import '../../features/json_analyzer/models/json_diff_result.dart';

/// Utility class for comparing two JSON structures.
abstract final class JsonDiffer {
  /// Compares two JSON objects and returns the differences.
  static JsonDiffResult compare(dynamic first, dynamic second) {
    final onlyInFirst = <JsonDiffItem>[];
    final onlyInSecond = <JsonDiffItem>[];
    final modified = <JsonDiffItem>[];
    final unchanged = <JsonDiffItem>[];

    _compareRecursive(
      first,
      second,
      '',
      onlyInFirst,
      onlyInSecond,
      modified,
      unchanged,
    );

    return JsonDiffResult(
      onlyInFirst: onlyInFirst,
      onlyInSecond: onlyInSecond,
      modified: modified,
      unchanged: unchanged,
    );
  }

  static void _compareRecursive(
    dynamic first,
    dynamic second,
    String path,
    List<JsonDiffItem> onlyInFirst,
    List<JsonDiffItem> onlyInSecond,
    List<JsonDiffItem> modified,
    List<JsonDiffItem> unchanged,
  ) {
    // Both are maps
    if (first is Map && second is Map) {
      final allKeys = {...first.keys, ...second.keys};

      for (final key in allKeys) {
        final newPath = path.isEmpty ? key.toString() : '$path.$key';
        final hasFirst = first.containsKey(key);
        final hasSecond = second.containsKey(key);

        if (hasFirst && !hasSecond) {
          onlyInFirst.add(
            JsonDiffItem(
              path: newPath,
              firstValue: first[key],
              secondValue: null,
              diffType: JsonDiffType.removed,
            ),
          );
        } else if (!hasFirst && hasSecond) {
          onlyInSecond.add(
            JsonDiffItem(
              path: newPath,
              firstValue: null,
              secondValue: second[key],
              diffType: JsonDiffType.added,
            ),
          );
        } else {
          _compareRecursive(
            first[key],
            second[key],
            newPath,
            onlyInFirst,
            onlyInSecond,
            modified,
            unchanged,
          );
        }
      }
    }
    // Both are lists
    else if (first is List && second is List) {
      final maxLength = first.length > second.length
          ? first.length
          : second.length;

      for (int i = 0; i < maxLength; i++) {
        final newPath = '$path[$i]';

        if (i >= first.length) {
          onlyInSecond.add(
            JsonDiffItem(
              path: newPath,
              firstValue: null,
              secondValue: second[i],
              diffType: JsonDiffType.added,
            ),
          );
        } else if (i >= second.length) {
          onlyInFirst.add(
            JsonDiffItem(
              path: newPath,
              firstValue: first[i],
              secondValue: null,
              diffType: JsonDiffType.removed,
            ),
          );
        } else {
          _compareRecursive(
            first[i],
            second[i],
            newPath,
            onlyInFirst,
            onlyInSecond,
            modified,
            unchanged,
          );
        }
      }
    }
    // Primitive comparison
    else if (first != second) {
      modified.add(
        JsonDiffItem(
          path: path.isEmpty ? 'root' : path,
          firstValue: first,
          secondValue: second,
          diffType: JsonDiffType.modified,
        ),
      );
    } else {
      unchanged.add(
        JsonDiffItem(
          path: path.isEmpty ? 'root' : path,
          firstValue: first,
          secondValue: second,
          diffType: JsonDiffType.unchanged,
        ),
      );
    }
  }
}
