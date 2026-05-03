import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_differ.dart';
import '../../../core/utils/json_validator.dart';
import '../models/json_diff_result.dart';
import 'json_analyzer_provider.dart';

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
