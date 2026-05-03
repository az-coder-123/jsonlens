import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/performance_constants.dart';
import '../../../core/utils/json_formatter.dart';
import '../../../core/utils/json_transformer.dart';
import '../../../core/utils/json_validator.dart';
import '../models/json_result.dart';
import '../models/json_statistics.dart';

/// StateNotifier for managing JSON analyzer state.
///
/// Handles input changes, formatting, minification, and validation.
/// Optimized for large JSON files with configurable thresholds.
class JsonAnalyzerNotifier extends StateNotifier<JsonAnalyzerState> {
  JsonAnalyzerNotifier() : super(const JsonAnalyzerState());

  /// Updates the input and validates/formats it.
  int _validationId = 0;

  Future<void> updateInput(String value) async {
    // Increment validation id to allow cancellation of stale validations.
    final myId = ++_validationId;

    final inputSize = value.length;

    // Determine mode based on input size thresholds
    final isLarge =
        inputSize > PerformanceConstants.processingIndicatorThreshold;
    final isOnDemandOutput =
        inputSize > PerformanceConstants.onDemandOutputThreshold;
    final disableSyntaxHighlighting =
        inputSize > PerformanceConstants.syntaxHighlightingThreshold;
    final isReadOnlyMode =
        inputSize > PerformanceConstants.readOnlyInputThreshold;

    // Update the input immediately so the UI reflects the change.
    // For large inputs, don't store output yet (on-demand generation).
    state = state.copyWith(
      input: value,
      output: '',
      isProcessing: isLarge,
      inputSize: inputSize,
      isOnDemandOutput: isOnDemandOutput,
      disableSyntaxHighlighting: disableSyntaxHighlighting,
      isReadOnlyMode: isReadOnlyMode,
    );

    // Quick empty check
    if (value.trim().isEmpty) {
      state = state.copyWith(
        validationResult: const JsonValidationResult(
          isValid: false,
          isEmpty: true,
        ),
        isProcessing: false,
        inputSize: 0,
        isOnDemandOutput: false,
        disableSyntaxHighlighting: false,
        isReadOnlyMode: false,
      );
      return;
    }

    // Quick heuristic check - prevents obvious invalid inputs from spawning isolates
    if (!JsonValidator.isPotentiallyValid(value)) {
      state = state.copyWith(
        validationResult: JsonValidationResult(
          isValid: false,
          errorMessage: 'Invalid JSON',
        ),
        isProcessing: false,
      );
      return;
    }

    // Perform full validation in an isolate
    final validationResult = await JsonValidator.validateAsync(value);

    // If a newer validation started, discard this result
    if (myId != _validationId) return;

    // Update state with validation result
    state = state.copyWith(validationResult: validationResult);

    if (validationResult.isValid) {
      try {
        // For on-demand output mode, skip caching formatted output
        // to save memory on large inputs.
        String formatted = '';
        if (!isOnDemandOutput) {
          formatted = await JsonFormatter.formatObjectAsync(
            validationResult.data,
          );
        }

        if (myId != _validationId) return; // check again after async work
        state = state.copyWith(
          input: value,
          output: formatted,
          isProcessing: false,
        );
      } catch (_) {
        if (myId != _validationId) return;
        state = state.copyWith(output: '', isProcessing: false);
      }
    } else {
      state = state.copyWith(output: '', isProcessing: false);
    }
  }

  /// Updates the input from an already-parsed JSON object.
  Future<void> updateFromParsedData(dynamic data) async {
    try {
      final formatted = await JsonFormatter.formatObjectAsync(data);
      await updateInput(formatted);
    } catch (_) {}
  }

  /// Gets the formatted output, generating on-demand if needed.
  Future<String> getFormattedOutput() async {
    if (state.output.isNotEmpty) {
      return state.output;
    }
    if (state.parsedData != null) {
      return await JsonFormatter.formatObjectAsync(state.parsedData);
    }
    return '';
  }

  /// Formats the current input JSON with 2-space indentation.
  Future<void> format() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      String formatted;
      if (state.parsedData != null) {
        formatted = await JsonFormatter.formatObjectAsync(state.parsedData);
      } else {
        formatted = await JsonFormatter.formatAsync(state.input);
      }
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Validation already failed or formatting failed, no need to update
    }
  }

  /// Minifies the current input JSON (async, using isolate).
  Future<void> minify() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      String minified;
      if (state.parsedData != null) {
        // Use async version to avoid blocking UI
        minified = await JsonFormatter.minifyObjectAsync(state.parsedData);
      } else {
        minified = await JsonFormatter.minifyAsync(state.input);
      }
      state = state.copyWith(input: minified, output: minified);
    } catch (_) {
      // Validation already failed or minify failed
    }
  }

  /// Sorts all keys in the JSON alphabetically (async, using isolate).
  Future<void> sortKeys({bool ascending = true}) async {
    if (!state.isValid || state.isEmpty) return;

    try {
      // Use async version for large data
      final sorted = await JsonTransformerAsync.sortKeysAsync(
        state.parsedData,
        ascending: ascending,
      );
      final formatted = await JsonFormatter.formatObjectAsync(sorted);
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Error handling
    }
  }

  /// Removes null values from the JSON (async, using isolate).
  Future<void> removeNulls() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      // Use async version for large data
      final cleaned = await JsonTransformerAsync.removeNullsAsync(
        state.parsedData,
      );
      final formatted = await JsonFormatter.formatObjectAsync(cleaned);
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Error handling
    }
  }

  /// Removes empty values from the JSON (async, using isolate).
  Future<void> removeEmpty() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      // Use async version for large data
      final cleaned = await JsonTransformerAsync.removeEmptyAsync(
        state.parsedData,
      );
      if (cleaned != null) {
        final formatted = await JsonFormatter.formatObjectAsync(cleaned);
        state = state.copyWith(input: formatted, output: formatted);
      }
    } catch (_) {
      // Error handling
    }
  }

  /// Flattens the JSON structure (async, using isolate).
  Future<void> flatten() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      // Use async version for large data
      final flattened = await JsonTransformerAsync.flattenAsync(
        state.parsedData,
      );
      final formatted = await JsonFormatter.formatObjectAsync(flattened);
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Error handling
    }
  }

  /// Clears all input and output.
  void clear() {
    state = const JsonAnalyzerState();
  }

  /// Sets the input from clipboard paste.
  Future<void> pasteFromClipboard(String text) async {
    await updateInput(text);
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

/// Provider for the raw input.
final inputProvider = Provider<String>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.input));
});

/// Provider for checking if processing is in progress.
final isProcessingProvider = Provider<bool>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.isProcessing));
});

/// Provider for input size.
final inputSizeProvider = Provider<int>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.inputSize));
});

/// Provider for checking if output is on-demand (not cached).
final isOnDemandOutputProvider = Provider<bool>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.isOnDemandOutput));
});

/// Provider for checking if syntax highlighting should be disabled.
final disableSyntaxHighlightingProvider = Provider<bool>((ref) {
  return ref.watch(
    jsonAnalyzerProvider.select((s) => s.disableSyntaxHighlighting),
  );
});

/// Provider for checking if read-only mode is enabled.
final isReadOnlyModeProvider = Provider<bool>((ref) {
  return ref.watch(jsonAnalyzerProvider.select((s) => s.isReadOnlyMode));
});

// ============================================================================
// Editor ↔ Tree Sync Providers (ROADMAP 2.5)
// ============================================================================

/// The 0-based line of the editor cursor.
///
/// Updated by [JsonInputArea] when the user moves the insertion point.
/// Read by [JsonTreeViewWidget] to highlight the corresponding tree node.
final editorCursorLineProvider = StateProvider<int>((ref) => -1);

/// The JSON path of the tree node most recently selected by the user.
///
/// Updated by [JsonTreeViewWidget] when a node is tapped.
/// Read by [JsonInputArea] to scroll the editor to the matching line.
final treeSelectedPathProvider = StateProvider<String>((ref) => '');

// ============================================================================
// Statistics Provider
// ============================================================================

final statisticsProvider = Provider<JsonStatistics>((ref) {
  final state = ref.watch(jsonAnalyzerProvider);

  if (!state.isValid || state.isEmpty || state.parsedData == null) {
    return JsonStatistics.empty();
  }

  return JsonStatistics.fromJson(state.parsedData, state.input);
});
