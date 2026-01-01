import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/json_analyzer_provider.dart';
import 'processing_overlay.dart';

/// Output area widget for displaying formatted JSON with syntax highlighting.
class JsonOutputArea extends ConsumerWidget {
  const JsonOutputArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final output = ref.watch(outputProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final errorMessage = ref.watch(errorMessageProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                _buildContent(
                  output: output,
                  isValid: isValid,
                  isEmpty: isEmpty,
                  errorMessage: errorMessage,
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

  Widget _buildHeader() {
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
        ],
      ),
    );
  }

  Widget _buildContent({
    required String output,
    required bool isValid,
    required bool isEmpty,
    required String errorMessage,
  }) {
    if (isEmpty) {
      return _buildPlaceholder();
    }

    if (!isValid) {
      return _buildError(errorMessage);
    }

    return _buildHighlightedJson(output);
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
