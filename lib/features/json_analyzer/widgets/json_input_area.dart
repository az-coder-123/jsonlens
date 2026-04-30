import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/performance_constants.dart';
import '../../../core/utils/json_position_mapper.dart';
import '../providers/json_analyzer_provider.dart';
import 'json_find_replace_bar.dart';

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
  late final ScrollController _lineNumberScrollController;
  late final FocusNode _focusNode;
  late final UndoHistoryController _undoController;
  Timer? _debounceTimer;
  Timer? _cursorDebounceTimer;
  bool _showFindReplace = false;
  int _lineCount = 1;
  int? _matchLine; // 1-based line of current find match
  Set<int> _matchLines = {}; // 1-based lines of all find matches

  // Position mapper for editor ↔ tree sync (ROADMAP 2.5).
  JsonPositionMapper? _positionMapper;
  String _lastMappedText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
    _lineNumberScrollController = ScrollController();
    _focusNode = FocusNode();
    _undoController = UndoHistoryController();
    _controller.addListener(_onControllerChanged);
    _scrollController.addListener(_syncLineNumbers);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_syncLineNumbers);
    _controller.dispose();
    _scrollController.dispose();
    _lineNumberScrollController.dispose();
    _focusNode.dispose();
    _undoController.dispose();
    _debounceTimer?.cancel();
    _cursorDebounceTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    final count = '\n'.allMatches(_controller.text).length + 1;
    if (count != _lineCount) {
      setState(() => _lineCount = count);
    }
    // Debounced cursor-to-path sync for editor → tree direction.
    _cursorDebounceTimer?.cancel();
    _cursorDebounceTimer = Timer(const Duration(milliseconds: 250), _syncCursorToTree);
  }

  /// Maps the current cursor offset to a 0-based line number and writes it
  /// to [editorCursorLineProvider] so the tree view can highlight the node.
  void _syncCursorToTree() {
    if (!mounted) return;
    final sel = _controller.selection;
    if (!sel.isValid || sel.baseOffset < 0) return;
    final text = _controller.text;
    final offset = sel.baseOffset.clamp(0, text.length);
    final line = '\n'.allMatches(text.substring(0, offset)).length;
    ref.read(editorCursorLineProvider.notifier).state = line;
  }

  /// Returns a cached [JsonPositionMapper] for the current editor text.
  JsonPositionMapper? _getMapper() {
    final text = _controller.text;
    if (text == _lastMappedText) return _positionMapper;
    _lastMappedText = text;
    if (!text.contains('\n') || text.isEmpty) {
      return _positionMapper = null;
    }
    return _positionMapper = JsonPositionMapper.build(text);
  }

  /// Scrolls the editor to [line] (0-based) using an animated scroll.
  ///
  /// JetBrains Mono 14px with height 1.5 → line height ≈ 21 px.
  static const double _estimatedLineHeight = 21.0;

  void _scrollEditorToLine(int line) {
    if (!_scrollController.hasClients) return;
    final target = (line * _estimatedLineHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Keeps the line-number gutter in sync with the editor's vertical scroll.
  void _syncLineNumbers() {
    if (!_lineNumberScrollController.hasClients) return;
    final offset = _scrollController.offset.clamp(
      0.0,
      _lineNumberScrollController.position.maxScrollExtent,
    );
    if (_lineNumberScrollController.offset != offset) {
      _lineNumberScrollController.jumpTo(offset);
    }
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

    // Tree → Editor: scroll editor when user taps a tree node.
    ref.listen<String>(treeSelectedPathProvider, (prev, next) {
      if (next.isEmpty || next == prev) return;
      final line = _getMapper()?.lineForPath(next);
      if (line != null) _scrollEditorToLine(line);
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
          if (_showFindReplace && !isReadOnlyMode)
            JsonFindReplaceBar(
              controller: _controller,
              onTextReplaced: _applyReplacedText,
              onClose: () => setState(() {
                _showFindReplace = false;
                _matchLine = null;
                _matchLines = {};
              }),
              onMatchLine: (line) => setState(() => _matchLine = line),
              onMatchLinesChanged: (lines) =>
                  setState(() => _matchLines = lines),
            ),
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
          // Undo / Redo buttons
          if (!isReadOnlyMode) _buildUndoRedoButtons(),
          // Find & Replace toggle
          if (!isReadOnlyMode)
            IconButton(
              tooltip: 'Find & Replace',
              icon: Icon(
                Icons.find_replace,
                size: AppDimensions.iconSizeS,
                color: _showFindReplace
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _showFindReplace = !_showFindReplace),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLineNumberGutter(),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            Expanded(
              child: SingleChildScrollView(
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
            ),
          ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLineNumberGutter(),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
        Expanded(
          child: TextField(
            controller: _controller,
            scrollController: _scrollController,
            focusNode: _focusNode,
            undoController: _undoController,
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
          ),
        ),
      ],
    );
  }

  /// Gutter widget showing 1-based line numbers — virtualized via ListView.builder
  /// so only visible rows are built, keeping performance good for large files.
  Widget _buildLineNumberGutter() {
    const lineHeight = AppDimensions.fontSizeM * 1.5;
    const topPadding = AppDimensions.paddingM;

    return Container(
      width: AppDimensions.lineNumberWidth,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: topPadding),
        child: ListView.builder(
          controller: _lineNumberScrollController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _lineCount,
          itemExtent: lineHeight,
          itemBuilder: (context, i) {
            final lineNum = i + 1;
            final isCurrent = lineNum == _matchLine;
            final isMatch = !isCurrent && _matchLines.contains(lineNum);

            final bgColor = isCurrent
                ? AppColors.primary.withValues(alpha: 0.28)
                : isMatch
                ? AppColors.primary.withValues(alpha: 0.10)
                : null;

            final textColor = isCurrent
                ? AppColors.primary
                : isMatch
                ? AppColors.primary.withValues(alpha: 0.65)
                : AppColors.textMuted;

            return Container(
              height: lineHeight,
              decoration: bgColor != null
                  ? BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusS,
                      ),
                    )
                  : null,
              padding: const EdgeInsets.only(right: AppDimensions.paddingS),
              alignment: Alignment.centerRight,
              child: Text(
                '$lineNum',
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeM,
                  color: textColor,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  height: 1.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Undo / Redo icon buttons driven by [UndoHistoryController].
  Widget _buildUndoRedoButtons() {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: _undoController,
      builder: (context, value, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo, size: AppDimensions.iconSizeS),
            color: AppColors.textSecondary,
            disabledColor: AppColors.textMuted,
            onPressed: value.canUndo ? _undoController.undo : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo, size: AppDimensions.iconSizeS),
            color: AppColors.textSecondary,
            disabledColor: AppColors.textMuted,
            onPressed: value.canRedo ? _undoController.redo : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  /// Immediately pushes [newText] to the provider (no debounce).
  ///
  /// Used by Find & Replace for deliberate one-shot replacements.
  void _applyReplacedText(String newText) {
    _debounceTimer?.cancel();
    ref.read(jsonAnalyzerProvider.notifier).updateInput(newText);
  }
}
