/// Performance-related constants for handling large JSON files.
///
/// Defines thresholds and limits for optimizing performance
/// when processing large JSON content.
abstract final class PerformanceConstants {
  // ============================================================================
  // Size Thresholds (in bytes)
  // ============================================================================

  /// Threshold for showing processing indicator (50 KB).
  /// Above this size, show loading overlay during processing.
  static const int processingIndicatorThreshold = 50 * 1024; // 50 KB

  /// Threshold for disabling syntax highlighting (1 MB).
  /// Above this size, use plain text rendering instead.
  static const int syntaxHighlightingThreshold = 1 * 1024 * 1024; // 1 MB

  /// Threshold for enabling read-only mode on input (5 MB).
  /// Above this size, disable text editing to prevent UI lag.
  static const int readOnlyInputThreshold = 5 * 1024 * 1024; // 5 MB

  /// Maximum recommended file size for full processing (50 MB).
  /// Above this, suggest chunked view or streaming mode.
  static const int maxRecommendedSize = 50 * 1024 * 1024; // 50 MB

  /// Hard limit for file processing (100 MB).
  /// Above this, refuse to process and suggest alternatives.
  static const int hardLimit = 100 * 1024 * 1024; // 100 MB

  // ============================================================================
  // Mobile-specific Thresholds (lower due to memory constraints)
  // ============================================================================

  /// Syntax highlighting threshold for mobile (500 KB).
  static const int mobileSyntaxHighlightingThreshold = 500 * 1024; // 500 KB

  /// Read-only input threshold for mobile (2 MB).
  static const int mobileReadOnlyInputThreshold = 2 * 1024 * 1024; // 2 MB

  /// Max recommended size for mobile (10 MB).
  static const int mobileMaxRecommendedSize = 10 * 1024 * 1024; // 10 MB

  // ============================================================================
  // Tree View Constants
  // ============================================================================

  /// Number of children before using virtualized list.
  static const int treeVirtualizationThreshold = 32;

  /// Maximum depth for initial tree expansion.
  static const int maxAutoExpandDepth = 3;

  /// Batch size for lazy loading tree children.
  static const int treeLazyLoadBatchSize = 50;

  // ============================================================================
  // Debounce & Timing
  // ============================================================================

  /// Debounce duration for input changes (milliseconds).
  static const int inputDebounceMs = 300;

  /// Debounce duration for large inputs (milliseconds).
  static const int largeInputDebounceMs = 500;

  /// Timeout for isolate operations (seconds).
  static const int isolateTimeoutSeconds = 30;

  // ============================================================================
  // Memory Management
  // ============================================================================

  /// Threshold to avoid storing both input and output (1 MB).
  /// Above this, generate output on-demand instead of caching.
  static const int onDemandOutputThreshold = 1 * 1024 * 1024; // 1 MB
}
