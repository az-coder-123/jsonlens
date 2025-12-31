/// Application string constants for JSONLens.
///
/// Centralizes all user-facing strings for easy maintenance and localization.
abstract final class AppStrings {
  // App info
  static const String appName = 'JSONLens';
  static const String appDescription = 'Professional JSON Analyzer & Formatter';

  // Toolbar buttons
  static const String format = 'Format';
  static const String minify = 'Minify';
  static const String clear = 'Clear';
  static const String copy = 'Copy';
  static const String paste = 'Paste';

  // Status messages
  static const String validJson = 'Valid JSON';
  static const String invalidJson = 'Invalid JSON';
  static const String emptyInput = 'Enter JSON to analyze';

  // Feedback messages
  static const String copiedToClipboard = 'Copied to clipboard';
  static const String pastedFromClipboard = 'Pasted from clipboard';
  static const String cleared = 'Cleared';
  static const String formatted = 'JSON formatted';
  static const String minified = 'JSON minified';

  // Error messages
  static const String parseError = 'Parse error';
  static const String unexpectedError = 'An unexpected error occurred';
  static const String clipboardEmpty = 'Clipboard is empty';

  // Placeholders
  static const String inputHint = 'Paste or type your JSON here...';
  static const String outputPlaceholder = 'Formatted JSON will appear here';

  // Tab labels
  static const String formattedTab = 'Formatted';
  static const String treeViewTab = 'Tree View';
}
