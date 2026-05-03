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
    if (filters.isEmpty) return const [];
    final results = <String>[];
    _traverse(data, filters, prefix, results);
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
    final lastKey = parts.last;
    final prefixSegments = parts.sublist(0, parts.length - 1);

    if (!_pathContainsSegments(nodePath, prefixSegments)) return false;
    if (!obj.containsKey(lastKey)) return false;
    return _checkValue(obj[lastKey], filter);
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

  static bool _pathContainsSegments(String path, List<String> segments) {
    if (segments.isEmpty) return true;
    final tokens = _tokenisePath(path);
    int si = 0;
    for (final token in tokens) {
      if (token == segments[si]) {
        si++;
        if (si == segments.length) return true;
      }
    }
    return false;
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
