import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/json_analyzer_provider.dart';

/// Status bar widget showing JSON validation status.
///
/// Displays "Valid JSON" (green) or "Invalid JSON" (red) based on the current state.
class ValidationIndicator extends ConsumerWidget {
  const ValidationIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final errorMessage = ref.watch(errorMessageProvider);

    return Container(
      height: AppDimensions.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _buildStatusIndicator(isValid: isValid, isEmpty: isEmpty),
          if (!isEmpty && !isValid) ...[
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Text(
                errorMessage,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({required bool isValid, required bool isEmpty}) {
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (isEmpty) {
      statusColor = AppColors.textMuted;
      statusText = AppStrings.emptyInput;
      statusIcon = Icons.edit_note;
    } else if (isValid) {
      statusColor = AppColors.success;
      statusText = AppStrings.validJson;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppColors.error;
      statusText = AppStrings.invalidJson;
      statusIcon = Icons.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, size: AppDimensions.iconSizeS, color: statusColor),
        const SizedBox(width: AppDimensions.paddingXS),
        Text(
          statusText,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
