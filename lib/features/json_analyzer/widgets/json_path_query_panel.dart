import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/json_formatter.dart';
import '../providers/json_analyzer_provider.dart';

/// Widget for querying JSON using path notation.
class JsonPathQueryPanel extends ConsumerStatefulWidget {
  const JsonPathQueryPanel({super.key});

  @override
  ConsumerState<JsonPathQueryPanel> createState() => _JsonPathQueryPanelState();
}

class _JsonPathQueryPanelState extends ConsumerState<JsonPathQueryPanel> {
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pathQueryState = ref.watch(pathQueryProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQueryInput(pathQueryState, isValid && !isEmpty),
        Expanded(child: _buildResult(pathQueryState)),
      ],
    );
  }

  Widget _buildQueryInput(PathQueryState state, bool enabled) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JSON Path Query',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  enabled: enabled,
                  onChanged: (value) {
                    ref.read(pathQueryProvider.notifier).setPath(value);
                  },
                  onSubmitted: (_) {
                    ref.read(pathQueryProvider.notifier).query();
                  },
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: AppDimensions.fontSizeM,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., users[0].name or data.items',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: AppDimensions.fontSizeM,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.route,
                      color: AppColors.textSecondary,
                      size: AppDimensions.iconSizeM,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingS),
              ElevatedButton(
                onPressed: enabled
                    ? () => ref.read(pathQueryProvider.notifier).query()
                    : null,
                child: const Text('Query'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            'Supports: dot notation (obj.key), array indices ([0]), nested paths',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(PathQueryState state) {
    if (state.errorMessage != null) {
      return _buildError(state.errorMessage!);
    }

    if (state.result == null && state.path.isEmpty) {
      return _buildPlaceholder();
    }

    if (state.result == null) {
      return _buildNoResult();
    }

    return _buildResultContent(state.result);
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.route, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'Enter a path to query JSON',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.warning),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'Path not found',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.warning,
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

  Widget _buildResultContent(dynamic result) {
    String displayText;
    if (result is Map || result is List) {
      displayText = JsonFormatter.formatObject(result);
    } else {
      displayText = result.toString();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Result Type: ',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingS,
                  vertical: AppDimensions.paddingXS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: Text(
                  _getTypeName(result),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: AppDimensions.fontSizeS,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              displayText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeM,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeName(dynamic value) {
    if (value is Map) return 'Object';
    if (value is List) return 'Array';
    if (value is String) return 'String';
    if (value is num) return 'Number';
    if (value is bool) return 'Boolean';
    if (value == null) return 'Null';
    return 'Unknown';
  }
}
