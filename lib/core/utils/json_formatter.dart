import 'dart:convert';
import 'dart:isolate';

/// Utility class for JSON formatting operations.
///
/// Provides methods to format and minify JSON strings.
abstract final class JsonFormatter {
  /// The standard indent used for formatting (2 spaces).
  static const String _indent = '  ';

  /// JSON encoder with 2-space indentation.
  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent(_indent);

  /// JSON encoder without indentation for minification.
  static const JsonEncoder _minifyEncoder = JsonEncoder();

  /// Formats a JSON string with 2-space indentation.
  ///
  /// Returns the formatted JSON string.
  /// Throws [FormatException] if [input] is not valid JSON.
  static String format(String input) {
    if (input.trim().isEmpty) {
      return '';
    }
    final decoded = jsonDecode(input);
    return _prettyEncoder.convert(decoded);
  }

  /// Minifies a JSON string by removing all unnecessary whitespace.
  ///
  /// Returns the minified JSON string.
  /// Throws [FormatException] if [input] is not valid JSON.
  static String minify(String input) {
    if (input.trim().isEmpty) {
      return '';
    }
    final decoded = jsonDecode(input);
    return _minifyEncoder.convert(decoded);
  }

  /// Formats a dynamic object to a JSON string with 2-space indentation.
  static String formatObject(dynamic data) {
    return _prettyEncoder.convert(data);
  }

  /// Parses a JSON string and returns the decoded object.
  ///
  /// Returns `null` if parsing fails.
  static dynamic tryParse(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      return null;
    }
  }

  // ------------------------ Async / Isolate helpers ------------------------

  static void _formatObjectEntry(List<dynamic> msg) {
    final data = msg[0];
    final SendPort reply = msg[1] as SendPort;
    final result = JsonEncoder.withIndent(_indent).convert(data);
    reply.send(result);
  }

  static void _formatStringEntry(List<dynamic> msg) {
    final input = msg[0] as String;
    final SendPort reply = msg[1] as SendPort;
    final result = JsonEncoder.withIndent(_indent).convert(jsonDecode(input));
    reply.send(result);
  }

  static void _minifyStringEntry(List<dynamic> msg) {
    final input = msg[0] as String;
    final SendPort reply = msg[1] as SendPort;
    final result = JsonEncoder().convert(jsonDecode(input));
    reply.send(result);
  }

  /// Formats an already-decoded object using an isolate.
  static Future<String> formatObjectAsync(dynamic data) async {
    final rp = ReceivePort();
    await Isolate.spawn(_formatObjectEntry, [data, rp.sendPort]);
    final result = await rp.first as String;
    rp.close();
    return result;
  }

  /// Formats a raw JSON string using an isolate (parse + pretty-print).
  static Future<String> formatAsync(String input) async {
    if (input.trim().isEmpty) return '';
    final rp = ReceivePort();
    await Isolate.spawn(_formatStringEntry, [input, rp.sendPort]);
    final result = await rp.first as String;
    rp.close();
    return result;
  }

  /// Minifies a raw JSON string using an isolate.
  static Future<String> minifyAsync(String input) async {
    if (input.trim().isEmpty) return '';
    final rp = ReceivePort();
    await Isolate.spawn(_minifyStringEntry, [input, rp.sendPort]);
    final result = await rp.first as String;
    rp.close();
    return result;
  }

  /// Parses a JSON string in an isolate and returns the decoded object.
  ///
  /// Returns `null` if parsing fails.
  static Future<dynamic> tryParseAsync(String input) async {
    if (input.trim().isEmpty) return null;
    final rp = ReceivePort();
    // Reuse formatStringEntry by sending parse result back
    void parseEntry(List<dynamic> msg) {
      final str = msg[0] as String;
      final SendPort reply = msg[1] as SendPort;
      try {
        final obj = jsonDecode(str);
        reply.send(obj);
      } catch (_) {
        reply.send(null);
      }
    }

    await Isolate.spawn(parseEntry, [input, rp.sendPort]);
    final result = await rp.first;
    rp.close();
    return result;
  }

  // ------------------------ Object-based Async helpers ------------------------

  static void _minifyObjectEntry(List<dynamic> msg) {
    final data = msg[0];
    final SendPort reply = msg[1] as SendPort;
    final result = JsonEncoder().convert(data);
    reply.send(result);
  }

  /// Minifies an already-decoded object using an isolate.
  static Future<String> minifyObjectAsync(dynamic data) async {
    final rp = ReceivePort();
    await Isolate.spawn(_minifyObjectEntry, [data, rp.sendPort]);
    final result = await rp.first as String;
    rp.close();
    return result;
  }
}
