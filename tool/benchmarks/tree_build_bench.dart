// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

int _countNodes(dynamic node, {int depth = 0, int? maxDepth}) {
  if (maxDepth != null && depth > maxDepth) return 0;
  if (node is Map) {
    var count = 1; // this node
    if (maxDepth == null || depth < maxDepth) {
      for (var v in node.values) {
        count += _countNodes(v, depth: depth + 1, maxDepth: maxDepth);
      }
    }
    return count;
  } else if (node is List) {
    var count = 1;
    if (maxDepth == null || depth < maxDepth) {
      for (var v in node) {
        count += _countNodes(v, depth: depth + 1, maxDepth: maxDepth);
      }
    }
    return count;
  } else {
    return 1; // scalar
  }
}

Future<void> main() async {
  final f = File('tool/benchmarks/large.json');
  if (!f.existsSync()) {
    print('Run json_bench.dart first to generate large.json');
    return;
  }

  final payload = await f.readAsString();
  final obj = jsonDecode(payload);
  print('Loaded JSON size: ${(payload.length / 1024).toStringAsFixed(1)} KB');

  // Warm up
  _countNodes(obj);

  for (final d in [1, 2, 3, 4, 5, null]) {
    final sw = Stopwatch()..start();
    final count = _countNodes(obj, maxDepth: d);
    sw.stop();
    final label = d == null ? 'full' : 'depth=$d';
    print('$label -> nodes: $count, time: ${sw.elapsedMilliseconds} ms');
  }
}
