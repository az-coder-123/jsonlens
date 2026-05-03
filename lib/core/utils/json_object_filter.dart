import '../../features/json_analyzer/models/search_filter.dart';

/// Finds all Map nodes in a JSON document that satisfy a list of
/// key-value [SearchFilter] conditions (AND semantics).
abstract final class JsonObjectFilter {
  /// Returns JSON-paths of every Map node (or List item that is a Map) where
  /// every condition in [filters] is satisfied simultaneously.
  ///
  /// An empty [filters] list returns an empty result immediately.
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
  /// **Simple key** (no dots): the key is resolved directly from [obj] with a
  /// one-level shallow fallback into nested objects/arrays.
  ///
  /// **Dotted path** (`"apis.name"`, `"contact.email"`): the node must
  ///   1. Be located *within* the path-prefix context (i.e. every prefix
  ///      segment must appear in [nodePath] in order), **and**
  ///   2. Directly own the last key as a property.
  ///
  /// This ensures `apis.name contains "email"` matches `$.apis[0]` (which
  /// directly has `name`) rather than `$` (which only reaches `name` via deep
  /// traversal).
  static bool _satisfies(
    Map<String, dynamic> obj,
    SearchFilter filter,
    String nodePath,
  ) {
    final key = filter.key;

    if (!key.contains('.')) {
      // Simple key — direct lookup with shallow fallback.
      final raw = _resolveSimple(obj, key);
      return _checkValue(raw, filter);
    }

    // Dotted path — context-aware matching.
    final parts = key.split('.');
    final lastKey = parts.last;
    final prefixSegments = parts.sublist(0, parts.length - 1);

    // Guard 1: the node's path must contain every prefix segment in order.
    if (!_pathContainsSegments(nodePath, prefixSegments)) return false;

    // Guard 2: the node must directly own the last key.
    if (!obj.containsKey(lastKey)) return false;

    return _checkValue(obj[lastKey], filter);
  }

  // ---------------------------------------------------------------------------
  // Path-context helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when every element of [segments] appears in [path]'s
  /// parsed tokens in order.
  ///
  /// Example: path `$.apis[0]` → tokens `[$, apis, [0]]`
  ///          segments `[apis]` → found in order → `true`
  ///          segments `[users]` → not found → `false`
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

  /// Splits a JSON-path string into individual tokens.
  ///
  /// `$.apis[0].contact[1]` → `[$, apis, [0], contact, [1]]`
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

  // ---------------------------------------------------------------------------
  // Value helpers
  // ---------------------------------------------------------------------------

  /// Resolves a **simple** (non-dotted) [key] from [data].
  ///
  /// Looks up [data] directly first, then falls back one level into nested
  /// objects and arrays so that a filter like `email` can still match
  /// `{ "contact": { "email": "…" } }` when the user hasn't used a dotted path.
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

  /// Recursively checks whether [raw] satisfies [filter].
  ///
  /// Lists are flattened: the condition passes if ANY element passes.
  /// Map values never match (use a dotted path to navigate into them).
  static bool _checkValue(dynamic raw, SearchFilter filter) {
    if (raw == null) return false;
    if (raw is List) return raw.any((item) => _checkValue(item, filter));
    if (raw is Map) return false;
    return _compare(raw.toString(), filter.value, filter.operator);
  }

  static bool _compare(String actual, String expected, FilterOperator op) {
    final a = actual.toLowerCase();
    final e = expected.toLowerCase();
    return switch (op) {
      FilterOperator.contains => a.contains(e),
      FilterOperator.equals => a == e,
      FilterOperator.notEquals => a != e,
      FilterOperator.startsWith => a.startsWith(e),
      FilterOperator.endsWith => a.endsWith(e),
    };
  }
}
