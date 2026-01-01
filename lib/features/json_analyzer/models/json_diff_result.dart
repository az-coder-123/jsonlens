/// Model for JSON diff/comparison results.
class JsonDiffResult {
  /// Items that exist only in the first JSON.
  final List<JsonDiffItem> onlyInFirst;

  /// Items that exist only in the second JSON.
  final List<JsonDiffItem> onlyInSecond;

  /// Items that have different values.
  final List<JsonDiffItem> modified;

  /// Items that are identical.
  final List<JsonDiffItem> unchanged;

  const JsonDiffResult({
    required this.onlyInFirst,
    required this.onlyInSecond,
    required this.modified,
    required this.unchanged,
  });

  factory JsonDiffResult.empty() {
    return const JsonDiffResult(
      onlyInFirst: [],
      onlyInSecond: [],
      modified: [],
      unchanged: [],
    );
  }

  /// Total number of differences.
  int get totalDifferences =>
      onlyInFirst.length + onlyInSecond.length + modified.length;

  /// Whether the two JSONs are identical.
  bool get isIdentical => totalDifferences == 0;
}

/// A single item in a diff result.
class JsonDiffItem {
  /// The path to the item.
  final String path;

  /// The value in the first JSON (null if not present).
  final dynamic firstValue;

  /// The value in the second JSON (null if not present).
  final dynamic secondValue;

  /// The type of difference.
  final JsonDiffType diffType;

  const JsonDiffItem({
    required this.path,
    this.firstValue,
    this.secondValue,
    required this.diffType,
  });
}

/// Type of difference in JSON comparison.
enum JsonDiffType { added, removed, modified, unchanged }
