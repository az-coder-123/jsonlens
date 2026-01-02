import 'package:flutter/foundation.dart';

/// Represents the result of a JSON validation operation.
@immutable
class JsonValidationResult {
  /// Whether the JSON is valid.
  final bool isValid;

  /// Whether the input was empty.
  final bool isEmpty;

  /// The parsed JSON data if valid.
  final dynamic data;

  /// The error message if invalid.
  final String? errorMessage;

  /// The character offset where the error occurred.
  final int? errorOffset;

  /// The line number where the error occurred (1-based).
  final int? lineNumber;

  const JsonValidationResult({
    required this.isValid,
    this.isEmpty = false,
    this.data,
    this.errorMessage,
    this.errorOffset,
    this.lineNumber,
  });

  /// Returns a formatted error description for display.
  String get displayError {
    if (isEmpty) {
      return '';
    }
    if (isValid) {
      return '';
    }

    final buffer = StringBuffer();

    if (lineNumber != null) {
      buffer.write('Line $lineNumber: ');
    }

    buffer.write(errorMessage ?? 'Invalid JSON');

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JsonValidationResult &&
        other.isValid == isValid &&
        other.isEmpty == isEmpty &&
        other.errorMessage == errorMessage &&
        other.errorOffset == errorOffset &&
        other.lineNumber == lineNumber;
  }

  @override
  int get hashCode {
    return Object.hash(isValid, isEmpty, errorMessage, errorOffset, lineNumber);
  }
}

/// Represents the state of the JSON analyzer.
@immutable
class JsonAnalyzerState {
  /// The raw input JSON string.
  final String input;

  /// The formatted JSON output.
  /// For large inputs, this may be empty and generated on-demand.
  final String output;

  /// The validation result.
  final JsonValidationResult validationResult;

  /// The currently selected output view tab index.
  final int selectedTabIndex;

  /// Whether async processing is in progress.
  final bool isProcessing;

  /// Size of the input in bytes (for threshold checks).
  final int inputSize;

  /// Whether output is generated on-demand (not cached).
  /// True for large inputs to save memory.
  final bool isOnDemandOutput;

  /// Whether input should be read-only (for very large files).
  final bool isReadOnlyMode;

  /// Whether syntax highlighting should be disabled.
  final bool disableSyntaxHighlighting;

  const JsonAnalyzerState({
    this.input = '',
    this.output = '',
    this.validationResult = const JsonValidationResult(
      isValid: false,
      isEmpty: true,
    ),
    this.selectedTabIndex = 0,
    this.isProcessing = false,
    this.inputSize = 0,
    this.isOnDemandOutput = false,
    this.isReadOnlyMode = false,
    this.disableSyntaxHighlighting = false,
  });

  /// Whether the current JSON is valid.
  bool get isValid => validationResult.isValid;

  /// Whether the input is empty.
  bool get isEmpty => validationResult.isEmpty;

  /// The error message if JSON is invalid.
  String get errorMessage => validationResult.displayError;

  /// The parsed JSON data if valid.
  dynamic get parsedData => validationResult.data;

  /// Creates a copy of this state with the given fields replaced.
  JsonAnalyzerState copyWith({
    String? input,
    String? output,
    JsonValidationResult? validationResult,
    int? selectedTabIndex,
    bool? isProcessing,
    int? inputSize,
    bool? isOnDemandOutput,
    bool? isReadOnlyMode,
    bool? disableSyntaxHighlighting,
  }) {
    return JsonAnalyzerState(
      input: input ?? this.input,
      output: output ?? this.output,
      validationResult: validationResult ?? this.validationResult,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      isProcessing: isProcessing ?? this.isProcessing,
      inputSize: inputSize ?? this.inputSize,
      isOnDemandOutput: isOnDemandOutput ?? this.isOnDemandOutput,
      isReadOnlyMode: isReadOnlyMode ?? this.isReadOnlyMode,
      disableSyntaxHighlighting:
          disableSyntaxHighlighting ?? this.disableSyntaxHighlighting,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JsonAnalyzerState &&
        other.input == input &&
        other.output == output &&
        other.validationResult == validationResult &&
        other.selectedTabIndex == selectedTabIndex &&
        other.isProcessing == isProcessing &&
        other.inputSize == inputSize &&
        other.isOnDemandOutput == isOnDemandOutput &&
        other.isReadOnlyMode == isReadOnlyMode &&
        other.disableSyntaxHighlighting == disableSyntaxHighlighting;
  }

  @override
  int get hashCode {
    return Object.hash(
      input,
      output,
      validationResult,
      selectedTabIndex,
      isProcessing,
      inputSize,
      isOnDemandOutput,
      isReadOnlyMode,
      disableSyntaxHighlighting,
    );
  }
}
