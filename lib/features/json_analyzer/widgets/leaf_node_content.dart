import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class LazyLeafNodeContent extends StatelessWidget {
  final bool isEditing;
  final Widget typeIcon;
  final Widget keyWidget;
  final Widget valueWidget;
  final Widget inlineEditor;
  final bool canEdit;
  final VoidCallback onEdit;
  final Widget copyButton;

  const LazyLeafNodeContent({
    super.key,
    required this.isEditing,
    required this.typeIcon,
    required this.keyWidget,
    required this.valueWidget,
    required this.inlineEditor,
    required this.canEdit,
    required this.onEdit,
    required this.copyButton,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Row(
        children: [
          typeIcon,
          Flexible(child: keyWidget),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(child: inlineEditor),
        ],
      );
    }

    return Row(
      children: [
        typeIcon,
        Flexible(child: keyWidget),
        const SizedBox(width: AppDimensions.paddingS),
        Expanded(child: valueWidget),
        if (canEdit)
          Tooltip(
            message: 'Edit value (double-click)',
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.edit, size: 11, color: AppColors.textMuted),
              ),
            ),
          ),
        copyButton,
      ],
    );
  }
}
