import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class LazyInlineEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  const LazyInlineEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onCommit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              onCancel();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: hasError ? AppColors.error : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: hasError ? AppColors.error : AppColors.borderFocused,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: hasError ? AppColors.error : AppColors.borderFocused,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: hasError ? AppColors.error : AppColors.primary,
                  width: 1.5,
                ),
              ),
              hintText: 'Enter value...',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textMuted,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Apply (Enter)',
                    child: InkWell(
                      onTap: onCommit,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Cancel (Escape)',
                    child: InkWell(
                      onTap: onCancel,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => onCommit(),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2),
            child: Text(
              errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 10),
            ),
          ),
      ],
    );
  }
}
