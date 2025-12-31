import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/json_analyzer_provider.dart';

/// Input area widget for entering JSON text.
///
/// Provides a text field with line numbers and monospace font.
class JsonInputArea extends ConsumerStatefulWidget {
  const JsonInputArea({super.key});

  @override
  ConsumerState<JsonInputArea> createState() => _JsonInputAreaState();
}

class _JsonInputAreaState extends ConsumerState<JsonInputArea> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

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
    super.dispose();
  }

  void _onTextChanged(String value) {
    ref.read(jsonAnalyzerProvider.notifier).updateInput(value);
  }

  @override
  Widget build(BuildContext context) {
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
          _buildHeader(),
          const Divider(height: 1),
          Expanded(child: _buildTextField()),
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
            Icons.input,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
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
