import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/performance_constants.dart';
import '../providers/json_analyzer_provider.dart';
import 'processing_overlay.dart';

/// Output area widget for displaying formatted JSON with syntax highlighting.
///
/// For large JSON files (>1MB), syntax highlighting is disabled and plain
/// text is displayed instead to maintain UI responsiveness. For large plain
/// text outputs we use virtualization (ListView.builder) to render only the
/// visible lines, significantly reducing memory and layout cost.
class JsonOutputArea extends ConsumerStatefulWidget {
  const JsonOutputArea({super.key});

  @override
  ConsumerState<JsonOutputArea> createState() => _JsonOutputAreaState();
}

class _JsonOutputAreaState extends ConsumerState<JsonOutputArea> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final output = ref.watch(outputProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final errorMessage = ref.watch(errorMessageProvider);
    final isProcessing = ref.watch(isProcessingProvider);
    final disableSyntaxHighlighting = ref.watch(
      disableSyntaxHighlightingProvider,
    );
    final isOnDemandOutput = ref.watch(isOnDemandOutputProvider);
    final inputSize = ref.watch(inputSizeProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(
            disableSyntaxHighlighting: disableSyntaxHighlighting,
            inputSize: inputSize,
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                _buildContent(
                  ref: ref,
                  output: output,
                  isValid: isValid,
                  isEmpty: isEmpty,
                  errorMessage: errorMessage,
                  disableSyntaxHighlighting: disableSyntaxHighlighting,
                  isOnDemandOutput: isOnDemandOutput,
                  inputSize: inputSize,
                ),
                if (isProcessing)
                  const ProcessingOverlay(message: 'Formatting JSON...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required bool disableSyntaxHighlighting,
    required int inputSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusM),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.code,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            AppStrings.formattedTab,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Show size and mode indicator for large files
          if (inputSize > 0) ...[
            _buildSizeIndicator(inputSize),
            if (disableSyntaxHighlighting) ...[
              const SizedBox(width: AppDimensions.paddingS),
              _buildPlainTextBadge(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSizeIndicator(int size) {
    final sizeStr = _formatSize(size);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Text(
        sizeStr,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildPlainTextBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Text(
        'Plain Text',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: AppColors.warning,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildContent({
    required WidgetRef ref,
    required String output,
    required bool isValid,
    required bool isEmpty,
    required String errorMessage,
    required bool disableSyntaxHighlighting,
    required bool isOnDemandOutput,
    required int inputSize,
  }) {
    if (isEmpty) {
      return _buildPlaceholder();
    }

    if (!isValid) {
      return _buildError(errorMessage);
    }

    // For on-demand output, we need to generate it async
    if (isOnDemandOutput && output.isEmpty) {
      return _buildOnDemandOutput(ref, disableSyntaxHighlighting, inputSize);
    }

    // Use plain text for large files to avoid UI lag
    if (disableSyntaxHighlighting) {
      return _buildPlainTextJson(output, inputSize);
    }

    return _buildHighlightedJson(output);
  }

  Widget _buildOnDemandOutput(
    WidgetRef ref,
    bool disableSyntaxHighlighting,
    int inputSize,
  ) {
    return FutureBuilder<String>(
      future: ref.read(jsonAnalyzerProvider.notifier).getFormattedOutput(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: AppDimensions.paddingM),
                Text(
                  'Generating output...',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildPlaceholder();
        }

        final output = snapshot.data!;
        if (disableSyntaxHighlighting) {
          return _buildPlainTextJson(output, inputSize);
        }
        return _buildHighlightedJson(output);
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        AppStrings.outputPlaceholder,
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildError(String errorMessage) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.paddingS),
              Text(
                AppStrings.parseError,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeM,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            errorMessage,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Plain text rendering for large JSON files.
  /// Avoids expensive syntax highlighting for better performance.
  /// For sufficiently large outputs we use a virtualized list to render
  /// only visible lines and reduce memory & layout cost.
  Widget _buildPlainTextJson(String output, int inputSize) {
    // Split by lines once and reuse.
    final lines = const LineSplitter().convert(output);

    // If output is small enough, render as a single SelectableText for
    // convenient selection and copy behavior.
    if (inputSize <= PerformanceConstants.plainTextVirtualizationThreshold) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SelectableText(
          output,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeM,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      );
    }

    // For larger outputs, use ListView.builder to only build visible lines.
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        return Text(
          lines[index],
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeM,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        );
      },
    );
  }

  Widget _buildHighlightedJson(String output) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: HighlightView(
        output,
        language: 'json',
        theme: atomOneDarkTheme,
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          height: 1.5,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
