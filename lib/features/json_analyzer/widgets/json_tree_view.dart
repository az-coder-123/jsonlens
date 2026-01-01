import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/settings/settings_provider.dart';
import '../providers/json_analyzer_provider.dart';
import 'depth_dialog.dart';
import 'lazy_json_tree.dart';
import 'processing_overlay.dart';

/// Tree view widget for displaying JSON in an expandable/collapsible tree structure.
class JsonTreeViewWidget extends ConsumerWidget {
  const JsonTreeViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedData = ref.watch(parsedDataProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, ref),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                _buildContent(
                  parsedData: parsedData,
                  isValid: isValid,
                  isEmpty: isEmpty,
                  ref: ref,
                ),
                if (isProcessing)
                  const ProcessingOverlay(message: 'Processing large JSON...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusM),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_tree,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            AppStrings.treeViewTab,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _buildSettingsButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildContent({
    required dynamic parsedData,
    required bool isValid,
    required bool isEmpty,
    required WidgetRef ref,
  }) {
    if (isEmpty || !isValid || parsedData == null) {
      return _buildPlaceholder();
    }

    return _buildTreeView(parsedData, ref);
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        AppStrings.outputPlaceholder,
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return IconButton(
      tooltip: 'Tree settings',
      icon: const Icon(Icons.settings, color: AppColors.textSecondary),
      onPressed: () async {
        final selected = await showDialog<int>(
          context: context,
          builder: (context) {
            return DepthDialog(initial: settings.defaultExpandedDepth);
          },
        );
        if (selected != null) {
          await ref
              .read(settingsProvider.notifier)
              .setDefaultExpandedDepth(selected);
        }
      },
    );
  }

  Widget _buildTreeView(dynamic data, WidgetRef ref) {
    final defaultDepth = ref.watch(settingsProvider).defaultExpandedDepth;
    return LazyJsonTree(data: data, defaultExpandedDepth: defaultDepth);
  }
}
