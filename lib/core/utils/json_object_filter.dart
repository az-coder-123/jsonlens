import 'package:intl/intl.dart';

import '../../features/json_analyzer/models/search_filter.dart';

/// Finds all Map nodes in a JSON document that satisfy a list of
/// key-value [SearchFilter] conditions (AND semantics).
abstract final class JsonObjectFilter {
  /// Returns JSON-paths of every Map node (or List item that is a Map) where
  /// every condition in [filters] is satisfied simultaneously.
  static List<String> findMatching(
    dynamic data,
    List<SearchFilter> filters, {
    String prefix = r'$',
  }) {
    // Only apply enabled conditions; if none are active return empty.
    final active = filters.where((f) => f.enabled).toList();
    if (active.isEmpty) return const [];
    final results = <String>[];
    _traverse(data, active, prefix, results);
    return results;
  }

  static void _traverse(
    dynamic data,
    List<SearchFilter> filters,
    String prefix,
    List<String> results,
  ) {
    if (data is Map<String, dynamic>) {
      if (filters.every((f) => _satisfies(data, f, prefix))) {
        results.add(prefix);
      }
      for (final entry in data.entries) {
        _traverse(entry.value, filters, '$prefix.${entry.key}', results);
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        _traverse(data[i], filters, '$prefix[$i]', results);
      }
    }
  }

  /// Returns `true` when [obj] at [nodePath] satisfies [filter].
  ///
  /// **Simple key**: looked up directly with a shallow fallback.
  /// **Dotted path**: the node must be within the prefix context AND
  ///   directly own the last key.
  static bool _satisfies(
    Map<String, dynamic> obj,
    SearchFilter filter,
    String nodePath,
  ) {
    final key = filter.key;

    if (!key.contains('.')) {
      final raw = _resolveSimple(obj, key);
      return _checkValue(raw, filter);
    }

    final parts = key.split('.');
    final pathTokens = _tokenisePath(nodePath);

    // Count how many leading [parts] are already "consumed" by [pathTokens]
    // (matched in order). These represent path context already in the node's
    // own location — e.g. for a product at `$.products[0]` and key
    // `products.reviews.date`, only `"products"` is consumed (index 1),
    // leaving `"reviews.date"` to be resolved from the node's own properties.
    int consumed = 0;
    int tokenIdx = 0;
    for (int i = 0; i < parts.length; i++) {
      bool found = false;
      for (int j = tokenIdx; j < pathTokens.length; j++) {
        if (pathTokens[j] == parts[i]) {
          tokenIdx = j + 1;
          consumed = i + 1;
          found = true;
          break;
        }
      }
      if (!found) break;
    }

    // At least one segment must be consumed (node must be in context).
    if (consumed == 0) return false;
    // There must be at least one segment left to evaluate on the node.
    if (consumed >= parts.length) return false;

    // Resolve remaining segments from the node, flattening through arrays.
    final remaining = parts.sublist(consumed).join('.');
    final resolved = _resolveNestedPath(obj, remaining);
    return _checkValue(resolved, filter);
  }

  // ---------------------------------------------------------------------------
  // Type-aware value matching
  // ---------------------------------------------------------------------------

  /// Recursively checks whether [raw] satisfies [filter] with full type-awareness.
  ///
  /// | [ValueType]       | Behaviour                                         |
  /// |-------------------|---------------------------------------------------|
  /// | `any`             | Loose: converts to string, type-agnostic.        |
  /// | `string`          | Strict: only matches `String` runtime values.    |
  /// | `number`          | Strict: only matches `num`; compares numerically.|
  /// | `boolean`         | Strict: only matches `bool`.                     |
  /// | `nullValue`       | Strict: only matches Dart `null`.                |
  ///
  /// Lists are flattened: the condition passes if ANY element passes.
  static bool _checkValue(dynamic raw, SearchFilter filter) {
    if (raw is List) return raw.any((item) => _checkValue(item, filter));

    return switch (filter.valueType) {
      ValueType.nullValue => raw == null,
      ValueType.boolean => _checkBoolean(raw, filter),
      ValueType.number => _checkNumber(raw, filter),
      ValueType.string => _checkString(raw, filter),
      ValueType.datetime => _checkDateTime(raw, filter),
      ValueType.any => _checkAny(raw, filter),
    };
  }

  /// Null matching — `true` only when [raw] is Dart `null`.
  static bool _checkBoolean(dynamic raw, SearchFilter filter) {
    if (raw is! bool) return false;
    final expected = filter.value.toLowerCase() == 'true';
    return switch (filter.operator) {
      FilterOperator.equals => raw == expected,
      FilterOperator.notEquals => raw != expected,
      _ => false,
    };
  }

  /// Numeric matching — parses both sides and compares with full operator set.
  static bool _checkNumber(dynamic raw, SearchFilter filter) {
    final actual = raw is num ? raw : num.tryParse(raw.toString());
    if (actual == null) return false;
    final expected = num.tryParse(filter.value);
    if (expected == null) return false;
    return switch (filter.operator) {
      FilterOperator.equals => actual == expected,
      FilterOperator.notEquals => actual != expected,
      FilterOperator.greaterThan => actual > expected,
      FilterOperator.lessThan => actual < expected,
      FilterOperator.greaterOrEqual => actual >= expected,
      FilterOperator.lessOrEqual => actual <= expected,
      _ => false,
    };
  }

  /// String matching — only considers `String` runtime values.
  static bool _checkString(dynamic raw, SearchFilter filter) {
    if (raw is! String) return false;
    return _compareStrings(raw, filter.value, filter.operator,
        caseSensitive: filter.caseSensitive);
  }

  /// DateTime matching — parses both sides according to [filter.dateTimeFormat]
  /// then compares temporally using the full numeric operator set.
  static bool _checkDateTime(dynamic raw, SearchFilter filter) {
    final actual = _parseDateTime(raw, filter.dateTimeFormat,
        filter.customDatePattern);
    final expected = _parseDateTime(filter.value, filter.dateTimeFormat,
        filter.customDatePattern);
    if (actual == null || expected == null) return false;
    return switch (filter.operator) {
      FilterOperator.equals => actual == expected,
      FilterOperator.notEquals => actual != expected,
      FilterOperator.greaterThan => actual.isAfter(expected),
      FilterOperator.lessThan => actual.isBefore(expected),
      FilterOperator.greaterOrEqual => !actual.isBefore(expected),
      FilterOperator.lessOrEqual => !actual.isAfter(expected),
      _ => false,
    };
  }

  /// Parses [raw] as a [DateTime] according to [format], normalised to UTC.
  ///
  /// Normalising to UTC ensures that comparing ISO 8601 timestamps with
  /// date-only strings (e.g. `"2025-04-30T09:41Z"` vs `"2025-04-30"`) works
  /// correctly regardless of the local timezone.
  ///
  /// [customPattern] is only used when [format] is [DateTimeFormat.custom].
  /// When the custom pattern is empty this method falls back to ISO 8601
  /// parsing so the filter still produces results.
  static DateTime? _parseDateTime(
      dynamic raw, DateTimeFormat format, String customPattern) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    DateTime? result;
    switch (format) {
      case DateTimeFormat.iso8601:
        result = DateTime.tryParse(str);

      case DateTimeFormat.timestamp:
        final n = double.tryParse(str);
        if (n == null) return null;
        result = DateTime.fromMillisecondsSinceEpoch(
            (n * 1000).toInt(), isUtc: true);

      case DateTimeFormat.timestampMs:
        final n = double.tryParse(str);
        if (n == null) return null;
        result = DateTime.fromMillisecondsSinceEpoch(n.toInt(), isUtc: true);

      case DateTimeFormat.custom:
        final pattern = customPattern.trim();
        if (pattern.isEmpty) {
          // Fallback: try ISO 8601 when no pattern has been entered.
          result = DateTime.tryParse(str);
        } else {
          try {
            result = DateFormat(pattern).parseLoose(str, true); // isUTC=true
          } catch (_) {
            // Pattern doesn't match — attempt ISO 8601 as a last resort.
            result = DateTime.tryParse(str);
          }
        }
    }

    // Always return UTC so comparisons are timezone-independent.
    return result?.toUtc();
  }

  /// Loose matching — converts [raw] to string regardless of type.
  static bool _checkAny(dynamic raw, SearchFilter filter) {
    if (raw == null && filter.valueType == ValueType.any) {
      return _compareStrings('null', filter.value, filter.operator,
          caseSensitive: filter.caseSensitive);
    }
    if (raw is Map) return false;
    return _compareStrings(raw.toString(), filter.value, filter.operator,
        caseSensitive: filter.caseSensitive);
  }

  static bool _compareStrings(
    String actual,
    String expected,
    FilterOperator op, {
    required bool caseSensitive,
  }) {
    final a = caseSensitive ? actual : actual.toLowerCase();
    final e = caseSensitive ? expected : expected.toLowerCase();
    return switch (op) {
      FilterOperator.contains => a.contains(e),
      FilterOperator.equals => a == e,
      FilterOperator.notEquals => a != e,
      FilterOperator.startsWith => a.startsWith(e),
      FilterOperator.endsWith => a.endsWith(e),
      _ => false, // numeric operators not valid for strings
    };
  }

  // ---------------------------------------------------------------------------
  // Path-context helpers
  // ---------------------------------------------------------------------------

  /// Resolves a (possibly dotted) [key] from [data], flattening through Lists.
  ///
  /// When a segment resolves to a List, the remaining segments are applied to
  /// every Map element and primitives are collected into a flat list — enabling
  /// `reviews.date` on a product object to return all review dates at once.
  static dynamic _resolveNestedPath(dynamic data, String key) {
    dynamic cur = data;
    for (final part in key.split('.')) {
      if (cur == null) return null;
      if (cur is Map<String, dynamic>) {
        cur = cur[part];
      } else if (cur is List) {
        final collected = <dynamic>[];
        for (final item in cur) {
          if (item is Map<String, dynamic>) {
            final v = item[part];
            if (v is List) {
              collected.addAll(v);
            } else if (v != null) {
              collected.add(v);
            }
          }
        }
        cur = collected.isEmpty ? null : collected;
      } else {
        return null;
      }
    }
    return cur;
  }

  static List<String> _tokenisePath(String path) {
    final tokens = <String>[];
    for (final segment in path.split('.')) {
      final bracketIdx = segment.indexOf('[');
      if (bracketIdx == -1) {
        if (segment.isNotEmpty) tokens.add(segment);
      } else {
        if (bracketIdx > 0) tokens.add(segment.substring(0, bracketIdx));
        for (final m
            in RegExp(r'\[\d+\]').allMatches(segment.substring(bracketIdx))) {
          tokens.add(m.group(0)!);
        }
      }
    }
    return tokens;
  }

  static dynamic _resolveSimple(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey(key)) return data[key];
      for (final v in data.values) {
        if (v is Map<String, dynamic>) {
          final found = _resolveSimple(v, key);
          if (found != null) return found;
        }
        if (v is List) {
          for (final item in v) {
            if (item is Map<String, dynamic>) {
              final found = _resolveSimple(item, key);
              if (found != null) return found;
            }
          }
        }
      }
    }
    return null;
  }
}
