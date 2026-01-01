/// Model for JSON statistics.
class JsonStatistics {
  /// Total number of keys in the JSON.
  final int totalKeys;

  /// Total number of values (leaf nodes).
  final int totalValues;

  /// Maximum depth of nesting.
  final int maxDepth;

  /// Count of each value type.
  final Map<String, int> typeCounts;

  /// Total size in characters.
  final int totalCharacters;

  /// Number of arrays.
  final int arrayCount;

  /// Number of objects.
  final int objectCount;

  const JsonStatistics({
    required this.totalKeys,
    required this.totalValues,
    required this.maxDepth,
    required this.typeCounts,
    required this.totalCharacters,
    required this.arrayCount,
    required this.objectCount,
  });

  factory JsonStatistics.empty() {
    return const JsonStatistics(
      totalKeys: 0,
      totalValues: 0,
      maxDepth: 0,
      typeCounts: {},
      totalCharacters: 0,
      arrayCount: 0,
      objectCount: 0,
    );
  }

  /// Calculate statistics from JSON data.
  factory JsonStatistics.fromJson(dynamic data, String rawJson) {
    int totalKeys = 0;
    int totalValues = 0;
    int maxDepth = 0;
    int arrayCount = 0;
    int objectCount = 0;
    final typeCounts = <String, int>{};

    void countType(String type) {
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    void traverse(dynamic value, int depth) {
      if (depth > maxDepth) maxDepth = depth;

      if (value is Map) {
        objectCount++;
        countType('object');
        totalKeys += value.length;
        for (final entry in value.entries) {
          traverse(entry.value, depth + 1);
        }
      } else if (value is List) {
        arrayCount++;
        countType('array');
        for (final item in value) {
          traverse(item, depth + 1);
        }
      } else if (value is String) {
        totalValues++;
        countType('string');
      } else if (value is num) {
        totalValues++;
        countType('number');
      } else if (value is bool) {
        totalValues++;
        countType('boolean');
      } else if (value == null) {
        totalValues++;
        countType('null');
      }
    }

    traverse(data, 0);

    return JsonStatistics(
      totalKeys: totalKeys,
      totalValues: totalValues,
      maxDepth: maxDepth,
      typeCounts: typeCounts,
      totalCharacters: rawJson.length,
      arrayCount: arrayCount,
      objectCount: objectCount,
    );
  }
}
