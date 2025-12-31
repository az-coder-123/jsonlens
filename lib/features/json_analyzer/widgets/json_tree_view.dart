import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/json_analyzer_provider.dart';

/// Tree view widget for displaying JSON in an expandable/collapsible tree structure.
class JsonTreeViewWidget extends ConsumerWidget {
  const JsonTreeViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedData = ref.watch(parsedDataProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: _buildContent(
              parsedData: parsedData,
              isValid: isValid,
              isEmpty: isEmpty,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        ],
      ),
    );
  }

  Widget _buildContent({
    required dynamic parsedData,
    required bool isValid,
    required bool isEmpty,
  }) {
    if (isEmpty || !isValid || parsedData == null) {
      return _buildPlaceholder();
    }

    return _buildTreeView(parsedData);
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

  Widget _buildTreeView(dynamic data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: JsonView.map(
        data is Map<String, dynamic> ? data : {'root': data},
        theme: JsonViewTheme(
          backgroundColor: Colors.transparent,
          keyStyle: GoogleFonts.jetBrainsMono(
            color: AppColors.jsonKey,
            fontSize: AppDimensions.fontSizeM,
          ),
          stringStyle: GoogleFonts.jetBrainsMono(
            color: AppColors.jsonString,
            fontSize: AppDimensions.fontSizeM,
          ),
          boolStyle: GoogleFonts.jetBrainsMono(
            color: AppColors.jsonBoolean,
            fontSize: AppDimensions.fontSizeM,
          ),
          openIcon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
            size: AppDimensions.iconSizeM,
          ),
          closeIcon: const Icon(
            Icons.arrow_right,
            color: AppColors.textSecondary,
            size: AppDimensions.iconSizeM,
          ),
          separator: const Text(': '),
        ),
      ),
    );
  }
}
