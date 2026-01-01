import 'dart:convert';

/// Utility class for advanced JSON transformations.
abstract final class JsonTransformer {
  /// Sorts all keys in the JSON object alphabetically.
  ///
  /// Works recursively on nested objects.
  static dynamic sortKeys(dynamic data, {bool ascending = true}) {
    if (data is Map) {
      final sortedKeys = data.keys.toList()
        ..sort(
          (a, b) => ascending
              ? a.toString().compareTo(b.toString())
              : b.toString().compareTo(a.toString()),
        );

      final sortedMap = <String, dynamic>{};
      for (final key in sortedKeys) {
        sortedMap[key.toString()] = sortKeys(data[key], ascending: ascending);
      }
      return sortedMap;
    } else if (data is List) {
      return data.map((item) => sortKeys(item, ascending: ascending)).toList();
    }
    return data;
  }

  /// Flattens a nested JSON structure into a single-level object.
  ///
  /// Keys are joined with the specified delimiter (default: ".").
  static Map<String, dynamic> flatten(
    dynamic data, {
    String delimiter = '.',
    String prefix = '',
  }) {
    final result = <String, dynamic>{};

    void flattenRecursive(dynamic value, String currentKey) {
      if (value is Map) {
        if (value.isEmpty) {
          result[currentKey] = {};
        } else {
          for (final entry in value.entries) {
            final newKey = currentKey.isEmpty
                ? entry.key.toString()
                : '$currentKey$delimiter${entry.key}';
            flattenRecursive(entry.value, newKey);
          }
        }
      } else if (value is List) {
        if (value.isEmpty) {
          result[currentKey] = [];
        } else {
          for (int i = 0; i < value.length; i++) {
            flattenRecursive(value[i], '$currentKey[$i]');
          }
        }
      } else {
        result[currentKey] = value;
      }
    }

    flattenRecursive(data, prefix);
    return result;
  }

  /// Unflattens a flat JSON structure back to nested.
  static dynamic unflatten(
    Map<String, dynamic> data, {
    String delimiter = '.',
  }) {
    final result = <String, dynamic>{};

    for (final entry in data.entries) {
      final keys = entry.key.split(delimiter);
      var current = result;

      for (int i = 0; i < keys.length - 1; i++) {
        final key = keys[i];
        current[key] ??= <String, dynamic>{};
        current = current[key] as Map<String, dynamic>;
      }

      current[keys.last] = entry.value;
    }

    return result;
  }

  /// Filters JSON to only include specified keys.
  static dynamic filterKeys(dynamic data, Set<String> keysToKeep) {
    if (data is Map) {
      final filtered = <String, dynamic>{};
      for (final entry in data.entries) {
        if (keysToKeep.contains(entry.key.toString())) {
          filtered[entry.key.toString()] = filterKeys(entry.value, keysToKeep);
        } else if (entry.value is Map || entry.value is List) {
          final nested = filterKeys(entry.value, keysToKeep);
          if (nested is Map && nested.isNotEmpty ||
              nested is List && nested.isNotEmpty) {
            filtered[entry.key.toString()] = nested;
          }
        }
      }
      return filtered;
    } else if (data is List) {
      return data.map((item) => filterKeys(item, keysToKeep)).toList();
    }
    return data;
  }

  /// Removes null values from JSON.
  static dynamic removeNulls(dynamic data) {
    if (data is Map) {
      final cleaned = <String, dynamic>{};
      for (final entry in data.entries) {
        if (entry.value != null) {
          final cleanedValue = removeNulls(entry.value);
          if (cleanedValue != null) {
            cleaned[entry.key.toString()] = cleanedValue;
          }
        }
      }
      return cleaned;
    } else if (data is List) {
      return data
          .where((item) => item != null)
          .map((item) => removeNulls(item))
          .toList();
    }
    return data;
  }

  /// Removes empty strings, arrays, and objects from JSON.
  static dynamic removeEmpty(dynamic data) {
    if (data is Map) {
      final cleaned = <String, dynamic>{};
      for (final entry in data.entries) {
        final cleanedValue = removeEmpty(entry.value);
        if (!_isEmpty(cleanedValue)) {
          cleaned[entry.key.toString()] = cleanedValue;
        }
      }
      return cleaned.isEmpty ? null : cleaned;
    } else if (data is List) {
      final cleaned = data
          .map((item) => removeEmpty(item))
          .where((item) => !_isEmpty(item))
          .toList();
      return cleaned.isEmpty ? null : cleaned;
    }
    return data;
  }

  static bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  /// Extracts a value at a given JSON path.
  ///
  /// Supports dot notation and array indices (e.g., "users[0].name").
  static dynamic getValueAtPath(dynamic data, String path) {
    if (path.isEmpty) return data;

    final segments = _parsePath(path);
    dynamic current = data;

    for (final segment in segments) {
      if (current == null) return null;

      if (segment.isArrayIndex) {
        if (current is List && segment.index! < current.length) {
          current = current[segment.index!];
        } else {
          return null;
        }
      } else {
        if (current is Map && current.containsKey(segment.key)) {
          current = current[segment.key];
        } else {
          return null;
        }
      }
    }

    return current;
  }

  static List<_PathSegment> _parsePath(String path) {
    final segments = <_PathSegment>[];
    final regex = RegExp(r'([^.\[\]]+)|\[(\d+)\]');

    for (final match in regex.allMatches(path)) {
      if (match.group(1) != null) {
        segments.add(_PathSegment(key: match.group(1)));
      } else if (match.group(2) != null) {
        segments.add(_PathSegment(index: int.parse(match.group(2)!)));
      }
    }

    return segments;
  }

  /// Converts JSON to a formatted string representation.
  static String toFormattedString(dynamic data) {
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

class _PathSegment {
  final String? key;
  final int? index;

  _PathSegment({this.key, this.index});

  bool get isArrayIndex => index != null;
}
