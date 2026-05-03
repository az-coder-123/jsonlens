/// Summary of one unique key found while scanning a JSON document.
class KeySuggestion {
  /// The key name as it appears in the JSON object.
  final String key;

  /// Total number of times this key appears across the whole document.
  final int count;

  /// Up to [JsonKeyCollector.maxSamples] distinct primitive values seen
  /// for this key, useful for populating value-suggestion chips in the UI.
  final List<String> sampleValues;

  const KeySuggestion({
    required this.key,
    required this.count,
    required this.sampleValues,
  });
}

/// Traverses a JSON document and collects every unique key together with its
/// occurrence count and a set of representative primitive values.
abstract final class JsonKeyCollector {
  static const int maxSamples = 10;

  /// Scans [data] and returns all unique keys sorted by frequency descending.
  static List<KeySuggestion> collect(dynamic data) {
    final acc = <String, _KeyAcc>{};
    _traverse(data, acc);
    return acc.entries
        .map((e) => KeySuggestion(
              key: e.key,
              count: e.value.count,
              sampleValues: e.value.samples.toList(),
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  static void _traverse(dynamic data, Map<String, _KeyAcc> acc) {
    if (data is Map<String, dynamic>) {
      for (final entry in data.entries) {
        final a = acc.putIfAbsent(entry.key, _KeyAcc.new);
        a.count++;
        if (entry.value is! Map && entry.value is! List) {
          // Primitive value — add directly as sample.
          a.addSample(entry.value.toString());
        } else if (entry.value is List) {
          // Primitive array — add each non-container element as a sample
          // so the value-suggestion chips reflect individual array items.
          for (final item in entry.value as List) {
            if (item is! Map && item is! List) {
              a.addSample(item.toString());
            }
          }
        }
        _traverse(entry.value, acc);
      }
    } else if (data is List) {
      for (final item in data) {
        _traverse(item, acc);
      }
    }
  }
}

class _KeyAcc {
  int count = 0;
  final Set<String> samples = {};

  void addSample(String v) {
    if (samples.length < JsonKeyCollector.maxSamples) samples.add(v);
  }
}
