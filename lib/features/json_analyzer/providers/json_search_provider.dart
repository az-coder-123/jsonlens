import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_searcher.dart';
import '../models/json_search_result.dart';
import 'json_analyzer_provider.dart';

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
