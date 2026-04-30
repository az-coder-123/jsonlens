/// Utilities for parsing JSON path strings.
abstract final class JsonPath {
  static final RegExp _tokenRegex = RegExp(r'\$|[^.\[\]]+|\[\d+\]');

  /// Tokenizes a JSON path into ordered string segments.
  ///
  /// Example: `$.users[0].name` -> `['$', 'users', '[0]', 'name']`.
  static List<String> tokens(String path) {
    if (path.isEmpty) return [];
    return [for (final match in _tokenRegex.allMatches(path)) match.group(0)!];
  }

  /// Returns token list for breadcrumb display, ensuring a leading `$`.
  static List<String> breadcrumbTokens(String path) {
    final parts = tokens(path);
    if (parts.isEmpty) return [];
    if (parts.first != r'$') {
      return ['\$', ...parts];
    }
    return parts;
  }

  /// Parses a JSON path into navigation segments.
  ///
  /// Returns a list of [String] (object key) or [int] (array index) values.
  /// The leading `$` token is ignored if present.
  static List<Object> toSegments(String path) {
    final segments = <Object>[];
    for (final token in tokens(path)) {
      if (token == r'$') continue;
      if (token.startsWith('[') && token.endsWith(']')) {
        final idx = int.tryParse(token.substring(1, token.length - 1));
        if (idx != null) segments.add(idx);
      } else {
        segments.add(token);
      }
    }
    return segments;
  }
}
