part of 'json_tree_view.dart';

// ---------------------------------------------------------------------------
// Search bar helper widgets
// ---------------------------------------------------------------------------

/// Small icon button used in the search bar action group.
class _SearchIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _SearchIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(
          icon,
          size: AppDimensions.iconSizeS,
          color: active ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
