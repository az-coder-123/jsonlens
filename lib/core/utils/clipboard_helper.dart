import 'package:flutter/services.dart';

/// Utility class for clipboard operations.
///
/// Provides methods to copy text to and paste text from the system clipboard.
abstract final class ClipboardHelper {
  /// Copies the given [text] to the system clipboard.
  ///
  /// Returns `true` if successful, `false` otherwise.
  static Future<bool> copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves text from the system clipboard.
  ///
  /// Returns the clipboard text, or `null` if empty or unavailable.
  static Future<String?> paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  /// Checks if the clipboard has text content.
  ///
  /// Returns `true` if clipboard contains text, `false` otherwise.
  static Future<bool> hasText() async {
    final text = await paste();
    return text != null && text.isNotEmpty;
  }
}
