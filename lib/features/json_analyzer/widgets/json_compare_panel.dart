import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/json_diff_result.dart';
import '../providers/json_analyzer_provider.dart';

/// Widget for comparing two JSON objects.
class JsonComparePanel extends ConsumerStatefulWidget {
  const JsonComparePanel({super.key});

  @override
  ConsumerState<JsonComparePanel> createState() => _JsonComparePanelState();
}

class _JsonComparePanelState extends ConsumerState<JsonComparePanel> {
  late final TextEditingController _secondJsonController;

  @override
  void initState() {
    super.initState();
    _secondJsonController = TextEditingController();
  }

  @override
  void dispose() {
    _secondJsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compareState = ref.watch(compareProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSecondJsonInput(compareState, isValid && !isEmpty),
        Expanded(child: _buildCompareResult(compareState)),
      ],
    );
  }

  Widget _buildSecondJsonInput(CompareState state, bool enabled) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JSON to Compare',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: enabled
                    ? () => ref.read(compareProvider.notifier).compare()
                    : null,
                icon: const Icon(
                  Icons.compare_arrows,
                  size: AppDimensions.iconSizeS,
                ),
                label: const Text('Compare'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Expanded(
            child: TextField(
              controller: _secondJsonController,
              enabled: enabled,
              onChanged: (value) {
                ref.read(compareProvider.notifier).setSecondJson(value);
              },
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeM,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Paste second JSON here...',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeM,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareResult(CompareState state) {
    if (state.errorMessage != null) {
      return _buildError(state.errorMessage!);
    }

    if (state.isComparing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.diffResult == null) {
      return _buildPlaceholder();
    }

    return _buildDiffResult(state.diffResult!);
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.compare_arrows,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'Enter JSON to compare',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            error,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiffResult(JsonDiffResult result) {
    if (result.isIdentical) {
      return _buildIdenticalMessage();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(result),
          const SizedBox(height: AppDimensions.paddingL),
          if (result.onlyInSecond.isNotEmpty) ...[
            _buildDiffSection(
              'Added',
              result.onlyInSecond,
              AppColors.success,
              Icons.add_circle,
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          if (result.onlyInFirst.isNotEmpty) ...[
            _buildDiffSection(
              'Removed',
              result.onlyInFirst,
              AppColors.error,
              Icons.remove_circle,
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          if (result.modified.isNotEmpty) ...[
            _buildDiffSection(
              'Modified',
              result.modified,
              AppColors.warning,
              Icons.edit,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdenticalMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 48, color: AppColors.success),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'JSONs are identical!',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(JsonDiffResult result) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Added',
            result.onlyInSecond.length,
            AppColors.success,
          ),
          _buildSummaryItem(
            'Removed',
            result.onlyInFirst.length,
            AppColors.error,
          ),
          _buildSummaryItem(
            'Modified',
            result.modified.length,
            AppColors.warning,
          ),
          _buildSummaryItem(
            'Unchanged',
            result.unchanged.length,
            AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeXL,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDiffSection(
    String title,
    List<JsonDiffItem> items,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.paddingS),
            Text(
              '$title (${items.length})',
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeM,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingS),
        ...items.map((item) => _buildDiffItem(item, color)),
      ],
    );
  }

  Widget _buildDiffItem(JsonDiffItem item, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.path,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          if (item.diffType == JsonDiffType.modified) ...[
            const SizedBox(height: AppDimensions.paddingXS),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Before:',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _formatValue(item.firstValue),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: AppDimensions.iconSizeS,
                  color: AppColors.textMuted,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'After:',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _formatValue(item.secondValue),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppDimensions.paddingXS),
            Text(
              _formatValue(
                item.diffType == JsonDiffType.added
                    ? item.secondValue
                    : item.firstValue,
              ),
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value is String) return '"$value"';
    if (value is Map || value is List) return '${value.runtimeType}';
    return value.toString();
  }
}
