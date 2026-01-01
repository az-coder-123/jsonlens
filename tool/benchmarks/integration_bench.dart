// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:jsonlens/core/utils/json_formatter.dart';

Future<void> main() async {
  final file = File('tool/benchmarks/large.json');
  if (!file.existsSync()) {
    print('Please run json_bench.dart first to generate large.json');
    return;
  }

  final payload = await file.readAsString();
  print('Loaded large.json (${(payload.length / 1024).toStringAsFixed(1)} KB)');

  // Path A: main-thread decode + main-thread pretty-print
  final sw1 = Stopwatch()..start();
  final obj1 = jsonDecode(payload);
  final mainPretty = JsonEncoder.withIndent('  ').convert(obj1);
  sw1.stop();
  print('Main-thread decode+format: ${sw1.elapsedMilliseconds} ms');

  // Path B: main-thread decode + isolate formatObjectAsync
  final sw2 = Stopwatch()..start();
  final obj2 = jsonDecode(payload);
  final isoPretty = await JsonFormatter.formatObjectAsync(obj2);
  sw2.stop();
  print('Main-thread decode + isolate format: ${sw2.elapsedMilliseconds} ms');

  // Path C: isolate parse + isolate format (both in isolate) - use formatAsync which parses inside isolate
  final sw3 = Stopwatch()..start();
  final isoFull = await JsonFormatter.formatAsync(payload);
  sw3.stop();
  print('Isolate parse+format (formatAsync): ${sw3.elapsedMilliseconds} ms');

  print(
    'Sizes: mainPretty=${(mainPretty.length / 1024).toStringAsFixed(1)} KB, isoPretty=${(isoPretty.length / 1024).toStringAsFixed(1)} KB, isoFull=${(isoFull.length / 1024).toStringAsFixed(1)} KB',
  );
}
