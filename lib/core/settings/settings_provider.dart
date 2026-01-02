import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/performance_constants.dart';

/// Application settings including performance thresholds.
class Settings {
  /// Default depth for tree view expansion.
  final int defaultExpandedDepth;

  /// Threshold (bytes) for showing processing indicator.
  final int processingIndicatorThreshold;

  /// Threshold (bytes) for disabling syntax highlighting.
  final int syntaxHighlightingThreshold;

  /// Threshold (bytes) for enabling read-only input mode.
  final int readOnlyInputThreshold;

  /// Threshold (bytes) for generating output on-demand vs caching.
  final int onDemandOutputThreshold;

  /// Maximum allowed file size (bytes).
  final int maxFileSize;

  const Settings({
    this.defaultExpandedDepth = 0,
    this.processingIndicatorThreshold =
        PerformanceConstants.processingIndicatorThreshold,
    this.syntaxHighlightingThreshold =
        PerformanceConstants.syntaxHighlightingThreshold,
    this.readOnlyInputThreshold = PerformanceConstants.readOnlyInputThreshold,
    this.onDemandOutputThreshold = PerformanceConstants.onDemandOutputThreshold,
    this.maxFileSize = PerformanceConstants.maxRecommendedSize,
  });

  Settings copyWith({
    int? defaultExpandedDepth,
    int? processingIndicatorThreshold,
    int? syntaxHighlightingThreshold,
    int? readOnlyInputThreshold,
    int? onDemandOutputThreshold,
    int? maxFileSize,
  }) {
    return Settings(
      defaultExpandedDepth: defaultExpandedDepth ?? this.defaultExpandedDepth,
      processingIndicatorThreshold:
          processingIndicatorThreshold ?? this.processingIndicatorThreshold,
      syntaxHighlightingThreshold:
          syntaxHighlightingThreshold ?? this.syntaxHighlightingThreshold,
      readOnlyInputThreshold:
          readOnlyInputThreshold ?? this.readOnlyInputThreshold,
      onDemandOutputThreshold:
          onDemandOutputThreshold ?? this.onDemandOutputThreshold,
      maxFileSize: maxFileSize ?? this.maxFileSize,
    );
  }

  /// Check if input size exceeds processing indicator threshold.
  bool shouldShowProcessingIndicator(int size) =>
      size > processingIndicatorThreshold;

  /// Check if input size exceeds syntax highlighting threshold.
  bool shouldDisableSyntaxHighlighting(int size) =>
      size > syntaxHighlightingThreshold;

  /// Check if input size exceeds read-only threshold.
  bool shouldEnableReadOnlyMode(int size) => size > readOnlyInputThreshold;

  /// Check if output should be generated on-demand instead of cached.
  bool shouldUseOnDemandOutput(int size) => size > onDemandOutputThreshold;

  /// Check if file size exceeds maximum allowed.
  bool exceedsMaxFileSize(int size) => size > maxFileSize;
}

class SettingsNotifier extends StateNotifier<Settings> {
  static const _keyDefaultDepth = 'default_expanded_depth';

  SettingsNotifier() : super(const Settings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final depth = prefs.getInt(_keyDefaultDepth) ?? state.defaultExpandedDepth;
    state = state.copyWith(defaultExpandedDepth: depth);
  }

  Future<void> setDefaultExpandedDepth(int depth) async {
    state = state.copyWith(defaultExpandedDepth: depth);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultDepth, depth);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((
  ref,
) {
  return SettingsNotifier();
});
