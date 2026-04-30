part of 'json_tree_view.dart';

// ---------------------------------------------------------------------------
// Search match count badge
// ---------------------------------------------------------------------------

/// Pill badge showing the number of search matches.
class _SearchCountBadge extends StatelessWidget {
  final int count;

  const _SearchCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: count > 0 ? AppColors.primary : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
