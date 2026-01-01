import '../../features/json_analyzer/models/json_search_result.dart';

/// Utility class for searching within JSON data.
abstract final class JsonSearcher {
  /// Searches for a query string in the JSON data.
  ///
  /// Returns a list of [JsonSearchResult] containing all matches.
  static List<JsonSearchResult> search(
    dynamic data,
    String query,
    JsonSearchOptions options,
  ) {
    if (query.isEmpty) return [];

    final results = <JsonSearchResult>[];
    final pattern = _createPattern(query, options);

    _searchRecursive(data, '', pattern, options, results);

    return results;
  }

  static RegExp _createPattern(String query, JsonSearchOptions options) {
    String patternString;
    if (options.useRegex) {
      patternString = query;
    } else {
      patternString = RegExp.escape(query);
    }

    return RegExp(patternString, caseSensitive: options.caseSensitive);
  }

  static void _searchRecursive(
    dynamic data,
    String currentPath,
    RegExp pattern,
    JsonSearchOptions options,
    List<JsonSearchResult> results,
  ) {
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final path = currentPath.isEmpty ? key : '$currentPath.$key';

        bool keyMatch = false;
        bool valueMatch = false;

        // Check key
        if (options.searchKeys && pattern.hasMatch(key)) {
          keyMatch = true;
        }

        // Check value (only for primitives)
        if (options.searchValues && _isPrimitive(value)) {
          if (pattern.hasMatch(value.toString())) {
            valueMatch = true;
          }
        }

        if (keyMatch || valueMatch) {
          results.add(
            JsonSearchResult(
              path: path,
              key: key,
              value: value,
              matchType: keyMatch && valueMatch
                  ? JsonSearchMatchType.both
                  : keyMatch
                  ? JsonSearchMatchType.key
                  : JsonSearchMatchType.value,
            ),
          );
        }

        // Recurse into nested structures
        _searchRecursive(value, path, pattern, options, results);
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final value = data[i];
        final path = '$currentPath[$i]';

        // Check value for primitives in arrays
        if (options.searchValues && _isPrimitive(value)) {
          if (pattern.hasMatch(value.toString())) {
            results.add(
              JsonSearchResult(
                path: path,
                key: null,
                value: value,
                matchType: JsonSearchMatchType.value,
              ),
            );
          }
        }

        // Recurse into nested structures
        _searchRecursive(value, path, pattern, options, results);
      }
    }
  }

  static bool _isPrimitive(dynamic value) {
    return value is String || value is num || value is bool || value == null;
  }
}
