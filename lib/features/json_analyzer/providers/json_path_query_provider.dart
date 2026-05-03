import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_transformer.dart';
import 'json_analyzer_provider.dart';

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
