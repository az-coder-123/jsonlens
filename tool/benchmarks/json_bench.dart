// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

/// Simple micro-benchmark for JSON decode/encode times.
///
/// Usage:
/// dart run tool/benchmarks/json_bench.dart
///
/// The script will:
///  - generate several payload sizes in memory
///  - optionally write `tool/benchmarks/large.json`
///  - measure decode and encode (with 2-space indent) times

Map<String, dynamic> _makeNested(int depth, int index) {
  Map<String, dynamic> m = {'leaf': 'leaf $index'};
  for (var d = 0; d < depth; d++) {
    m = {'level': d, 'data': m};
  }
  return m;
}

String generatePayload(int itemCount, {int nestedDepth = 5}) {
  final rng = Random(12345);
  final list = List.generate(
    itemCount,
    (i) => {
      'id': i,
      'name': 'Item $i',
      'value': rng.nextInt(1 << 31),
      'nested': _makeNested(nestedDepth, i),
    },
  );
  return jsonEncode(list);
}

Future<void> bench(String label, String payload, {int rounds = 3}) async {
  final bytes = utf8.encode(payload).length;
  print('\n--- $label (${(bytes / 1024).toStringAsFixed(1)} KB) ---');

  // decode
  final decodeTimes = <int>[];
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    final decoded = jsonDecode(payload);
    sw.stop();
    decodeTimes.add(sw.elapsedMilliseconds);
    // use decoded to prevent optimizations away
    if (decoded == null) stdout.writeln('');
  }
  final decodeAvg = decodeTimes.reduce((a, b) => a + b) / rounds;
  print('decode avg: $decodeAvg ms (rounds: $rounds)');

  // encode with indent
  final encoder = JsonEncoder.withIndent('  ');
  final encodeTimes = <int>[];
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    final encoded = encoder.convert(jsonDecode(payload));
    sw.stop();
    encodeTimes.add(sw.elapsedMilliseconds);
    if (encoded.isEmpty) stdout.writeln('');
  }
  final encodeAvg = encodeTimes.reduce((a, b) => a + b) / rounds;
  print('encode (with indent) avg: $encodeAvg ms (rounds: $rounds)');
}

// Isolate helper entries
void _decodeEntry(List<dynamic> msg) {
  final payload = msg[0] as String;
  final SendPort reply = msg[1] as SendPort;

  // perform decode
  jsonDecode(payload);
  reply.send(true);
}

void _encodeEntry(List<dynamic> msg) {
  final payload = msg[0] as String;
  final SendPort reply = msg[1] as SendPort;

  final obj = jsonDecode(payload);
  final encoded = JsonEncoder.withIndent('  ').convert(obj);
  reply.send(encoded.length);
}

Future<void> _runIsolateDecode(String payload) async {
  final rp = ReceivePort();
  await Isolate.spawn(_decodeEntry, [payload, rp.sendPort]);
  await rp.first;
  rp.close();
}

Future<void> _runIsolateEncode(String payload) async {
  final rp = ReceivePort();
  await Isolate.spawn(_encodeEntry, [payload, rp.sendPort]);
  await rp.first;
  rp.close();
}

Future<void> benchIsolate(
  String label,
  String payload, {
  int rounds = 3,
}) async {
  final bytes = utf8.encode(payload).length;
  print('\n--- $label (isolate) (${(bytes / 1024).toStringAsFixed(1)} KB) ---');

  // decode in isolate
  final decodeTimes = <int>[];
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    await _runIsolateDecode(payload);
    sw.stop();
    decodeTimes.add(sw.elapsedMilliseconds);
  }
  final decodeAvg = decodeTimes.reduce((a, b) => a + b) / rounds;
  print('isolate decode avg: $decodeAvg ms (rounds: $rounds)');

  // encode in isolate
  final encodeTimes = <int>[];
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    await _runIsolateEncode(payload);
    sw.stop();
    encodeTimes.add(sw.elapsedMilliseconds);
  }
  final encodeAvg = encodeTimes.reduce((a, b) => a + b) / rounds;
  print('isolate encode avg: $encodeAvg ms (rounds: $rounds)');
}

Future<void> main() async {
  print('JSONLens micro-benchmark');

  // sizes by item count (tune as needed)
  final sizes = [100, 1000, 5000, 20000];

  for (final n in sizes) {
    final payload = generatePayload(n, nestedDepth: 5);
    await bench('items=$n', payload);
    await benchIsolate('items=$n', payload);
  }

  // Also generate and persist a sample large file for manual UI tests
  final largePayload = generatePayload(10000, nestedDepth: 5);
  final outFile = File('tool/benchmarks/large.json');
  await outFile.writeAsString(
    JsonEncoder.withIndent('  ').convert(jsonDecode(largePayload)),
  );
  final outBytes = await outFile.length();
  print(
    '\nWrote sample large JSON to ${outFile.path} (${(outBytes / 1024).toStringAsFixed(1)} KB)',
  );

  // Benchmark the written large.json file as well
  final filePayload = await outFile.readAsString();
  await bench('file: large.json', filePayload);
  await benchIsolate('file: large.json', filePayload);

  print('\nDone.');
}
