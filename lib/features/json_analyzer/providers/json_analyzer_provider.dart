import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_formatter.dart';
import '../../../core/utils/json_validator.dart';
import '../models/json_result.dart';

/// StateNotifier for managing JSON analyzer state.
///
/// Handles input changes, formatting, minification, and validation.
class JsonAnalyzerNotifier extends StateNotifier<JsonAnalyzerState> {
  JsonAnalyzerNotifier() : super(const JsonAnalyzerState());

  /// Updates the input and validates/formats it.
  void updateInput(String value) {
    final validationResult = JsonValidator.validate(value);

    String output = '';
    if (validationResult.isValid) {
      try {
        output = JsonFormatter.format(value);
      } catch (_) {
        output = '';
      }
    }

    state = state.copyWith(
      input: value,
      output: output,
      validationResult: validationResult,
    );
  }

  /// Formats the current input JSON with 2-space indentation.
  void format() {
    if (!state.isValid || state.isEmpty) return;

    try {
      final formatted = JsonFormatter.format(state.input);
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Validation already failed, no need to update
    }
  }

  /// Minifies the current input JSON.
  void minify() {
    if (!state.isValid || state.isEmpty) return;

    try {
      final minified = JsonFormatter.minify(state.input);
      state = state.copyWith(input: minified, output: minified);
    } catch (_) {
      // Validation already failed, no need to update
    }
  }

  /// Clears all input and output.
  void clear() {
    state = const JsonAnalyzerState();
  }

  /// Sets the input from clipboard paste.
  void pasteFromClipboard(String text) {
    updateInput(text);
  }

  /// Updates the selected tab index for output view.
  void setSelectedTab(int index) {
    state = state.copyWith(selectedTabIndex: index);
  }
}

/// Provider for the JSON analyzer state.
final jsonAnalyzerProvider =
    StateNotifierProvider<JsonAnalyzerNotifier, JsonAnalyzerState>(
      (ref) => JsonAnalyzerNotifier(),
    );

/// Provider for checking if JSON is valid.
final isValidProvider = Provider<bool>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.isValid));
});

/// Provider for checking if input is empty.
final isEmptyProvider = Provider<bool>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.isEmpty));
});

/// Provider for the formatted output.
final outputProvider = Provider<String>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.output));
});

/// Provider for the error message.
final errorMessageProvider = Provider<String>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.errorMessage));
});

/// Provider for the parsed JSON data.
final parsedDataProvider = Provider<dynamic>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.parsedData));
});

/// Provider for the selected tab index.
final selectedTabProvider = Provider<int>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.selectedTabIndex));
});
