/// Model for JSON search results.
class JsonSearchResult {
  /// The path to the found item (e.g., "root.users[0].name").
  final String path;

  /// The key where the match was found.
  final String? key;

  /// The value where the match was found.
  final dynamic value;

  /// The type of match (key or value).
  final JsonSearchMatchType matchType;

  const JsonSearchResult({
    required this.path,
    this.key,
    required this.value,
    required this.matchType,
  });

  @override
  String toString() => 'JsonSearchResult(path: $path, matchType: $matchType)';
}

/// Type of search match.
enum JsonSearchMatchType { key, value, both }

/// Options for JSON search.
class JsonSearchOptions {
  /// Whether to search in keys.
  final bool searchKeys;

  /// Whether to search in values.
  final bool searchValues;

  /// Whether the search is case sensitive.
  final bool caseSensitive;

  /// Whether to use regex matching.
  final bool useRegex;

  const JsonSearchOptions({
    this.searchKeys = true,
    this.searchValues = true,
    this.caseSensitive = false,
    this.useRegex = false,
  });

  JsonSearchOptions copyWith({
    bool? searchKeys,
    bool? searchValues,
    bool? caseSensitive,
    bool? useRegex,
  }) {
    return JsonSearchOptions(
      searchKeys: searchKeys ?? this.searchKeys,
      searchValues: searchValues ?? this.searchValues,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      useRegex: useRegex ?? this.useRegex,
    );
  }
}
