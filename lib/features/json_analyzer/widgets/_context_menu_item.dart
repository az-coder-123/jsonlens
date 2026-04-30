part of 'lazy_json_tree.dart';

// ---------------------------------------------------------------------------
// Context menu item widget
// ---------------------------------------------------------------------------

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimensions.iconSizeS, color: color),
        const SizedBox(width: AppDimensions.paddingS),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: color,
          ),
        ),
      ],
    );
  }
}
