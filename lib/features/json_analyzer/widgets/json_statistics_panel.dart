import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/json_statistics.dart';
import '../providers/json_analyzer_provider.dart';

/// Widget displaying JSON statistics.
class JsonStatisticsPanel extends ConsumerWidget {
  const JsonStatisticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final isValid = ref.watch(isValidProvider);

    if (isEmpty || !isValid) {
      return _buildEmptyState();
    }

    return _buildStatistics(stats);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Enter valid JSON to see statistics',
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildStatistics(JsonStatistics stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Overview'),
          const SizedBox(height: AppDimensions.paddingS),
          _buildStatsGrid([
            _StatItem('Total Keys', stats.totalKeys.toString(), Icons.key),
            _StatItem(
              'Total Values',
              stats.totalValues.toString(),
              Icons.data_array,
            ),
            _StatItem('Max Depth', stats.maxDepth.toString(), Icons.layers),
            _StatItem(
              'Characters',
              _formatNumber(stats.totalCharacters),
              Icons.text_fields,
            ),
          ]),
          const SizedBox(height: AppDimensions.paddingL),
          _buildSectionTitle('Structure'),
          const SizedBox(height: AppDimensions.paddingS),
          _buildStatsGrid([
            _StatItem(
              'Objects',
              stats.objectCount.toString(),
              Icons.data_object,
            ),
            _StatItem('Arrays', stats.arrayCount.toString(), Icons.list),
          ]),
          const SizedBox(height: AppDimensions.paddingL),
          _buildSectionTitle('Value Types'),
          const SizedBox(height: AppDimensions.paddingS),
          _buildTypeBreakdown(stats.typeCounts),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        fontSize: AppDimensions.fontSizeM,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return Wrap(
      spacing: AppDimensions.paddingM,
      runSpacing: AppDimensions.paddingM,
      children: items.map((item) => _buildStatCard(item)).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.icon,
                size: AppDimensions.iconSizeS,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimensions.paddingXS),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: AppDimensions.fontSizeS,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            item.value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBreakdown(Map<String, int> typeCounts) {
    if (typeCounts.isEmpty) {
      return Text(
        'No data',
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textMuted,
        ),
      );
    }

    final total = typeCounts.values.fold(0, (a, b) => a + b);
    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedTypes.map((entry) {
        final percentage = (entry.value / total * 100).toStringAsFixed(1);
        return _buildTypeRow(entry.key, entry.value, percentage);
      }).toList(),
    );
  }

  Widget _buildTypeRow(String type, int count, String percentage) {
    final color = _getTypeColor(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            flex: 2,
            child: Text(
              type,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeM,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: double.parse(percentage) / 100,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          SizedBox(
            width: 80,
            child: Text(
              '$count ($percentage%)',
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'string':
        return AppColors.jsonString;
      case 'number':
        return AppColors.jsonNumber;
      case 'boolean':
        return AppColors.jsonBoolean;
      case 'null':
        return AppColors.jsonNull;
      case 'object':
        return AppColors.primary;
      case 'array':
        return AppColors.secondary;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  _StatItem(this.label, this.value, this.icon);
}
