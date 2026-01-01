import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_differ.dart';
import '../../../core/utils/json_formatter.dart';
import '../../../core/utils/json_searcher.dart';
import '../../../core/utils/json_transformer.dart';
import '../../../core/utils/json_validator.dart';
import '../models/json_diff_result.dart';
import '../models/json_result.dart';
import '../models/json_search_result.dart';
import '../models/json_statistics.dart';

/// StateNotifier for managing JSON analyzer state.
///
/// Handles input changes, formatting, minification, and validation.
class JsonAnalyzerNotifier extends StateNotifier<JsonAnalyzerState> {
  JsonAnalyzerNotifier() : super(const JsonAnalyzerState());

  /// Updates the input and validates/formats it.
  int _validationId = 0;

  Future<void> updateInput(String value) async {
    // Increment validation id to allow cancellation of stale validations.
    final myId = ++_validationId;

    // Update the input immediately so the UI reflects the change.
    // Show loading indicator for large payloads (>50KB)
    final isLarge = value.length > 50000;
    state = state.copyWith(input: value, output: '', isProcessing: isLarge);

    // Quick empty check
    if (value.trim().isEmpty) {
      state = state.copyWith(
        validationResult: const JsonValidationResult(
          isValid: false,
          isEmpty: true,
        ),
        isProcessing: false,
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
        final formatted = await JsonFormatter.formatObjectAsync(
          validationResult.data,
        );
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

  /// Minifies the current input JSON.
  Future<void> minify() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      String minified;
      if (state.parsedData != null) {
        minified = JsonEncoder().convert(state.parsedData);
      } else {
        minified = await JsonFormatter.minifyAsync(state.input);
      }
      state = state.copyWith(input: minified, output: minified);
    } catch (_) {
      // Validation already failed or minify failed
    }
  }

  /// Sorts all keys in the JSON alphabetically.
  Future<void> sortKeys({bool ascending = true}) async {
    if (!state.isValid || state.isEmpty) return;

    try {
      final sorted = JsonTransformer.sortKeys(
        state.parsedData,
        ascending: ascending,
      );
      final formatted = await JsonFormatter.formatObjectAsync(sorted);
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Error handling
    }
  }

  /// Removes null values from the JSON.
  Future<void> removeNulls() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      final cleaned = JsonTransformer.removeNulls(state.parsedData);
      final formatted = await JsonFormatter.formatObjectAsync(cleaned);
      state = state.copyWith(input: formatted, output: formatted);
    } catch (_) {
      // Error handling
    }
  }

  /// Removes empty values from the JSON.
  Future<void> removeEmpty() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      final cleaned = JsonTransformer.removeEmpty(state.parsedData);
      if (cleaned != null) {
        final formatted = await JsonFormatter.formatObjectAsync(cleaned);
        state = state.copyWith(input: formatted, output: formatted);
      }
    } catch (_) {
      // Error handling
    }
  }

  /// Flattens the JSON structure.
  Future<void> flatten() async {
    if (!state.isValid || state.isEmpty) return;

    try {
      final flattened = JsonTransformer.flatten(state.parsedData);
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

// ============================================================================
// Search Feature Providers
// ============================================================================

/// State for search functionality.
class SearchState {
  final String query;
  final JsonSearchOptions options;
  final List<JsonSearchResult> results;
  final int currentResultIndex;
  final bool isSearching;

  const SearchState({
    this.query = '',
    this.options = const JsonSearchOptions(),
    this.results = const [],
    this.currentResultIndex = -1,
    this.isSearching = false,
  });

  SearchState copyWith({
    String? query,
    JsonSearchOptions? options,
    List<JsonSearchResult>? results,
    int? currentResultIndex,
    bool? isSearching,
  }) {
    return SearchState(
      query: query ?? this.query,
      options: options ?? this.options,
      results: results ?? this.results,
      currentResultIndex: currentResultIndex ?? this.currentResultIndex,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

/// Notifier for search state.
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    if (query.isNotEmpty) {
      _performSearch();
    } else {
      state = state.copyWith(results: [], currentResultIndex: -1);
    }
  }

  void setOptions(JsonSearchOptions options) {
    state = state.copyWith(options: options);
    if (state.query.isNotEmpty) {
      _performSearch();
    }
  }

  void toggleSearchKeys() {
    setOptions(state.options.copyWith(searchKeys: !state.options.searchKeys));
  }

  void toggleSearchValues() {
    setOptions(
      state.options.copyWith(searchValues: !state.options.searchValues),
    );
  }

  void toggleCaseSensitive() {
    setOptions(
      state.options.copyWith(caseSensitive: !state.options.caseSensitive),
    );
  }

  void toggleRegex() {
    setOptions(state.options.copyWith(useRegex: !state.options.useRegex));
  }

  void _performSearch() {
    final parsedData = _ref.read(parsedDataProvider);
    if (parsedData == null) {
      state = state.copyWith(results: [], currentResultIndex: -1);
      return;
    }

    state = state.copyWith(isSearching: true);

    try {
      final results = JsonSearcher.search(
        parsedData,
        state.query,
        state.options,
      );
      state = state.copyWith(
        results: results,
        currentResultIndex: results.isNotEmpty ? 0 : -1,
        isSearching: false,
      );
    } catch (_) {
      state = state.copyWith(
        results: [],
        currentResultIndex: -1,
        isSearching: false,
      );
    }
  }

  void nextResult() {
    if (state.results.isEmpty) return;
    final nextIndex = (state.currentResultIndex + 1) % state.results.length;
    state = state.copyWith(currentResultIndex: nextIndex);
  }

  void previousResult() {
    if (state.results.isEmpty) return;
    final prevIndex = state.currentResultIndex <= 0
        ? state.results.length - 1
        : state.currentResultIndex - 1;
    state = state.copyWith(currentResultIndex: prevIndex);
  }

  void clearSearch() {
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(ref),
);

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

// ============================================================================
// JSON Diff/Compare Providers
// ============================================================================

/// State for JSON comparison.
class CompareState {
  final String secondJson;
  final JsonDiffResult? diffResult;
  final bool isComparing;
  final String? errorMessage;

  const CompareState({
    this.secondJson = '',
    this.diffResult,
    this.isComparing = false,
    this.errorMessage,
  });

  CompareState copyWith({
    String? secondJson,
    JsonDiffResult? diffResult,
    bool? isComparing,
    String? errorMessage,
  }) {
    return CompareState(
      secondJson: secondJson ?? this.secondJson,
      diffResult: diffResult ?? this.diffResult,
      isComparing: isComparing ?? this.isComparing,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for compare state.
class CompareNotifier extends StateNotifier<CompareState> {
  final Ref _ref;

  CompareNotifier(this._ref) : super(const CompareState());

  void setSecondJson(String json) {
    state = state.copyWith(secondJson: json, errorMessage: null);
  }

  void compare() {
    final firstData = _ref.read(parsedDataProvider);
    if (firstData == null) {
      state = state.copyWith(errorMessage: 'First JSON is invalid');
      return;
    }

    if (state.secondJson.isEmpty) {
      state = state.copyWith(errorMessage: 'Enter JSON to compare');
      return;
    }

    state = state.copyWith(isComparing: true);

    try {
      final validation = JsonValidator.validate(state.secondJson);
      if (!validation.isValid) {
        state = state.copyWith(
          isComparing: false,
          errorMessage: 'Second JSON is invalid: ${validation.errorMessage}',
        );
        return;
      }

      final diffResult = JsonDiffer.compare(firstData, validation.data);
      state = state.copyWith(
        diffResult: diffResult,
        isComparing: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isComparing: false,
        errorMessage: 'Comparison failed: $e',
      );
    }
  }

  void clearCompare() {
    state = const CompareState();
  }
}

final compareProvider = StateNotifierProvider<CompareNotifier, CompareState>(
  (ref) => CompareNotifier(ref),
);

// ============================================================================
// JSON Path Query Provider
// ============================================================================

/// State for JSON path query.
class PathQueryState {
  final String path;
  final dynamic result;
  final String? errorMessage;

  const PathQueryState({this.path = '', this.result, this.errorMessage});

  PathQueryState copyWith({
    String? path,
    dynamic result,
    String? errorMessage,
  }) {
    return PathQueryState(
      path: path ?? this.path,
      result: result,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for path query state.
class PathQueryNotifier extends StateNotifier<PathQueryState> {
  final Ref _ref;

  PathQueryNotifier(this._ref) : super(const PathQueryState());

  void setPath(String path) {
    state = state.copyWith(path: path, errorMessage: null);
  }

  void query() {
    final parsedData = _ref.read(parsedDataProvider);
    if (parsedData == null) {
      state = state.copyWith(errorMessage: 'JSON is invalid', result: null);
      return;
    }

    if (state.path.isEmpty) {
      state = state.copyWith(result: parsedData, errorMessage: null);
      return;
    }

    try {
      final result = JsonTransformer.getValueAtPath(parsedData, state.path);
      if (result == null) {
        state = state.copyWith(
          result: null,
          errorMessage: 'Path not found: ${state.path}',
        );
      } else {
        state = state.copyWith(result: result, errorMessage: null);
      }
    } catch (e) {
      state = state.copyWith(result: null, errorMessage: 'Query error: $e');
    }
  }

  void clear() {
    state = const PathQueryState();
  }
}

final pathQueryProvider =
    StateNotifierProvider<PathQueryNotifier, PathQueryState>(
      (ref) => PathQueryNotifier(ref),
    );
