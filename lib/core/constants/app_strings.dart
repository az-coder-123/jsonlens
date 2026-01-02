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
  static const String save = 'Save';
  static const String open = 'Open';

  // Status messages
  static const String validJson = 'Valid JSON';

  // Save feedback
  static const String savedToFile = 'Saved to file';
  static const String saveCancelled = 'Save cancelled';
  static const String saveFailed = 'Failed to save file';

  // Load feedback
  static const String loadedFromFile = 'Loaded from file';
  static const String loadCancelled = 'Open cancelled';
  static const String loadFailed = 'Failed to open file';
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
