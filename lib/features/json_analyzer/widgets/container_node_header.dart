import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class LazyContainerNodeHeader extends StatelessWidget {
  final bool expanded;
  final Widget typeIcon;
  final Widget keyWidget;
  final Widget valueWidget;
  final VoidCallback onTap;
  final Widget copyButton;

  const LazyContainerNodeHeader({
    super.key,
    required this.expanded,
    required this.typeIcon,
    required this.keyWidget,
    required this.valueWidget,
    required this.onTap,
    required this.copyButton,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: AppDimensions.iconSizeS,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 2),
            typeIcon,
            Flexible(child: keyWidget),
            const SizedBox(width: AppDimensions.paddingS),
            Expanded(child: valueWidget),
            copyButton,
          ],
        ),
      ),
    );
  }
}
