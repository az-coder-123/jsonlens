import 'dart:convert';

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
}
