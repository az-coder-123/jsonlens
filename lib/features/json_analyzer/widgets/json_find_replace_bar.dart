import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// An inline find-and-replace bar placed inside the JSON input area.
///
/// **Find features**
/// - Iterates through all matches as the user types
/// - Displays a "N / M" match counter
/// - Previous / Next navigation — selects (highlights) each match in the editor
/// - Case-sensitive toggle
/// - Regular-expression toggle
///
/// **Replace features**
/// - Toggle the replace row via the leading chevron
/// - Replace Current — replaces the selected match and advances
/// - Replace All — replaces every match in one shot
///
/// When any replacement is made, [onTextReplaced] is called with the new text
/// so the caller can propagate the change to the state provider.
class JsonFindReplaceBar extends StatefulWidget {
  const JsonFindReplaceBar({
    super.key,
    required this.controller,
    required this.onTextReplaced,
    required this.onClose,
    this.onMatchLine,
  });

  /// The [TextEditingController] of the JSON editor.
  final TextEditingController controller;

  /// Called after a replacement so the parent can update the provider.
  final void Function(String newText) onTextReplaced;

  final VoidCallback onClose;

  /// Called with the 1-based line number of the current match whenever
  /// navigation moves to a new match. Called with null when there are no matches.
  final void Function(int? lineNumber)? onMatchLine;

  @override
  State<JsonFindReplaceBar> createState() => _JsonFindReplaceBarState();
}

class _JsonFindReplaceBarState extends State<JsonFindReplaceBar> {
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _findFocus = FocusNode();

  bool _showReplace = false;
  bool _caseSensitive = false;
  bool _useRegex = false;

  /// Start offset of every match in the current text.
  List<int> _matchStarts = [];

  /// Length (char count) of every match.
  List<int> _matchLengths = [];

  int _currentIndex = -1;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _findController.addListener(_updateMatches);
  }

  @override
  void dispose() {
    _findController
      ..removeListener(_updateMatches)
      ..dispose();
    _replaceController.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Match computation
  // ---------------------------------------------------------------------------

  void _updateMatches() {
    final query = _findController.text;
    final text = widget.controller.text;

    if (query.isEmpty) {
      setState(() {
        _matchStarts = [];
        _matchLengths = [];
        _currentIndex = -1;
      });
      widget.onMatchLine?.call(null);
      return;
    }

    final starts = <int>[];
    final lengths = <int>[];

    if (_useRegex) {
      _collectRegexMatches(text, query, starts, lengths);
    } else {
      _collectLiteralMatches(text, query, starts, lengths);
    }

    final first = starts.isNotEmpty ? 0 : -1;
    setState(() {
      _matchStarts = starts;
      _matchLengths = lengths;
      _currentIndex = first;
    });
    if (first >= 0) {
      _selectMatch(first);
    } else {
      widget.onMatchLine?.call(null);
    }
  }

  void _collectRegexMatches(
    String text,
    String query,
    List<int> starts,
    List<int> lengths,
  ) {
    try {
      final re = RegExp(query, caseSensitive: _caseSensitive);
      for (final m in re.allMatches(text)) {
        starts.add(m.start);
        lengths.add(m.end - m.start);
      }
    } catch (_) {
      // Invalid regex — no matches shown
    }
  }

  void _collectLiteralMatches(
    String text,
    String query,
    List<int> starts,
    List<int> lengths,
  ) {
    final haystack = _caseSensitive ? text : text.toLowerCase();
    final needle = _caseSensitive ? query : query.toLowerCase();
    var pos = 0;
    while (pos < haystack.length) {
      final i = haystack.indexOf(needle, pos);
      if (i == -1) break;
      starts.add(i);
      lengths.add(needle.length);
      pos = i + needle.length;
    }
  }

  void _selectMatch(int index) {
    if (index < 0 || index >= _matchStarts.length) return;
    final offset = _matchStarts[index];
    widget.controller.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + _matchLengths[index],
    );
    widget.onMatchLine?.call(_lineOfOffset(offset));
  }

  /// Returns the 1-based line number for a character [offset] in the text.
  int _lineOfOffset(int offset) {
    final text = widget.controller.text;
    final safeOffset = offset.clamp(0, text.length);
    return '\n'.allMatches(text.substring(0, safeOffset)).length + 1;
  }

  void _goNext() {
    if (_matchStarts.isEmpty) return;
    final next = (_currentIndex + 1) % _matchStarts.length;
    setState(() => _currentIndex = next);
    _selectMatch(next);
  }

  void _goPrev() {
    if (_matchStarts.isEmpty) return;
    final prev =
        (_currentIndex - 1 + _matchStarts.length) % _matchStarts.length;
    setState(() => _currentIndex = prev);
    _selectMatch(prev);
  }

  // ---------------------------------------------------------------------------
  // Replace
  // ---------------------------------------------------------------------------

  void _replaceCurrent() {
    if (_currentIndex < 0 || _matchStarts.isEmpty) return;
    final offset = _matchStarts[_currentIndex];
    final matchLen = _matchLengths[_currentIndex];
    final replacement = _replaceController.text;
    final text = widget.controller.text;

    final newText =
        text.substring(0, offset) +
        replacement +
        text.substring(offset + matchLen);
    _applyNewText(newText, offset + replacement.length);
  }

  void _replaceAll() {
    final query = _findController.text;
    if (query.isEmpty || _matchStarts.isEmpty) return;

    final count = _matchStarts.length;
    final newText = _buildReplaceAll(
      widget.controller.text,
      query,
      _replaceController.text,
    );
    _applyNewText(newText, null);
    _showSnackbar('Replaced $count occurrence${count == 1 ? '' : 's'}');
  }

  String _buildReplaceAll(String text, String query, String replacement) {
    if (_useRegex) {
      try {
        return text.replaceAll(
          RegExp(query, caseSensitive: _caseSensitive),
          replacement,
        );
      } catch (_) {
        return text;
      }
    }
    return text.replaceAll(
      RegExp(RegExp.escape(query), caseSensitive: _caseSensitive),
      replacement,
    );
  }

  void _applyNewText(String newText, int? cursorOffset) {
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: cursorOffset != null
          ? TextSelection.collapsed(offset: cursorOffset)
          : const TextSelection.collapsed(offset: 0),
    );
    widget.onTextReplaced(newText);
    _updateMatches();
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppDimensions.paddingM),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: 4,
      ),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_buildFindRow(), if (_showReplace) _buildReplaceRow()],
      ),
    );
  }

  Widget _buildFindRow() {
    final hasQuery = _findController.text.isNotEmpty;
    return Row(
      children: [
        _iconBtn(
          icon: _showReplace ? Icons.expand_more : Icons.chevron_right,
          tooltip: _showReplace ? 'Hide replace' : 'Show replace',
          onPressed: () => setState(() => _showReplace = !_showReplace),
        ),
        const Icon(Icons.search, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(child: _buildInput(_findController, 'Find', autofocus: true)),
        if (hasQuery) _buildMatchCounter(),
        _iconBtn(
          icon: Icons.arrow_upward,
          tooltip: 'Previous match',
          onPressed: _matchStarts.isNotEmpty ? _goPrev : null,
        ),
        _iconBtn(
          icon: Icons.arrow_downward,
          tooltip: 'Next match',
          onPressed: _matchStarts.isNotEmpty ? _goNext : null,
        ),
        _toggleBtn(
          label: 'Aa',
          tooltip: 'Case sensitive',
          active: _caseSensitive,
          onPressed: () => setState(() {
            _caseSensitive = !_caseSensitive;
            _updateMatches();
          }),
        ),
        _toggleBtn(
          label: '.*',
          tooltip: 'Regular expression',
          active: _useRegex,
          onPressed: () => setState(() {
            _useRegex = !_useRegex;
            _updateMatches();
          }),
        ),
        _iconBtn(
          icon: Icons.close,
          tooltip: 'Close',
          onPressed: widget.onClose,
        ),
      ],
    );
  }

  Widget _buildMatchCounter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        _matchStarts.isEmpty
            ? 'No results'
            : '${_currentIndex + 1} / ${_matchStarts.length}',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: _matchStarts.isEmpty
              ? AppColors.error
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildReplaceRow() {
    return Row(
      children: [
        const SizedBox(width: 24), // align with find input
        const Icon(
          Icons.find_replace,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(child: _buildInput(_replaceController, 'Replace')),
        _textBtn(
          label: 'Replace',
          onPressed: _currentIndex >= 0 ? _replaceCurrent : null,
        ),
        const SizedBox(width: 4),
        _textBtn(
          label: 'Replace All',
          onPressed: _matchStarts.isNotEmpty ? _replaceAll : null,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helper widgets
  // ---------------------------------------------------------------------------

  Widget _buildInput(
    TextEditingController controller,
    String hint, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      focusNode: autofocus ? _findFocus : null,
      onSubmitted: (_) => _goNext(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: AppDimensions.fontSizeS,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeS,
          color: AppColors.textMuted,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 14),
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppColors.textSecondary,
      disabledColor: AppColors.textMuted,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    );
  }

  Widget _toggleBtn({
    required String label,
    required String tooltip,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: active ? AppColors.primary : AppColors.textSecondary,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textBtn({required String label, required VoidCallback? onPressed}) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.primary,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
