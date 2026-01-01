import 'dart:convert';
import 'dart:isolate';

import '../../features/json_analyzer/models/json_result.dart';

/// Utility class for JSON validation operations.
///
/// Provides methods to validate JSON strings and extract error information.
abstract final class JsonValidator {
  /// Validates a JSON string synchronously and returns a [JsonValidationResult].
  ///
  /// Returns a result indicating whether the JSON is valid,
  /// and includes error details if invalid.
  static JsonValidationResult validate(String input) {
    if (input.trim().isEmpty) {
      return const JsonValidationResult(isValid: false, isEmpty: true);
    }

    try {
      final decoded = jsonDecode(input);
      return JsonValidationResult(isValid: true, data: decoded);
    } on FormatException catch (e) {
      return JsonValidationResult(
        isValid: false,
        errorMessage: _formatErrorMessage(e),
        errorOffset: e.offset,
        lineNumber: _calculateLineNumber(input, e.offset),
      );
    } catch (e) {
      return JsonValidationResult(isValid: false, errorMessage: e.toString());
    }
  }

  /// Validates a JSON string in an isolate and returns a [JsonValidationResult].
  /// This offloads parsing to a separate isolate so it doesn't block the UI thread.
  static Future<JsonValidationResult> validateAsync(String input) async {
    if (input.trim().isEmpty) {
      return const JsonValidationResult(isValid: false, isEmpty: true);
    }

    final rp = ReceivePort();

    void validateEntry(List<dynamic> msg) {
      final str = msg[0] as String;
      final SendPort reply = msg[1] as SendPort;
      try {
        final obj = jsonDecode(str);
        reply.send({'ok': true, 'data': obj});
      } on FormatException catch (e) {
        reply.send({'ok': false, 'message': e.message, 'offset': e.offset});
      } catch (e) {
        reply.send({'ok': false, 'message': e.toString()});
      }
    }

    await Isolate.spawn(validateEntry, [input, rp.sendPort]);
    final res = await rp.first as Map;
    rp.close();

    if (res['ok'] == true) {
      return JsonValidationResult(isValid: true, data: res['data']);
    }

    final message = res['message'] as String?;
    final offset = res['offset'] as int?;

    return JsonValidationResult(
      isValid: false,
      errorMessage: message ?? 'Invalid JSON',
      errorOffset: offset,
      lineNumber: _calculateLineNumber(input, offset),
    );
  }

  /// Formats the error message from a [FormatException].
  static String _formatErrorMessage(FormatException e) {
    String message = e.message;

    // Clean up common error message prefixes
    if (message.startsWith('Unexpected character')) {
      return message;
    }
    if (message.startsWith('Expected')) {
      return message;
    }

    return message;
  }

  /// Calculates the line number from the error offset.
  static int? _calculateLineNumber(String input, int? offset) {
    if (offset == null || offset < 0 || offset > input.length) {
      return null;
    }

    int lineNumber = 1;
    for (int i = 0; i < offset && i < input.length; i++) {
      if (input[i] == '\n') {
        lineNumber++;
      }
    }

    return lineNumber;
  }

  /// Quick check if a string is potentially valid JSON.
  ///
  /// This is a fast preliminary check that doesn't fully parse the JSON.
  static bool isPotentiallyValid(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    final firstChar = trimmed[0];
    final lastChar = trimmed[trimmed.length - 1];

    // JSON must start with { or [ and end with } or ]
    return (firstChar == '{' && lastChar == '}') ||
        (firstChar == '[' && lastChar == ']') ||
        (firstChar == '"' && lastChar == '"') ||
        trimmed == 'null' ||
        trimmed == 'true' ||
        trimmed == 'false' ||
        double.tryParse(trimmed) != null;
  }
}
