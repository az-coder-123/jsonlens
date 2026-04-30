import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class TypeFilterBar extends StatelessWidget {
  final Set<String> hiddenTypes;
  final Color Function(String type) typeColor;
  final ValueChanged<String> onToggleType;
  final VoidCallback onReset;

  const TypeFilterBar({
    super.key,
    required this.hiddenTypes,
    required this.typeColor,
    required this.onToggleType,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('object', '{}'),
      ('array', '[]'),
      ('string', '"'),
      ('number', '#'),
      ('boolean', 'T/F'),
      ('null', '∅'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: 6,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            'Show:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          ...filters.map((f) {
            final type = f.$1;
            final label = f.$2;
            final isVisible = !hiddenTypes.contains(type);
            final color = typeColor(type);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: isVisible ? 'Hide $type nodes' : 'Show $type nodes',
                child: InkWell(
                  onTap: () => onToggleType(type),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isVisible
                          ? color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isVisible
                            ? color.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isVisible ? color : AppColors.textMuted,
                        decoration: isVisible
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          if (hiddenTypes.isNotEmpty)
            GestureDetector(
              onTap: onReset,
              child: Text(
                'Reset',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
