import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';

/// A reusable error display widget with two layout variants.
///
/// Use [ErrorDisplay.centered] for panel centers (large icon + message).
/// Use [ErrorDisplay.inline] for output areas (icon + title row + detail text).
class ErrorDisplay extends StatelessWidget {
  final String message;
  final _ErrorVariant _variant;

  /// Centered layout: large icon above the error message.
  ///
  /// Suitable for empty-state panels (JSON Path, Diff, etc.).
  const ErrorDisplay.centered(this.message, {super.key})
    : _variant = _ErrorVariant.centered;

  /// Inline layout: small icon + "Parse Error" title, detail below.
  ///
  /// Suitable for output areas and the main screen error state.
  const ErrorDisplay.inline(this.message, {super.key})
    : _variant = _ErrorVariant.inline;

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      _ErrorVariant.centered => _buildCentered(),
      _ErrorVariant.inline => _buildInline(),
    };
  }

  Widget _buildCentered() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            message,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInline() {
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
            message,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ErrorVariant { centered, inline }
