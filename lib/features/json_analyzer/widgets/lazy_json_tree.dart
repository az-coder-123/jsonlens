import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

// ---------------------------------------------------------------------------
// Node action enum
// ---------------------------------------------------------------------------

/// Actions available in the tree node right-click / long-press context menu.
enum TreeNodeAction { addKey, addItem, delete, duplicate }

// ---------------------------------------------------------------------------
// Search helpers
// ---------------------------------------------------------------------------

/// Returns true if [key] or [value] (recursively) contains [query] (case-insensitive).
bool _matchesSearch(String key, dynamic value, String query) {
  if (query.isEmpty) return false;
  final q = query.toLowerCase();
  if (key.toLowerCase().contains(q)) return true;
  if (value is Map<String, dynamic>) {
    return value.entries.any((e) => _matchesSearch(e.key, e.value, q));
  }
  if (value is List) {
    for (int i = 0; i < value.length; i++) {
      if (_matchesSearch('[$i]', value[i], q)) return true;
    }
    return false;
  }
  return value.toString().toLowerCase().contains(q);
}

/// Builds a widget that highlights [query] within [text] using the given [style].
Widget _buildHighlightedText(String text, String query, TextStyle style) {
  if (query.isEmpty) {
    return Text(
      text,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final index = lowerText.indexOf(lowerQuery);
  if (index == -1) {
    return Text(
      text,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
  return RichText(
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
    text: TextSpan(
      style: style,
      children: [
        if (index > 0) TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: text.substring(index, index + query.length),
          style: style.copyWith(
            backgroundColor: AppColors.searchHighlight,
            color: AppColors.searchHighlightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (index + query.length < text.length)
          TextSpan(text: text.substring(index + query.length)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Copy helper
// ---------------------------------------------------------------------------

/// Serializes [value] to a string suitable for the clipboard.
String _serializeForClipboard(dynamic value) {
  if (value == null) return 'null';
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// A lazy JSON tree widget that only builds children when a node is expanded.
///
/// Supports:
///   - Search highlighting with auto-expand
///   - Per-node copy button
///   - JSON Path reporting via [onPathSelected]
///   - Programmatic expand-all / collapse-all via [forceExpandAll]
///   - Node type icon badges ({}, [], ", #, ✓/✗, ∅)
///   - Array index keys styled distinctly from object keys
///   - Alphabetical key sorting via [sortKeys]
///   - Keyboard navigation (→ expand, ← collapse, Enter/Space toggle or copy)
class LazyJsonTree extends StatelessWidget {
  final dynamic data;
  final int defaultExpandedDepth;
  final String searchQuery;

  /// Increment to trigger all nodes to re-evaluate their expansion state.
  final int expansionGeneration;

  /// `true` = expand all, `false` = collapse all, `null` = use depth setting.
  final bool? forceExpandAll;

  /// When true, object keys are sorted alphabetically before rendering.
  final bool sortKeys;

  /// Called when the user taps a node. Receives the full JSON-Path string.
  final void Function(String path)? onPathSelected;

  /// Called when the user edits a leaf-node value inline.
  /// Receives the full JSON-Path string and the parsed new value.
  final void Function(String path, dynamic newValue)? onValueChanged;

  /// Called when the user selects an action from the node's context menu.
  final void Function(String path, TreeNodeAction action)? onNodeAction;

  const LazyJsonTree({
    super.key,
    required this.data,
    this.defaultExpandedDepth = 0,
    this.searchQuery = '',
    this.expansionGeneration = 0,
    this.forceExpandAll,
    this.sortKeys = false,
    this.onPathSelected,
    this.onValueChanged,
    this.onNodeAction,
  });

  @override
  Widget build(BuildContext context) {
    if (data is List) {
      final list = data as List;
      return ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        itemCount: list.length,
        itemBuilder: (context, index) => _LazyNode(
          keyName: '[$index]',
          value: list[index],
          depth: 0,
          path: '\$[$index]',
          isArrayIndex: true,
          defaultExpandedDepth: defaultExpandedDepth,
          searchQuery: searchQuery,
          expansionGeneration: expansionGeneration,
          forceExpandAll: forceExpandAll,
          sortKeys: sortKeys,
          onPathSelected: onPathSelected,
          onValueChanged: onValueChanged,
          onNodeAction: onNodeAction,
        ),
      );
    }

    final Map<String, dynamic> root = data is Map<String, dynamic>
        ? data as Map<String, dynamic>
        : <String, dynamic>{'root': data};
    var entries = root.entries.toList();
    if (sortKeys) entries.sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return _LazyNode(
          keyName: e.key,
          value: e.value,
          depth: 0,
          path: '\$.${e.key}',
          isArrayIndex: false,
          defaultExpandedDepth: defaultExpandedDepth,
          searchQuery: searchQuery,
          expansionGeneration: expansionGeneration,
          forceExpandAll: forceExpandAll,
          sortKeys: sortKeys,
          onPathSelected: onPathSelected,
          onValueChanged: onValueChanged,
          onNodeAction: onNodeAction,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal node widget
// ---------------------------------------------------------------------------

class _LazyNode extends StatefulWidget {
  final String keyName;
  final dynamic value;
  final int depth;
  final String path;

  /// True when this node represents an array index (e.g. [0], [1]).
  final bool isArrayIndex;

  final int defaultExpandedDepth;
  final String searchQuery;
  final int expansionGeneration;
  final bool? forceExpandAll;
  final bool sortKeys;
  final void Function(String path)? onPathSelected;
  final void Function(String path, dynamic newValue)? onValueChanged;
  final void Function(String path, TreeNodeAction action)? onNodeAction;

  const _LazyNode({
    required this.keyName,
    required this.value,
    required this.depth,
    required this.path,
    required this.isArrayIndex,
    required this.defaultExpandedDepth,
    required this.searchQuery,
    required this.expansionGeneration,
    this.forceExpandAll,
    required this.sortKeys,
    this.onPathSelected,
    this.onValueChanged,
    this.onNodeAction,
  });

  @override
  State<_LazyNode> createState() => _LazyNodeState();
}

class _LazyNodeState extends State<_LazyNode> {
  late bool _expanded;

  // Inline editing state (leaf nodes only).
  bool _isEditing = false;
  late TextEditingController _editController;
  String? _editError;
  final FocusNode _editFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _expanded = _computeExpanded();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LazyNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signalChanged =
        oldWidget.expansionGeneration != widget.expansionGeneration;
    final queryChanged = oldWidget.searchQuery != widget.searchQuery;
    if (signalChanged || queryChanged) {
      setState(() => _expanded = _computeExpanded());
    }
  }

  bool _computeExpanded() {
    // When a search is active, auto-expand nodes whose subtree contains a match.
    if (widget.searchQuery.isNotEmpty) {
      return _matchesSearch(widget.keyName, widget.value, widget.searchQuery);
    }
    // Honour programmatic expand/collapse signal.
    if (widget.forceExpandAll != null) return widget.forceExpandAll!;
    // Fall back to depth-based default.
    return widget.depth < widget.defaultExpandedDepth;
  }

  // -------------------------------------------------------------------------
  // Styles
  // -------------------------------------------------------------------------

  TextStyle _keyStyle() => GoogleFonts.jetBrainsMono(
    // Array indices use number color to visually distinguish from object keys.
    color: widget.isArrayIndex ? AppColors.jsonNumber : AppColors.jsonKey,
    fontSize: AppDimensions.fontSizeM,
  );

  TextStyle _valueStyle(dynamic v) {
    if (v == null) {
      return GoogleFonts.jetBrainsMono(
        color: AppColors.jsonNull,
        fontSize: AppDimensions.fontSizeM,
      );
    }
    if (v is bool) {
      return GoogleFonts.jetBrainsMono(
        color: AppColors.jsonBoolean,
        fontSize: AppDimensions.fontSizeM,
      );
    }
    if (v is num) {
      return GoogleFonts.jetBrainsMono(
        color: AppColors.jsonNumber,
        fontSize: AppDimensions.fontSizeM,
      );
    }
    return GoogleFonts.jetBrainsMono(
      color: AppColors.jsonString,
      fontSize: AppDimensions.fontSizeM,
    );
  }

  TextStyle _previewStyle() => GoogleFonts.jetBrainsMono(
    color: AppColors.textSecondary,
    fontSize: AppDimensions.fontSizeM,
  );

  // -------------------------------------------------------------------------
  // Type icon badge
  // -------------------------------------------------------------------------

  /// Returns a compact monospace badge indicating the value type.
  Widget _buildTypeIcon(dynamic v) {
    final String label;
    final Color color;

    if (v is Map) {
      label = '{}';
      color = AppColors.jsonBracket;
    } else if (v is List) {
      label = '[]';
      color = AppColors.jsonBracket;
    } else if (v is String) {
      label = '"';
      color = AppColors.jsonString;
    } else if (v is int || v is double) {
      label = '#';
      color = AppColors.jsonNumber;
    } else if (v is bool) {
      label = v ? 'T' : 'F';
      color = AppColors.jsonBoolean;
    } else {
      // null
      label = '∅';
      color = AppColors.jsonNull;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: color.withValues(alpha: 0.75),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Value rendering
  // -------------------------------------------------------------------------

  String _scalarText(dynamic v) {
    if (v == null) return 'null';
    if (v is String) {
      return '"${v.length > 80 ? '${v.substring(0, 80)}...' : v}"';
    }
    return v.toString();
  }

  Widget _buildValuePreview() {
    final v = widget.value;
    if (v is Map) {
      final len = v.length;
      return Text(
        '{$len ${len == 1 ? 'key' : 'keys'}}',
        style: _previewStyle(),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }
    if (v is List) {
      final len = v.length;
      return Text(
        '[$len ${len == 1 ? 'item' : 'items'}]',
        style: _previewStyle(),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }
    return _buildHighlightedText(
      _scalarText(v),
      widget.searchQuery,
      _valueStyle(v),
    );
  }

  // -------------------------------------------------------------------------
  // Inline editing
  // -------------------------------------------------------------------------

  /// Converts the current value to an editable string (no surrounding quotes
  /// for strings — the user sees raw text).
  String _editableText(dynamic v) {
    if (v == null) return 'null';
    if (v is String) return v;
    return v.toString();
  }

  /// Parses [text] into a typed value matching [original]'s type.
  ///
  /// Returns the parsed value, or throws [FormatException] with a human-
  /// readable message when the text is not valid for the original type.
  dynamic _parseTyped(String text, dynamic original) {
    if (original is bool) {
      if (text == 'true') return true;
      if (text == 'false') return false;
      throw const FormatException('Enter true or false');
    }
    if (original is int) {
      final v = int.tryParse(text);
      if (v == null) throw const FormatException('Enter a whole number');
      return v;
    }
    if (original is double) {
      final v = double.tryParse(text);
      if (v == null) throw const FormatException('Enter a number');
      return v;
    }
    if (original == null) {
      if (text == 'null') return null;
      // Allow the user to replace null with a typed value.
      final asInt = int.tryParse(text);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(text);
      if (asDouble != null) return asDouble;
      if (text == 'true') return true;
      if (text == 'false') return false;
      return text; // fallback to string
    }
    // String: accept anything.
    return text;
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editError = null;
      _editController.text = _editableText(widget.value);
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
    // Delay so the field is built before requesting focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  void _cancelEditing() => setState(() {
    _isEditing = false;
    _editError = null;
  });

  void _commitEdit() {
    final text = _editController.text;
    try {
      final newValue = _parseTyped(text, widget.value);
      setState(() {
        _isEditing = false;
        _editError = null;
      });
      widget.onValueChanged?.call(widget.path, newValue);
    } on FormatException catch (e) {
      setState(() => _editError = e.message);
    }
  }

  Widget _buildInlineEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyboardListener(
          focusNode: FocusNode(), // wrapper just for Escape
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              _cancelEditing();
            }
          },
          child: TextField(
            controller: _editController,
            focusNode: _editFocus,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: _editError != null
                  ? AppColors.error
                  : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: _editError != null
                      ? AppColors.error
                      : AppColors.borderFocused,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: _editError != null
                      ? AppColors.error
                      : AppColors.borderFocused,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(
                  color: _editError != null
                      ? AppColors.error
                      : AppColors.primary,
                  width: 1.5,
                ),
              ),
              hintText: 'Enter value…',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textMuted,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Apply (Enter)',
                    child: InkWell(
                      onTap: _commitEdit,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Cancel (Escape)',
                    child: InkWell(
                      onTap: _cancelEditing,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _commitEdit(),
          ),
        ),
        if (_editError != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2),
            child: Text(
              _editError!,
              style: const TextStyle(color: AppColors.error, fontSize: 10),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Context menu
  // -------------------------------------------------------------------------

  Future<void> _showContextMenu(BuildContext ctx, Offset globalOffset) async {
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalOffset.dx, globalOffset.dy, 1, 1),
      Offset.zero & overlay.size,
    );

    final isMap = widget.value is Map;
    final isList = widget.value is List;

    final action = await showMenu<TreeNodeAction>(
      context: ctx,
      position: position,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        side: const BorderSide(color: AppColors.border),
      ),
      items: [
        if (isMap)
          const PopupMenuItem(
            value: TreeNodeAction.addKey,
            child: _ContextMenuItem(
              icon: Icons.add_box_outlined,
              label: 'Add key',
            ),
          ),
        if (isList)
          const PopupMenuItem(
            value: TreeNodeAction.addItem,
            child: _ContextMenuItem(
              icon: Icons.playlist_add,
              label: 'Add item',
            ),
          ),
        const PopupMenuItem(
          value: TreeNodeAction.duplicate,
          child: _ContextMenuItem(
            icon: Icons.copy_all_outlined,
            label: 'Duplicate',
          ),
        ),
        const PopupMenuItem(
          value: TreeNodeAction.delete,
          child: _ContextMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            isDestructive: true,
          ),
        ),
      ],
    );

    if (action != null && mounted) {
      widget.onNodeAction?.call(widget.path, action);
    }
  }

  // -------------------------------------------------------------------------
  // Copy button
  // -------------------------------------------------------------------------

  Widget _buildCopyButton() {
    return Tooltip(
      message: 'Copy value',
      child: InkWell(
        onTap: _copyValue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(Icons.copy, size: 12, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Future<void> _copyValue() async {
    await Clipboard.setData(
      ClipboardData(text: _serializeForClipboard(widget.value)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied: ${widget.path}',
          style: GoogleFonts.jetBrainsMono(fontSize: AppDimensions.fontSizeS),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Keyboard navigation
  // -------------------------------------------------------------------------

  /// Handles keyboard events for this node.
  ///
  /// Desktop shortcuts:
  ///   → (ArrowRight) : expand a collapsed container
  ///   ← (ArrowLeft)  : collapse an expanded container
  ///   Enter / Space  : toggle container, or copy leaf value
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isContainer = widget.value is Map || widget.value is List;

    if (key == LogicalKeyboardKey.arrowRight && isContainer && !_expanded) {
      setState(() => _expanded = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && isContainer && _expanded) {
      setState(() => _expanded = false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (isContainer) {
        setState(() => _expanded = !_expanded);
      } else {
        _copyValue();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Path helper
  // -------------------------------------------------------------------------

  /// Returns the JSON-Path of a child node.
  /// [isIndex] must be true when [childKey] is an array index like `[0]`.
  String _childPath(String childKey, {required bool isIndex}) {
    return isIndex ? '${widget.path}$childKey' : '${widget.path}.$childKey';
  }

  // -------------------------------------------------------------------------
  // Children
  // -------------------------------------------------------------------------

  List<MapEntry<String, dynamic>> _sortedEntries(Map<String, dynamic> map) {
    final entries = map.entries.toList();
    if (widget.sortKeys) entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  _LazyNode _childNode({
    required String keyName,
    required dynamic value,
    required String path,
    required bool isArrayIndex,
  }) {
    return _LazyNode(
      keyName: keyName,
      value: value,
      depth: widget.depth + 1,
      path: path,
      isArrayIndex: isArrayIndex,
      defaultExpandedDepth: widget.defaultExpandedDepth,
      searchQuery: widget.searchQuery,
      expansionGeneration: widget.expansionGeneration,
      forceExpandAll: widget.forceExpandAll,
      sortKeys: widget.sortKeys,
      onPathSelected: widget.onPathSelected,
      onValueChanged: widget.onValueChanged,
      onNodeAction: widget.onNodeAction,
    );
  }

  Widget _buildChildrenWidget() {
    final v = widget.value;
    const virtualizationThreshold = 32;

    if (v is Map<String, dynamic>) {
      final entries = _sortedEntries(v);
      if (entries.isEmpty) return const SizedBox.shrink();
      if (entries.length <= virtualizationThreshold) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries
              .map(
                (e) => _childNode(
                  keyName: e.key,
                  value: e.value,
                  path: _childPath(e.key, isIndex: false),
                  isArrayIndex: false,
                ),
              )
              .toList(),
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          return _childNode(
            keyName: e.key,
            value: e.value,
            path: _childPath(e.key, isIndex: false),
            isArrayIndex: false,
          );
        },
      );
    }

    if (v is List) {
      if (v.isEmpty) return const SizedBox.shrink();
      if (v.length <= virtualizationThreshold) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            v.length,
            (i) => _childNode(
              keyName: '[$i]',
              value: v[i],
              path: _childPath('[$i]', isIndex: true),
              isArrayIndex: true,
            ),
          ),
        );
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: v.length,
        itemBuilder: (context, index) => _childNode(
          keyName: '[$index]',
          value: v[index],
          path: _childPath('[$index]', isIndex: true),
          isArrayIndex: true,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isContainer = widget.value is Map || widget.value is List;
    final indent = widget.depth * 12.0;

    // ----- Leaf node -----
    if (!isContainer) {
      return GestureDetector(
        onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
        onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
        child: Focus(
          onKeyEvent: _handleKeyEvent,
          child: GestureDetector(
            onTap: () => widget.onPathSelected?.call(widget.path),
            onDoubleTap: widget.onValueChanged != null ? _startEditing : null,
            child: Padding(
              padding: EdgeInsets.only(left: indent, top: 3, bottom: 3),
              child: _isEditing
                  ? Row(
                      children: [
                        _buildTypeIcon(widget.value),
                        Flexible(
                          child: _buildHighlightedText(
                            '${widget.keyName}: ',
                            widget.searchQuery,
                            _keyStyle(),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.paddingS),
                        Expanded(child: _buildInlineEditor()),
                      ],
                    )
                  : Row(
                      children: [
                        _buildTypeIcon(widget.value),
                        Flexible(
                          child: _buildHighlightedText(
                            '${widget.keyName}: ',
                            widget.searchQuery,
                            _keyStyle(),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.paddingS),
                        Expanded(child: _buildValuePreview()),
                        if (widget.onValueChanged != null)
                          Tooltip(
                            message: 'Edit value (double-click)',
                            child: InkWell(
                              onTap: _startEditing,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusS,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Icon(
                                  Icons.edit,
                                  size: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        _buildCopyButton(),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    // ----- Container node (Map or List) -----
    return GestureDetector(
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: Padding(
          padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — tap toggles expansion and reports path.
              InkWell(
                onTap: () {
                  setState(() => _expanded = !_expanded);
                  widget.onPathSelected?.call(widget.path);
                },
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_more : Icons.chevron_right,
                        size: AppDimensions.iconSizeS,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      _buildTypeIcon(widget.value),
                      Flexible(
                        child: _buildHighlightedText(
                          '${widget.keyName}: ',
                          widget.searchQuery,
                          _keyStyle(),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(child: _buildValuePreview()),
                      _buildCopyButton(),
                    ],
                  ),
                ),
              ),
              // Children — built lazily, only when expanded.
              if (_expanded) _buildChildrenWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Context menu item widget
// ---------------------------------------------------------------------------

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimensions.iconSizeS, color: color),
        const SizedBox(width: AppDimensions.paddingS),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: color,
          ),
        ),
      ],
    );
  }
}
