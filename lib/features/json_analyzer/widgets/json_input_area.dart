import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/performance_constants.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/file_helper.dart';
import '../../../core/utils/json_position_mapper.dart';
import '../providers/json_analyzer_provider.dart';
import 'http_request_dialog.dart';
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
    _cursorDebounceTimer = Timer(
      const Duration(milliseconds: 250),
      _syncCursorToTree,
    );
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

  /// Scrolls the editor to [line] (0-based) only when it is outside the
  /// visible viewport. If already visible, no scroll is performed.
  ///
  /// JetBrains Mono 14px with height 1.5 → line height ≈ 21 px.
  void _scrollEditorToLine(int line) {
    if (!_scrollController.hasClients) return;
    final lineTop = line * AppDimensions.estimatedLineHeight;
    final lineBottom = lineTop + AppDimensions.estimatedLineHeight;
    final viewTop = _scrollController.offset;
    final viewBottom = viewTop + _scrollController.position.viewportDimension;
    if (lineTop >= viewTop && lineBottom <= viewBottom) {
      return; // already visible
    }
    final target = (lineTop - _scrollController.position.viewportDimension / 3)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
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
              onMatchLine: (line) {
                setState(() => _matchLine = line);
                if (line != null) _scrollEditorToLine(line - 1);
              },
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
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final canAct = isValid && !isEmpty;
    final canCopySave = isValid && ref.watch(outputProvider).isNotEmpty;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              !isReadOnlyMode &&
              constraints.maxWidth < AppDimensions.inputCompactThreshold;
          return Row(
            children: [
              Icon(
                isReadOnlyMode ? Icons.lock_outline : Icons.input,
                size: AppDimensions.iconSizeS,
                color: isReadOnlyMode
                    ? AppColors.warning
                    : AppColors.textSecondary,
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
              if (compact)
                _buildActionsCompact(
                  canAct: canAct,
                  canCopySave: canCopySave,
                  isEmpty: isEmpty,
                )
              else if (!isReadOnlyMode)
                _buildActionsWide(
                  canAct: canAct,
                  canCopySave: canCopySave,
                  isEmpty: isEmpty,
                ),
              if (isReadOnlyMode) _buildReadOnlyBadge(),
            ],
          );
        },
      ),
    );
  }

  /// Full grouped icon-button row shown when width >= [AppDimensions.inputCompactThreshold].
  Widget _buildActionsWide({
    required bool canAct,
    required bool canCopySave,
    required bool isEmpty,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Group 1: File ────────────────────────────────────────────────
        _iconBtn(
          tooltip: 'HTTP Request',
          icon: Icons.http,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const HttpRequestDialog(),
          ),
        ),
        _iconBtn(
          tooltip: AppStrings.open,
          icon: Icons.folder_open,
          onPressed: () async {
            final outcome = await FileHelper.openTextFile();
            switch (outcome.status) {
              case OpenStatus.opened:
                if (outcome.contents != null) {
                  await ref
                      .read(jsonAnalyzerProvider.notifier)
                      .updateInput(outcome.contents!);
                  _snack(
                    outcome.path != null
                        ? '${AppStrings.loadedFromFile}: ${outcome.path}'
                        : AppStrings.loadedFromFile,
                  );
                }
              case OpenStatus.cancelled:
                _snack(AppStrings.loadCancelled);
              case OpenStatus.failed:
                _snack(AppStrings.loadFailed);
            }
          },
        ),
        _iconBtn(
          tooltip: AppStrings.save,
          icon: Icons.save,
          enabled: canCopySave,
          onPressed: !canCopySave
              ? null
              : () async {
                  final outcome = await FileHelper.saveTextFile(
                    suggestedName: 'data.json',
                    contents: ref.read(outputProvider),
                  );
                  switch (outcome.status) {
                    case SaveStatus.saved:
                      _snack(
                        outcome.path != null
                            ? '${AppStrings.savedToFile}: ${outcome.path}'
                            : AppStrings.savedToFile,
                      );
                    case SaveStatus.cancelled:
                      _snack(AppStrings.saveCancelled);
                    case SaveStatus.failed:
                      _snack(AppStrings.saveFailed);
                  }
                },
        ),
        _divider(),
        // ── Group 2: Clipboard ───────────────────────────────────────────
        _iconBtn(
          tooltip: AppStrings.copy,
          icon: Icons.content_copy,
          enabled: canCopySave,
          onPressed: !canCopySave
              ? null
              : () async {
                  final ok = await ClipboardHelper.copy(
                    ref.read(outputProvider),
                  );
                  if (ok) _snack(AppStrings.copiedToClipboard);
                },
        ),
        FutureBuilder<bool>(
          future: ClipboardHelper.hasText(),
          builder: (context, snapshot) {
            final hasText = snapshot.data ?? false;
            return _iconBtn(
              tooltip: AppStrings.paste,
              icon: Icons.content_paste,
              enabled: hasText,
              onPressed: !hasText
                  ? null
                  : () async {
                      final text = await ClipboardHelper.paste();
                      if (text != null && text.isNotEmpty) {
                        ref
                            .read(jsonAnalyzerProvider.notifier)
                            .pasteFromClipboard(text);
                        _snack(AppStrings.pastedFromClipboard);
                      } else {
                        _snack(AppStrings.clipboardEmpty);
                      }
                    },
            );
          },
        ),
        _iconBtn(
          tooltip: AppStrings.clear,
          icon: Icons.clear_all,
          enabled: !isEmpty,
          onPressed: isEmpty
              ? null
              : () {
                  ref.read(jsonAnalyzerProvider.notifier).clear();
                  _snack(AppStrings.cleared);
                },
        ),
        _divider(),
        // ── Group 3: Transform ───────────────────────────────────────────
        _iconBtn(
          tooltip: AppStrings.format,
          icon: Icons.format_align_left,
          enabled: canAct,
          onPressed: !canAct
              ? null
              : () async {
                  await ref.read(jsonAnalyzerProvider.notifier).format();
                  _snack(AppStrings.formatted);
                },
        ),
        _iconBtn(
          tooltip: AppStrings.minify,
          icon: Icons.compress,
          enabled: canAct,
          onPressed: !canAct
              ? null
              : () async {
                  await ref.read(jsonAnalyzerProvider.notifier).minify();
                  _snack(AppStrings.minified);
                },
        ),
        _popupIconBtn(
          tooltip: 'Transform',
          icon: Icons.transform,
          enabled: canAct,
          items: [
            _menuItem(
              Icons.sort_by_alpha,
              'Sort Keys (A→Z)',
              () => ref
                  .read(jsonAnalyzerProvider.notifier)
                  .sortKeys(ascending: true),
            ),
            _menuItem(
              Icons.sort_by_alpha,
              'Sort Keys (Z→A)',
              () => ref
                  .read(jsonAnalyzerProvider.notifier)
                  .sortKeys(ascending: false),
            ),
            _menuItem(
              Icons.compress,
              'Flatten',
              () => ref.read(jsonAnalyzerProvider.notifier).flatten(),
            ),
          ],
        ),
        _popupIconBtn(
          tooltip: 'Clean',
          icon: Icons.cleaning_services,
          enabled: canAct,
          items: [
            _menuItem(
              Icons.delete_outline,
              'Remove Nulls',
              () => ref.read(jsonAnalyzerProvider.notifier).removeNulls(),
            ),
            _menuItem(
              Icons.delete_sweep,
              'Remove Empty',
              () => ref.read(jsonAnalyzerProvider.notifier).removeEmpty(),
            ),
          ],
        ),
        _divider(),
        // ── Group 4: Edit ────────────────────────────────────────────────
        _iconBtn(
          tooltip: 'Find & Replace',
          icon: Icons.find_replace,
          active: _showFindReplace,
          onPressed: () => setState(() => _showFindReplace = !_showFindReplace),
        ),
        ValueListenableBuilder<UndoHistoryValue>(
          valueListenable: _undoController,
          builder: (context, undoVal, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(
                tooltip: 'Undo',
                icon: Icons.undo,
                enabled: undoVal.canUndo,
                onPressed: undoVal.canUndo ? _undoController.undo : null,
              ),
              _iconBtn(
                tooltip: 'Redo',
                icon: Icons.redo,
                enabled: undoVal.canRedo,
                onPressed: undoVal.canRedo ? _undoController.redo : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Collapsed single `⋯` menu shown when width < [AppDimensions.inputCompactThreshold].
  Widget _buildActionsCompact({
    required bool canAct,
    required bool canCopySave,
    required bool isEmpty,
  }) {
    final undoVal = _undoController.value;
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Actions',
      offset: const Offset(0, 32),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (fn) => fn(),
      icon: const Icon(
        Icons.more_horiz,
        size: AppDimensions.iconSizeS,
        color: AppColors.textSecondary,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      itemBuilder: (_) => [
        // ── File ──────────────────────────────────────────────────────────
        _menuSection('FILE'),
        _menuAction(
          Icons.http,
          'HTTP Request',
          true,
          () => showDialog<void>(
            context: context,
            builder: (_) => const HttpRequestDialog(),
          ),
        ),
        _menuAction(Icons.folder_open, AppStrings.open, true, () async {
          final outcome = await FileHelper.openTextFile();
          switch (outcome.status) {
            case OpenStatus.opened:
              if (outcome.contents != null) {
                await ref
                    .read(jsonAnalyzerProvider.notifier)
                    .updateInput(outcome.contents!);
                _snack(
                  outcome.path != null
                      ? '${AppStrings.loadedFromFile}: ${outcome.path}'
                      : AppStrings.loadedFromFile,
                );
              }
            case OpenStatus.cancelled:
              _snack(AppStrings.loadCancelled);
            case OpenStatus.failed:
              _snack(AppStrings.loadFailed);
          }
        }),
        _menuAction(
          Icons.save,
          AppStrings.save,
          canCopySave,
          !canCopySave
              ? null
              : () async {
                  final outcome = await FileHelper.saveTextFile(
                    suggestedName: 'data.json',
                    contents: ref.read(outputProvider),
                  );
                  switch (outcome.status) {
                    case SaveStatus.saved:
                      _snack(
                        outcome.path != null
                            ? '${AppStrings.savedToFile}: ${outcome.path}'
                            : AppStrings.savedToFile,
                      );
                    case SaveStatus.cancelled:
                      _snack(AppStrings.saveCancelled);
                    case SaveStatus.failed:
                      _snack(AppStrings.saveFailed);
                  }
                },
        ),
        // ── Clipboard ─────────────────────────────────────────────────────
        const PopupMenuDivider(),
        _menuSection('CLIPBOARD'),
        _menuAction(
          Icons.content_copy,
          AppStrings.copy,
          canCopySave,
          !canCopySave
              ? null
              : () async {
                  final ok = await ClipboardHelper.copy(
                    ref.read(outputProvider),
                  );
                  if (ok) _snack(AppStrings.copiedToClipboard);
                },
        ),
        _menuAction(Icons.content_paste, AppStrings.paste, true, () async {
          final text = await ClipboardHelper.paste();
          if (text != null && text.isNotEmpty) {
            ref.read(jsonAnalyzerProvider.notifier).pasteFromClipboard(text);
            _snack(AppStrings.pastedFromClipboard);
          } else {
            _snack(AppStrings.clipboardEmpty);
          }
        }),
        _menuAction(
          Icons.clear_all,
          AppStrings.clear,
          !isEmpty,
          isEmpty
              ? null
              : () {
                  ref.read(jsonAnalyzerProvider.notifier).clear();
                  _snack(AppStrings.cleared);
                },
        ),
        // ── Transform ─────────────────────────────────────────────────────
        const PopupMenuDivider(),
        _menuSection('TRANSFORM'),
        _menuAction(
          Icons.format_align_left,
          AppStrings.format,
          canAct,
          !canAct
              ? null
              : () async {
                  await ref.read(jsonAnalyzerProvider.notifier).format();
                  _snack(AppStrings.formatted);
                },
        ),
        _menuAction(
          Icons.compress,
          AppStrings.minify,
          canAct,
          !canAct
              ? null
              : () async {
                  await ref.read(jsonAnalyzerProvider.notifier).minify();
                  _snack(AppStrings.minified);
                },
        ),
        _menuAction(
          Icons.sort_by_alpha,
          'Sort Keys (A→Z)',
          canAct,
          !canAct
              ? null
              : () => ref
                    .read(jsonAnalyzerProvider.notifier)
                    .sortKeys(ascending: true),
        ),
        _menuAction(
          Icons.sort_by_alpha,
          'Sort Keys (Z→A)',
          canAct,
          !canAct
              ? null
              : () => ref
                    .read(jsonAnalyzerProvider.notifier)
                    .sortKeys(ascending: false),
        ),
        _menuAction(
          Icons.compress,
          'Flatten',
          canAct,
          !canAct
              ? null
              : () => ref.read(jsonAnalyzerProvider.notifier).flatten(),
        ),
        _menuAction(
          Icons.delete_outline,
          'Remove Nulls',
          canAct,
          !canAct
              ? null
              : () => ref.read(jsonAnalyzerProvider.notifier).removeNulls(),
        ),
        _menuAction(
          Icons.delete_sweep,
          'Remove Empty',
          canAct,
          !canAct
              ? null
              : () => ref.read(jsonAnalyzerProvider.notifier).removeEmpty(),
        ),
        // ── Edit ──────────────────────────────────────────────────────────
        const PopupMenuDivider(),
        _menuSection('EDIT'),
        _menuAction(
          Icons.find_replace,
          'Find & Replace',
          true,
          () => setState(() => _showFindReplace = !_showFindReplace),
        ),
        _menuAction(
          Icons.undo,
          'Undo',
          undoVal.canUndo,
          !undoVal.canUndo ? null : _undoController.undo,
        ),
        _menuAction(
          Icons.redo,
          'Redo',
          undoVal.canRedo,
          !undoVal.canRedo ? null : _undoController.redo,
        ),
      ],
    );
  }

  /// Section header item for the compact dropdown.
  PopupMenuItem<VoidCallback> _menuSection(String label) {
    return PopupMenuItem<VoidCallback>(
      enabled: false,
      height: 28,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Action item for the compact dropdown.
  PopupMenuItem<VoidCallback> _menuAction(
    IconData icon,
    String label,
    bool enabled,
    VoidCallback? onTap,
  ) {
    return PopupMenuItem<VoidCallback>(
      value: onTap,
      enabled: enabled && onTap != null,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeS,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            label,
            style: TextStyle(
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// A thin vertical divider for separating button groups.
  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: SizedBox(
      height: 16,
      child: VerticalDivider(color: AppColors.border, thickness: 1),
    ),
  );

  /// A compact icon-only button used throughout the header.
  Widget _iconBtn({
    required String tooltip,
    required IconData icon,
    VoidCallback? onPressed,
    bool enabled = true,
    bool active = false,
  }) {
    final color = active
        ? AppColors.primary
        : (enabled ? AppColors.textSecondary : AppColors.textMuted);
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: AppDimensions.iconSizeS, color: color),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  /// A compact icon-only popup-menu button used for Transform / Clean.
  Widget _popupIconBtn({
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required List<PopupMenuItem<VoidCallback>> items,
  }) {
    return PopupMenuButton<VoidCallback>(
      enabled: enabled,
      tooltip: tooltip,
      offset: const Offset(0, 28),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (fn) => fn(),
      itemBuilder: (_) => items,
      icon: Icon(
        icon,
        size: AppDimensions.iconSizeS,
        color: enabled ? AppColors.textSecondary : AppColors.textMuted,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  PopupMenuItem<VoidCallback> _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return PopupMenuItem<VoidCallback>(
      value: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeS,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(label, style: const TextStyle(color: AppColors.textPrimary)),
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

  void _snack(String msg) {
    if (!mounted) return;

    // Auto-detect intent from message content
    final lower = msg.toLowerCase();
    final isError =
        lower.contains('fail') ||
        lower.contains('error') ||
        lower.contains('invalid');
    final isWarning =
        lower.contains('cancel') ||
        lower.contains('empty') ||
        lower.contains('nothing');

    final Color accent;
    final Color bgColor;
    final IconData iconData;
    if (isError) {
      accent = AppColors.error;
      bgColor = const Color(0xFF2D1515); // dark red tint
      iconData = Icons.error_outline;
    } else if (isWarning) {
      accent = AppColors.warning;
      bgColor = const Color(0xFF2D1F10); // dark orange tint
      iconData = Icons.warning_amber_outlined;
    } else {
      accent = AppColors.success;
      bgColor = const Color(0xFF102D25); // dark green tint
      iconData = Icons.check_circle_outline;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppDimensions.paddingM),
          duration: Duration(seconds: isError ? 4 : 2),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, size: 18, color: accent),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    msg,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: AppDimensions.fontSizeS,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
