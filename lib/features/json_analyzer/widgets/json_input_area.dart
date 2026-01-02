import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/performance_constants.dart';
import '../providers/json_analyzer_provider.dart';

/// Input area widget for entering JSON text.
///
/// Provides a text field with line numbers and monospace font.
/// For very large files (>5MB), switches to read-only mode to prevent UI lag.
class JsonInputArea extends ConsumerStatefulWidget {
  const JsonInputArea({super.key});

  @override
  ConsumerState<JsonInputArea> createState() => _JsonInputAreaState();
}

class _JsonInputAreaState extends ConsumerState<JsonInputArea> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();

    // Use longer debounce for large inputs
    final debounceMs =
        value.length > PerformanceConstants.processingIndicatorThreshold
        ? PerformanceConstants.largeInputDebounceMs
        : PerformanceConstants.inputDebounceMs;

    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
      // fire-and-forget — provider handles async work and cancellation
      ref.read(jsonAnalyzerProvider.notifier).updateInput(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnlyMode = ref.watch(isReadOnlyModeProvider);
    final inputSize = ref.watch(inputSizeProvider);

    // Listen to state changes to sync controller
    ref.listen<String>(jsonAnalyzerProvider.select((s) => s.input), (
      previous,
      next,
    ) {
      if (_controller.text != next) {
        final selection = _controller.selection;
        _controller.text = next;
        // Restore cursor position if possible
        if (selection.isValid && selection.end <= next.length) {
          _controller.selection = selection;
        }
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isReadOnlyMode: isReadOnlyMode, inputSize: inputSize),
          const Divider(height: 1),
          Expanded(
            child: isReadOnlyMode ? _buildReadOnlyView() : _buildTextField(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool isReadOnlyMode, required int inputSize}) {
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
          Icon(
            isReadOnlyMode ? Icons.lock_outline : Icons.input,
            size: AppDimensions.iconSizeS,
            color: isReadOnlyMode ? AppColors.warning : AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            'Input',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Show read-only badge for large files
          if (isReadOnlyMode) _buildReadOnlyBadge(),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            'Read Only',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Read-only view for very large files.
  /// Uses SelectableText instead of TextField to avoid editing overhead.
  Widget _buildReadOnlyView() {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: SelectableText(
            _controller.text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeM,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
        // Info banner at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildLargeFileInfoBanner(),
        ),
      ],
    );
  }

  Widget _buildLargeFileInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: AppDimensions.iconSizeS,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              'Large file detected. Editing disabled for better performance.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      scrollController: _scrollController,
      focusNode: _focusNode,
      onChanged: _onTextChanged,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: GoogleFonts.jetBrainsMono(
        fontSize: AppDimensions.fontSizeM,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: AppStrings.inputHint,
        hintStyle: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textMuted,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
      ),
      cursorColor: AppColors.primary,
    );
  }
}
