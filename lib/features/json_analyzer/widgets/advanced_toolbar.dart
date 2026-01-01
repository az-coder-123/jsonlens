import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../providers/json_analyzer_provider.dart';

/// Advanced toolbar with transformation options.
class AdvancedToolbar extends ConsumerWidget {
  /// Callback for showing feedback messages.
  final void Function(String message) onShowMessage;

  const AdvancedToolbar({super.key, required this.onShowMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final canTransform = isValid && !isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildDropdownButton(
              context: context,
              label: 'Transform',
              icon: Icons.transform,
              enabled: canTransform,
              items: [
                _MenuItem(
                  icon: Icons.sort_by_alpha,
                  label: 'Sort Keys (A-Z)',
                  onTap: () => _handleSortKeysAsc(ref),
                ),
                _MenuItem(
                  icon: Icons.sort_by_alpha,
                  label: 'Sort Keys (Z-A)',
                  onTap: () => _handleSortKeysDesc(ref),
                ),
                _MenuItem(
                  icon: Icons.compress,
                  label: 'Flatten',
                  onTap: () => _handleFlatten(ref),
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.paddingS),
            _buildDropdownButton(
              context: context,
              label: 'Clean',
              icon: Icons.cleaning_services,
              enabled: canTransform,
              items: [
                _MenuItem(
                  icon: Icons.delete_outline,
                  label: 'Remove Nulls',
                  onTap: () => _handleRemoveNulls(ref),
                ),
                _MenuItem(
                  icon: Icons.delete_sweep,
                  label: 'Remove Empty',
                  onTap: () => _handleRemoveEmpty(ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool enabled,
    required List<_MenuItem> items,
  }) {
    return PopupMenuButton<_MenuItem>(
      enabled: enabled,
      tooltip: label,
      offset: const Offset(0, 40),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (item) => item.onTap(),
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<_MenuItem>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: AppDimensions.iconSizeS,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  Text(
                    item.label,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          border: Border.all(
            color: enabled
                ? AppColors.border
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeS,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
            const SizedBox(width: AppDimensions.paddingXS),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: AppDimensions.fontSizeM,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingXS),
            Icon(
              Icons.arrow_drop_down,
              size: AppDimensions.iconSizeS,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSortKeysAsc(WidgetRef ref) {
    ref.read(jsonAnalyzerProvider.notifier).sortKeys(ascending: true);
    onShowMessage('Keys sorted (A-Z)');
  }

  void _handleSortKeysDesc(WidgetRef ref) {
    ref.read(jsonAnalyzerProvider.notifier).sortKeys(ascending: false);
    onShowMessage('Keys sorted (Z-A)');
  }

  void _handleFlatten(WidgetRef ref) {
    ref.read(jsonAnalyzerProvider.notifier).flatten();
    onShowMessage('JSON flattened');
  }

  void _handleRemoveNulls(WidgetRef ref) {
    ref.read(jsonAnalyzerProvider.notifier).removeNulls();
    onShowMessage('Null values removed');
  }

  void _handleRemoveEmpty(WidgetRef ref) {
    ref.read(jsonAnalyzerProvider.notifier).removeEmpty();
    onShowMessage('Empty values removed');
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.label, required this.onTap});
}
