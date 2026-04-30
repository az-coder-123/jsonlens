import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/settings/settings_provider.dart';
import '../providers/json_analyzer_provider.dart';
import 'depth_dialog.dart';
import 'lazy_json_tree.dart';
import 'processing_overlay.dart';

/// Tree view widget for displaying JSON in an expandable/collapsible tree.
///
/// Phase 1:
///   - Search / filter with match highlighting and auto-expand
///   - Per-node copy button (in LazyJsonTree)
///   - JSON Path display in the bottom status strip
///   - Expand All / Collapse All toolbar buttons
///
/// Phase 2:
///   - Sort Keys toggle button (persisted via Settings)
///   - Node type icons, array index coloring, keyboard nav (in LazyJsonTree)
class JsonTreeViewWidget extends ConsumerStatefulWidget {
  const JsonTreeViewWidget({super.key});

  @override
  ConsumerState<JsonTreeViewWidget> createState() => _JsonTreeViewWidgetState();
}

class _JsonTreeViewWidgetState extends ConsumerState<JsonTreeViewWidget> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedPath = '';
  int _expansionGeneration = 0;

  /// `true` = expand all, `false` = collapse all, `null` = use depth setting.
  bool? _forceExpandAll;

  bool _isSearchVisible = false;
  bool _isFilterVisible = false;

  /// Types currently hidden. Values: 'object','array','string','number','boolean','null'.
  final Set<String> _hiddenTypes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Toolbar actions
  // -------------------------------------------------------------------------

  void _expandAll() => setState(() {
    _forceExpandAll = true;
    _expansionGeneration++;
  });

  void _collapseAll() => setState(() {
    _forceExpandAll = false;
    _expansionGeneration++;
  });

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) _clearSearch();
    });
  }

  void _toggleFilter() => setState(() => _isFilterVisible = !_isFilterVisible);

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // -------------------------------------------------------------------------
  // Inline edit application
  // -------------------------------------------------------------------------

  /// Parses a JSON-Path like `$.users[0].name` into navigation keys.
  ///
  /// Returns a list of [String] (object key) or [int] (array index) segments,
  /// skipping the leading `$`.
  List<Object> _pathSegments(String path) {
    final segments = <Object>[];
    var rest = path.startsWith(r'$') ? path.substring(1) : path;

    while (rest.isNotEmpty) {
      if (rest.startsWith('.')) rest = rest.substring(1);

      if (rest.startsWith('[')) {
        final end = rest.indexOf(']');
        if (end == -1) break;
        final idx = int.tryParse(rest.substring(1, end));
        if (idx != null) segments.add(idx);
        rest = rest.substring(end + 1);
      } else {
        final dotIdx = rest.indexOf('.');
        final bracketIdx = rest.indexOf('[');
        final int end;
        if (dotIdx == -1 && bracketIdx == -1) {
          end = rest.length;
        } else if (dotIdx == -1) {
          end = bracketIdx;
        } else if (bracketIdx == -1) {
          end = dotIdx;
        } else {
          end = dotIdx < bracketIdx ? dotIdx : bracketIdx;
        }
        if (end == 0) break;
        segments.add(rest.substring(0, end));
        rest = rest.substring(end);
      }
    }

    return segments;
  }

  /// Navigates [data] using [segments] (all but last), then sets the leaf.
  ///
  /// Returns false when the path cannot be resolved.
  bool _setAtPath(dynamic data, List<Object> segments, dynamic newValue) {
    if (segments.isEmpty) return false;

    dynamic current = data;
    for (int i = 0; i < segments.length - 1; i++) {
      final seg = segments[i];
      if (seg is String && current is Map<String, dynamic>) {
        current = current[seg];
      } else if (seg is int && current is List) {
        current = current[seg];
      } else {
        return false; // path mismatch
      }
    }

    final last = segments.last;
    if (last is String && current is Map<String, dynamic>) {
      current[last] = newValue;
      return true;
    }
    if (last is int && current is List) {
      current[last] = newValue;
      return true;
    }
    return false;
  }

  /// Called by [LazyJsonTree] when a leaf value is edited inline.
  ///
  /// Navigates the current parsed data to the node at [path], updates it,
  /// re-serialises to formatted JSON, and pushes the change to the provider.
  Future<void> _applyEdit(String path, dynamic newValue) async {
    final parsedData = ref.read(parsedDataProvider);
    if (parsedData == null) return;

    final segments = _pathSegments(path);
    final ok = _setAtPath(parsedData, segments, newValue);
    if (!ok) return;

    final json = const JsonEncoder.withIndent('  ').convert(parsedData);
    await ref.read(jsonAnalyzerProvider.notifier).updateInput(json);
  }

  // -------------------------------------------------------------------------
  // Node action application (2.3)
  // -------------------------------------------------------------------------

  /// Navigates [data] to the node at exactly [segments].
  dynamic _nodeAtSegments(dynamic data, List<Object> segments) {
    dynamic current = data;
    for (final seg in segments) {
      if (seg is String && current is Map<String, dynamic>) {
        current = current[seg];
      } else if (seg is int && current is List) {
        current = current[seg];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Dispatches a context menu action received from [LazyJsonTree].
  Future<void> _applyNodeAction(String path, TreeNodeAction action) async {
    final parsedData = ref.read(parsedDataProvider);
    if (parsedData == null) return;
    final segments = _pathSegments(path);

    switch (action) {
      case TreeNodeAction.delete:
        await _deleteNode(parsedData, segments);
      case TreeNodeAction.addKey:
        await _addKey(parsedData, segments);
      case TreeNodeAction.addItem:
        await _addItem(parsedData, segments);
      case TreeNodeAction.duplicate:
        await _duplicateNode(parsedData, segments);
    }
  }

  Future<void> _deleteNode(dynamic data, List<Object> segments) async {
    if (segments.isEmpty) return;

    final node = _nodeAtSegments(data, segments);
    final isContainer = node is Map || node is List;

    if (isContainer) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Delete node',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppDimensions.fontSizeL,
            ),
          ),
          content: const Text(
            'This will delete the node and all its children.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Navigate to parent and remove the key/index.
    final parentSegs = segments.sublist(0, segments.length - 1);
    final parent = parentSegs.isEmpty
        ? data
        : _nodeAtSegments(data, parentSegs);
    final last = segments.last;

    if (last is String && parent is Map<String, dynamic>) {
      parent.remove(last);
    } else if (last is int && parent is List) {
      parent.removeAt(last);
    } else {
      return;
    }

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await ref.read(jsonAnalyzerProvider.notifier).updateInput(json);
  }

  Future<void> _addKey(dynamic data, List<Object> segments) async {
    final node = _nodeAtSegments(data, segments);
    if (node is! Map<String, dynamic>) return;

    final keyName = await showDialog<String>(
      context: context,
      builder: (_) => const _AddKeyDialog(),
    );
    if (keyName == null || keyName.isEmpty) return;

    // Ensure the key is unique.
    String finalKey = keyName;
    int attempt = 1;
    while (node.containsKey(finalKey)) {
      finalKey = '$keyName ($attempt)';
      attempt++;
    }

    node[finalKey] = null;

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await ref.read(jsonAnalyzerProvider.notifier).updateInput(json);
  }

  Future<void> _addItem(dynamic data, List<Object> segments) async {
    final node = _nodeAtSegments(data, segments);
    if (node is! List) return;

    node.add(null);

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await ref.read(jsonAnalyzerProvider.notifier).updateInput(json);
  }

  Future<void> _duplicateNode(dynamic data, List<Object> segments) async {
    if (segments.isEmpty) return;

    final node = _nodeAtSegments(data, segments);
    // Deep copy via JSON round-trip.
    final deepCopy = jsonDecode(jsonEncode(node));

    final parentSegs = segments.sublist(0, segments.length - 1);
    final parent = parentSegs.isEmpty
        ? data
        : _nodeAtSegments(data, parentSegs);
    final last = segments.last;

    if (last is String && parent is Map<String, dynamic>) {
      String copyKey = '${last}_copy';
      int attempt = 1;
      while (parent.containsKey(copyKey)) {
        copyKey = '${last}_copy_$attempt';
        attempt++;
      }
      parent[copyKey] = deepCopy;
    } else if (last is int && parent is List) {
      parent.insert(last + 1, deepCopy);
    } else {
      return;
    }

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await ref.read(jsonAnalyzerProvider.notifier).updateInput(json);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final parsedData = ref.watch(parsedDataProvider);
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final isProcessing = ref.watch(isProcessingProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          if (_isSearchVisible) _buildSearchBar(),
          if (_isFilterVisible) _buildFilterBar(),
          if (_selectedPath.isNotEmpty) _buildBreadcrumbBar(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                _buildContent(
                  parsedData: parsedData,
                  isValid: isValid,
                  isEmpty: isEmpty,
                ),
                if (isProcessing)
                  const ProcessingOverlay(message: 'Processing large JSON...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
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
            Icons.account_tree,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            AppStrings.treeViewTab,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _buildExpandCollapseButtons(),
          _buildSearchToggleButton(),
          _buildFilterButton(),
          _buildSortKeysButton(),
          _buildSettingsButton(context),
        ],
      ),
    );
  }

  Widget _buildExpandCollapseButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Expand all',
          icon: const Icon(
            Icons.unfold_more,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          onPressed: _expandAll,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          tooltip: 'Collapse all',
          icon: const Icon(
            Icons.unfold_less,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          onPressed: _collapseAll,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _buildSearchToggleButton() {
    return IconButton(
      tooltip: _isSearchVisible ? 'Close search' : 'Search in tree',
      icon: Icon(
        Icons.search,
        size: AppDimensions.iconSizeS,
        color: _isSearchVisible ? AppColors.primary : AppColors.textSecondary,
      ),
      onPressed: _toggleSearch,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildFilterButton() {
    final active = _hiddenTypes.isNotEmpty || _isFilterVisible;
    return IconButton(
      tooltip: _hiddenTypes.isNotEmpty
          ? 'Type filter: ${6 - _hiddenTypes.length}/6 types visible'
          : 'Filter by type',
      icon: Icon(
        Icons.filter_list,
        size: AppDimensions.iconSizeS,
        color: active ? AppColors.primary : AppColors.textSecondary,
      ),
      onPressed: _toggleFilter,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  /// Toggle button for alphabetical key sorting (Phase 2).
  Widget _buildSortKeysButton() {
    final sortKeys = ref.watch(settingsProvider).sortKeys;
    return IconButton(
      tooltip: sortKeys ? 'Sort keys: ON (click to disable)' : 'Sort keys A-Z',
      icon: Icon(
        Icons.sort_by_alpha,
        size: AppDimensions.iconSizeS,
        color: sortKeys ? AppColors.primary : AppColors.textSecondary,
      ),
      onPressed: () async {
        await ref.read(settingsProvider.notifier).setSortKeys(!sortKeys);
        setState(() => _expansionGeneration++);
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return IconButton(
      tooltip: 'Tree settings',
      icon: const Icon(
        Icons.settings,
        size: AppDimensions.iconSizeS,
        color: AppColors.textSecondary,
      ),
      onPressed: () async {
        final selected = await showDialog<int>(
          context: context,
          builder: (context) =>
              DepthDialog(initial: settings.defaultExpandedDepth),
        );
        if (selected != null) {
          await ref
              .read(settingsProvider.notifier)
              .setDefaultExpandedDepth(selected);
          setState(() {
            _forceExpandAll = null;
            _expansionGeneration++;
          });
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  // -------------------------------------------------------------------------
  // Search bar
  // -------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search keys or values...',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: const Icon(
                Icons.close,
                size: AppDimensions.iconSizeS,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Filter bar (2.4)
  // -------------------------------------------------------------------------

  Color _typeColor(String type) => switch (type) {
    'object' || 'array' => AppColors.jsonBracket,
    'string' => AppColors.jsonString,
    'number' => AppColors.jsonNumber,
    'boolean' => AppColors.jsonBoolean,
    _ => AppColors.jsonNull,
  };

  Widget _buildFilterBar() {
    const filters = [
      ('object', '{}'),
      ('array', '[]'),
      ('string', '"'),
      ('number', '#'),
      ('boolean', 'T/F'),
      ('null', '∅'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: 6,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            'Show:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          ...filters.map((f) {
            final type = f.$1;
            final label = f.$2;
            final isVisible = !_hiddenTypes.contains(type);
            final typeColor = _typeColor(type);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: isVisible ? 'Hide $type nodes' : 'Show $type nodes',
                child: InkWell(
                  onTap: () => setState(() {
                    if (isVisible) {
                      _hiddenTypes.add(type);
                    } else {
                      _hiddenTypes.remove(type);
                    }
                  }),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isVisible
                          ? typeColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isVisible
                            ? typeColor.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isVisible ? typeColor : AppColors.textMuted,
                        decoration: isVisible
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          if (_hiddenTypes.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _hiddenTypes.clear()),
              child: Text(
                'Reset',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Breadcrumb bar
  // -------------------------------------------------------------------------

  /// Parses a JSON-Path string (e.g. `$.users[0].profile`) into ordered
  /// segments: `['$', 'users', '[0]', 'profile']`.
  List<String> _parseBreadcrumbs(String path) {
    final segments = <String>[];
    if (path.isEmpty) return segments;

    // Always starts with `$`.
    segments.add('\$');
    var rest = path.startsWith('\$') ? path.substring(1) : path;

    while (rest.isNotEmpty) {
      if (rest.startsWith('.')) rest = rest.substring(1);

      if (rest.startsWith('[')) {
        // Array index segment like [0].
        final end = rest.indexOf(']');
        if (end == -1) break;
        segments.add(rest.substring(0, end + 1));
        rest = rest.substring(end + 1);
      } else {
        // Named key — read until next `.` or `[`.
        final dotIdx = rest.indexOf('.');
        final bracketIdx = rest.indexOf('[');
        final int end;
        if (dotIdx == -1 && bracketIdx == -1) {
          end = rest.length;
        } else if (dotIdx == -1) {
          end = bracketIdx;
        } else if (bracketIdx == -1) {
          end = dotIdx;
        } else {
          end = dotIdx < bracketIdx ? dotIdx : bracketIdx;
        }
        if (end == 0) break; // safeguard
        segments.add(rest.substring(0, end));
        rest = rest.substring(end);
      }
    }

    return segments;
  }

  /// Reconstructs the JSON-Path string from [segments] up to index [upTo].
  String _pathFromSegments(List<String> segments, int upTo) {
    final buf = StringBuffer();
    for (int i = 0; i <= upTo && i < segments.length; i++) {
      final seg = segments[i];
      if (seg == '\$') {
        buf.write('\$');
      } else if (seg.startsWith('[')) {
        buf.write(seg);
      } else {
        buf.write('.$seg');
      }
    }
    return buf.toString();
  }

  Widget _buildBreadcrumbBar() {
    final segments = _parseBreadcrumbs(_selectedPath);

    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
              ),
              child: Row(
                children: [
                  for (int i = 0; i < segments.length; i++) ...[
                    _BreadcrumbSegment(
                      label: segments[i],
                      isLast: i == segments.length - 1,
                      isArrayIndex: segments[i].startsWith('['),
                      onTap: () => setState(
                        () => _selectedPath = _pathFromSegments(segments, i),
                      ),
                    ),
                    if (i < segments.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.chevron_right,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Copy path button.
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _selectedPath));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('JSON path copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: 4,
              ),
              child: Icon(Icons.copy, size: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Content
  // -------------------------------------------------------------------------

  Widget _buildContent({
    required dynamic parsedData,
    required bool isValid,
    required bool isEmpty,
  }) {
    if (isEmpty || !isValid || parsedData == null) {
      return _buildPlaceholder();
    }
    return _buildTreeView(parsedData);
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        AppStrings.outputPlaceholder,
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeM,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildTreeView(dynamic data) {
    final settings = ref.watch(settingsProvider);
    return LazyJsonTree(
      data: data,
      defaultExpandedDepth: settings.defaultExpandedDepth,
      searchQuery: _searchQuery,
      expansionGeneration: _expansionGeneration,
      forceExpandAll: _forceExpandAll,
      sortKeys: settings.sortKeys,
      hiddenTypes: _hiddenTypes,
      onPathSelected: (path) => setState(() => _selectedPath = path),
      onValueChanged: _applyEdit,
      onNodeAction: _applyNodeAction,
    );
  }
}

// ---------------------------------------------------------------------------
// Add-key dialog
// ---------------------------------------------------------------------------

/// Dialog that prompts the user for a key name when adding a node to a Map.
class _AddKeyDialog extends StatefulWidget {
  const _AddKeyDialog();

  @override
  State<_AddKeyDialog> createState() => _AddKeyDialogState();
}

class _AddKeyDialogState extends State<_AddKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Add key',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeL,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppDimensions.fontSizeS,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Key name',
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            borderSide: const BorderSide(
              color: AppColors.borderFocused,
              width: 1.5,
            ),
          ),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Breadcrumb segment widget
// ---------------------------------------------------------------------------
///
/// The last (active) segment is rendered in [AppColors.primary]; ancestor
/// segments are muted but still tappable so the user can jump up the path.
class _BreadcrumbSegment extends StatefulWidget {
  final String label;
  final bool isLast;
  final bool isArrayIndex;
  final VoidCallback onTap;

  const _BreadcrumbSegment({
    required this.label,
    required this.isLast,
    required this.isArrayIndex,
    required this.onTap,
  });

  @override
  State<_BreadcrumbSegment> createState() => _BreadcrumbSegmentState();
}

class _BreadcrumbSegmentState extends State<_BreadcrumbSegment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (widget.isLast) {
      color = AppColors.primary;
    } else if (_hovered) {
      color = AppColors.textSecondary;
    } else {
      color = AppColors.textMuted;
    }

    // Array indices ([0]) use a slightly different style.
    final fontStyle = widget.isArrayIndex ? FontStyle.italic : FontStyle.normal;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: color,
            fontStyle: fontStyle,
            fontWeight: widget.isLast ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
