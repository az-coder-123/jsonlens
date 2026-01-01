import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../providers/json_analyzer_provider.dart';

/// Search panel widget for searching within JSON.
class JsonSearchPanel extends ConsumerStatefulWidget {
  const JsonSearchPanel({super.key});

  @override
  ConsumerState<JsonSearchPanel> createState() => _JsonSearchPanelState();
}

class _JsonSearchPanelState extends ConsumerState<JsonSearchPanel> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final isValid = ref.watch(isValidProvider);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchRow(searchState, isValid),
          const SizedBox(height: AppDimensions.paddingS),
          _buildOptionsRow(searchState),
          if (searchState.results.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingS),
            _buildResultsInfo(searchState),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchRow(SearchState searchState, bool isValid) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: (value) {
              ref.read(searchProvider.notifier).setQuery(value);
            },
            enabled: isValid,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search in JSON...',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeM,
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: AppDimensions.iconSizeM,
              ),
              suffixIcon: searchState.query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.textSecondary,
                        size: AppDimensions.iconSizeS,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchProvider.notifier).clearSearch();
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.paddingS),
        _buildNavigationButtons(searchState),
      ],
    );
  }

  Widget _buildNavigationButtons(SearchState searchState) {
    final hasResults = searchState.results.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: hasResults
              ? () => ref.read(searchProvider.notifier).previousResult()
              : null,
          color: hasResults ? AppColors.textPrimary : AppColors.textMuted,
          iconSize: AppDimensions.iconSizeM,
          tooltip: 'Previous result',
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: hasResults
              ? () => ref.read(searchProvider.notifier).nextResult()
              : null,
          color: hasResults ? AppColors.textPrimary : AppColors.textMuted,
          iconSize: AppDimensions.iconSizeM,
          tooltip: 'Next result',
        ),
      ],
    );
  }

  Widget _buildOptionsRow(SearchState searchState) {
    return Wrap(
      spacing: AppDimensions.paddingM,
      runSpacing: AppDimensions.paddingXS,
      children: [
        _buildOptionChip(
          label: 'Keys',
          selected: searchState.options.searchKeys,
          onSelected: (_) =>
              ref.read(searchProvider.notifier).toggleSearchKeys(),
        ),
        _buildOptionChip(
          label: 'Values',
          selected: searchState.options.searchValues,
          onSelected: (_) =>
              ref.read(searchProvider.notifier).toggleSearchValues(),
        ),
        _buildOptionChip(
          label: 'Aa',
          selected: searchState.options.caseSensitive,
          onSelected: (_) =>
              ref.read(searchProvider.notifier).toggleCaseSensitive(),
          tooltip: 'Case sensitive',
        ),
        _buildOptionChip(
          label: '.*',
          selected: searchState.options.useRegex,
          onSelected: (_) => ref.read(searchProvider.notifier).toggleRegex(),
          tooltip: 'Use regex',
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    String? tooltip,
  }) {
    final chip = FilterChip(
      label: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeS,
          color: selected ? AppColors.background : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXS),
      visualDensity: VisualDensity.compact,
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }

  Widget _buildResultsInfo(SearchState searchState) {
    final currentIndex = searchState.currentResultIndex + 1;
    final totalResults = searchState.results.length;

    return Row(
      children: [
        Text(
          '$currentIndex of $totalResults results',
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        if (searchState.currentResultIndex >= 0) ...[
          Text(
            searchState.results[searchState.currentResultIndex].path,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}
