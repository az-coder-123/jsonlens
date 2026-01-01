// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:jsonlens/core/utils/json_formatter.dart';

Future<void> main() async {
  final file = File('tool/benchmarks/large.json');
  if (!file.existsSync()) {
    print('Please run json_bench.dart first to generate large.json');
    return;
  }

  final payload = await file.readAsString();
  print('Loaded large.json (${(payload.length / 1024).toStringAsFixed(1)} KB)');

  final iterations = 50;
  final rng = Random();
  final times = <int>[];

  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    // occasionally slightly modify payload to avoid identical caching effects
    final modPayload = (rng.nextBool())
        ? payload
        : payload.replaceFirst('"Item 0"', '"Item -$i"');
    await JsonFormatter.formatAsync(modPayload);
    sw.stop();
    times.add(sw.elapsedMilliseconds);
    if (i % 10 == 0) print('iter $i: ${sw.elapsedMilliseconds} ms');
    await Future.delayed(Duration(milliseconds: 50));
  }

  final avg = times.reduce((a, b) => a + b) / times.length;
  final max = times.reduce((a, b) => a > b ? a : b);
  print(
    'Iterations: $iterations, avg: ${avg.toStringAsFixed(1)} ms, max: $max ms',
  );
}
