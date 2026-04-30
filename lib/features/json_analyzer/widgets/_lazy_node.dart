part of 'lazy_json_tree.dart';

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

  /// Set of type names whose nodes should be hidden (propagated from [LazyJsonTree]).
  final Set<String> hiddenTypes;

  /// JSON path to visually highlight (propagated from [LazyJsonTree]).
  final String? highlightedPath;

  /// Paths that must be force-expanded (propagated from [LazyJsonTree]).
  final Set<String> forcedExpandedPaths;

  /// GlobalKey attached to the highlighted node for scroll-to (propagated from [LazyJsonTree]).
  final GlobalKey? highlightedNodeKey;

  /// Which parts of each node to match during search (propagated from [LazyJsonTree]).
  final SearchScope searchScope;

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
    this.hiddenTypes = const {},
    this.highlightedPath,
    this.forcedExpandedPaths = const {},
    this.highlightedNodeKey,
    this.searchScope = SearchScope.both,
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
    // Targeted re-evaluation when forced-expansion state for this node changes.
    final wasForced = oldWidget.forcedExpandedPaths.contains(widget.path);
    final isForced = widget.forcedExpandedPaths.contains(widget.path);
    if (signalChanged || queryChanged || wasForced != isForced) {
      setState(() => _expanded = _computeExpanded());
    }
  }

  bool _computeExpanded() {
    // When a search is active, auto-expand nodes whose subtree contains a match.
    if (widget.searchQuery.isNotEmpty) {
      return _matchesSearch(
        widget.keyName,
        widget.value,
        widget.searchQuery,
        widget.searchScope,
      );
    }
    // Force-expand specific ancestor paths for editor→tree sync.
    // Checked before forceExpandAll so that cursor navigation in the editor
    // can reveal a node even when the tree is in "Collapse All" mode.
    if (widget.forcedExpandedPaths.contains(widget.path)) return true;
    // Honour programmatic expand/collapse signal.
    if (widget.forceExpandAll != null) return widget.forceExpandAll!;
    // Fall back to depth-based default.
    return widget.depth < widget.defaultExpandedDepth;
  }

  /// Search query used for key highlighting — empty when scope is values-only.
  String get _keyQuery =>
      widget.searchScope != SearchScope.valuesOnly ? widget.searchQuery : '';

  /// Search query used for value highlighting — empty when scope is keys-only.
  String get _valueQuery =>
      widget.searchScope != SearchScope.keysOnly ? widget.searchQuery : '';

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
    return _buildHighlightedText(_scalarText(v), _valueQuery, _valueStyle(v));
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
    return LazyInlineEditor(
      controller: _editController,
      focusNode: _editFocus,
      errorText: _editError,
      onCommit: _commitEdit,
      onCancel: _cancelEditing,
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
      searchScope: widget.searchScope,
      expansionGeneration: widget.expansionGeneration,
      forceExpandAll: widget.forceExpandAll,
      sortKeys: widget.sortKeys,
      onPathSelected: widget.onPathSelected,
      onValueChanged: widget.onValueChanged,
      onNodeAction: widget.onNodeAction,
      hiddenTypes: widget.hiddenTypes,
      highlightedPath: widget.highlightedPath,
      forcedExpandedPaths: widget.forcedExpandedPaths,
      highlightedNodeKey: widget.highlightedNodeKey,
    );
  }

  Widget _buildChildrenWidget() {
    return LazyNodeChildren(
      value: widget.value,
      sortEntries: _sortedEntries,
      buildPath: _childPath,
      buildChild: (keyName, value, path, isArrayIndex) => _childNode(
        keyName: keyName,
        value: value,
        path: path,
        isArrayIndex: isArrayIndex,
      ),
    );
  }

  Widget _buildLeafNode(double indent, bool isHighlighted) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: () => widget.onPathSelected?.call(widget.path),
          onDoubleTap: widget.onValueChanged != null ? _startEditing : null,
          child: AnimatedContainer(
            key: isHighlighted ? widget.highlightedNodeKey : null,
            duration: const Duration(milliseconds: 200),
            color: isHighlighted
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            child: Padding(
              padding: EdgeInsets.only(left: indent, top: 3, bottom: 3),
              child: LazyLeafNodeContent(
                isEditing: _isEditing,
                typeIcon: _buildTypeIcon(widget.value),
                keyWidget: _buildHighlightedText(
                  '${widget.keyName}: ',
                  _keyQuery,
                  _keyStyle(),
                ),
                valueWidget: _buildValuePreview(),
                inlineEditor: _buildInlineEditor(),
                canEdit: widget.onValueChanged != null,
                onEdit: _startEditing,
                copyButton: _buildCopyButton(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContainerNode(double indent, bool isHighlighted) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showContextMenu(context, d.globalPosition),
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: AnimatedContainer(
          key: isHighlighted ? widget.highlightedNodeKey : null,
          duration: const Duration(milliseconds: 200),
          color: isHighlighted
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Padding(
            padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LazyContainerNodeHeader(
                  expanded: _expanded,
                  typeIcon: _buildTypeIcon(widget.value),
                  keyWidget: _buildHighlightedText(
                    '${widget.keyName}: ',
                    _keyQuery,
                    _keyStyle(),
                  ),
                  valueWidget: _buildValuePreview(),
                  onTap: () {
                    setState(() => _expanded = !_expanded);
                    widget.onPathSelected?.call(widget.path);
                  },
                  copyButton: _buildCopyButton(),
                ),
                if (_expanded) _buildChildrenWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Hide this node entirely when its type is filtered out.
    if (widget.hiddenTypes.contains(_typeOf(widget.value))) {
      return const SizedBox.shrink();
    }

    final isContainer = widget.value is Map || widget.value is List;
    final indent = widget.depth * 12.0;
    final isHighlighted =
        widget.highlightedPath != null && widget.highlightedPath == widget.path;

    // ----- Leaf node -----
    if (!isContainer) {
      return _buildLeafNode(indent, isHighlighted);
    }

    // ----- Container node (Map or List) -----
    return _buildContainerNode(indent, isHighlighted);
  }
}
