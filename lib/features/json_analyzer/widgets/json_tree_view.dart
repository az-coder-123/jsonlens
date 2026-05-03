import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/performance_constants.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/utils/json_key_collector.dart';
import '../../../core/utils/json_object_filter.dart';
import '../../../core/utils/json_path.dart';
import '../../../core/utils/json_position_mapper.dart';
import '../models/search_filter.dart';
import '../providers/json_analyzer_provider.dart';
import 'add_key_dialog.dart';
import 'breadcrumb_bar.dart';
import 'depth_dialog.dart';
import 'json_filter_bar.dart';
import 'lazy_json_tree.dart';
import 'processing_overlay.dart';
import 'type_filter_bar.dart';

part '_scope_chip.dart';
part '_search_count_badge.dart';
part '_search_icon_btn.dart';

// ---------------------------------------------------------------------------
// Path-list search helpers
// ---------------------------------------------------------------------------

/// Returns the canonical type name for [value] used by the search type filter.
String _typeOfValue(dynamic value) {
  if (value == null) return 'null';
  if (value is Map) return 'object';
  if (value is List) return 'array';
  if (value is bool) return 'boolean';
  if (value is num) return 'number';
  return 'string';
}

/// Returns `true` if [key] or the leaf [value] itself (not its children)
/// directly matches [query] under [scope] and passes [typeFilter].
///
/// [typeFilter] is empty when no type restriction is active.
bool _directMatch(
  String key,
  dynamic value,
  String query,
  SearchScope scope, {
  Set<String> typeFilter = const {},
}) {
  if (query.isEmpty) return false;
  final q = query.toLowerCase();
  final checkKeys = scope != SearchScope.valuesOnly;
  final checkValues = scope != SearchScope.keysOnly;
  final type = _typeOfValue(value);
  final passesTypeFilter = typeFilter.isEmpty || typeFilter.contains(type);

  if (checkKeys && key.toLowerCase().contains(q) && passesTypeFilter) return true;
  // Only match the value directly (not its children).
  if (checkValues && value is! Map && value is! List && passesTypeFilter) {
    return value.toString().toLowerCase().contains(q);
  }
  return false;
}

/// Recursively collects every JSON path where the node key or leaf value
/// directly matches [query] under [scope], filtered by [typeFilter].
///
/// [prefix] is the JSON-path string for [data] (default `'$'` for the root).
List<String> _collectMatchingPaths(
  dynamic data,
  String query,
  SearchScope scope, {
  String prefix = r'$',
  Set<String> typeFilter = const {},
}) {
  if (query.isEmpty) return const [];
  final results = <String>[];
  if (data is Map<String, dynamic>) {
    for (final entry in data.entries) {
      final childPath = '$prefix.${entry.key}';
      if (_directMatch(entry.key, entry.value, query, scope,
          typeFilter: typeFilter)) {
        results.add(childPath);
      }
      results.addAll(
        _collectMatchingPaths(entry.value, query, scope,
            prefix: childPath, typeFilter: typeFilter),
      );
    }
  } else if (data is List) {
    for (int i = 0; i < data.length; i++) {
      final childPath = '$prefix[$i]';
      if (_directMatch('[$i]', data[i], query, scope,
          typeFilter: typeFilter)) {
        results.add(childPath);
      }
      results.addAll(
        _collectMatchingPaths(data[i], query, scope,
            prefix: childPath, typeFilter: typeFilter),
      );
    }
  }
  return results;
}

// ---------------------------------------------------------------------------

/// Tree view widget for displaying JSON in an expandable/collapsible tree.
class JsonTreeViewWidget extends ConsumerStatefulWidget {
  const JsonTreeViewWidget({super.key});

  @override
  ConsumerState<JsonTreeViewWidget> createState() => _JsonTreeViewWidgetState();
}

class _JsonTreeViewWidgetState extends ConsumerState<JsonTreeViewWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFieldFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  String _searchQuery = '';
  String _selectedPath = '';
  int _expansionGeneration = 0;

  /// `true` = expand all, `false` = collapse all, `null` = use depth setting.
  bool? _forceExpandAll;

  bool _isSearchVisible = false;
  bool _isFilterVisible = false;

  /// When `true`, search results are shown as a flat path list instead of
  /// the filtered tree.
  bool _pathListMode = false;

  SearchScope _searchScope = SearchScope.both;

  /// Types currently hidden. Values: 'object','array','string','number','boolean','null'.
  final Set<String> _hiddenTypes = {};

  // ---- Object filter mode ----

  /// When `true`, the structured key-value filter bar is shown instead of the
  /// plain text search bar.
  bool _isFilterMode = false;

  /// Active filter conditions (AND semantics).
  List<SearchFilter> _filterConditions = [];

  /// When `true`, filter results are displayed as a flat path-list.
  /// Set to `false` after the user clicks a result to switch to tree view.
  /// Resets to `true` whenever [_filterConditions] changes.
  bool _filterShowList = true;

  /// Cached key suggestions built from the current parsed data.
  /// Recomputed whenever [parsedData] changes.
  List<KeySuggestion> _keySuggestions = [];
  String _lastKeySuggestionInput = '';

  // ---- Search enhancements ----

  /// Index of the currently highlighted result in the path-list. -1 = none.
  int _currentResultIndex = -1;

  /// Recently used search queries (newest first, max 10).
  final List<String> _searchHistory = [];

  /// When non-empty, restricts search matches to nodes whose value type is in
  /// this set. Possible values: 'string','number','boolean','null','object','array'.
  Set<String> _searchValueTypeFilter = {};

  /// When `true`, path-list results are restricted to nodes under [_selectedPath].
  bool _searchSubtreeOnly = false;

  // Position mapper for bidirectional editor ↔ tree sync (ROADMAP 2.5).
  JsonPositionMapper? _positionMapper;
  String _lastMappedInput = '';

  /// Key attached to the highlighted node; used by [Scrollable.ensureVisible].
  final GlobalKey _highlightedNodeKey = GlobalKey();

  /// Ancestor paths that must remain expanded so the highlighted node is reachable.
  Set<String> _forcedExpandedPaths = {};

  /// Controls the outer [ListView] inside [LazyJsonTree].
  ///
  /// Used to pre-scroll the list toward the target area before the frame-retry
  /// loop runs, ensuring that virtualised items get built in time.
  final ScrollController _treeScrollController = ScrollController();

  /// Controls the path-results [ListView] shown in path-list search mode.
  final ScrollController _pathListScrollController = ScrollController();

  /// Key attached to the currently selected row in the path-results list.
  /// Used by [Scrollable.ensureVisible] to scroll the list to the active result.
  final GlobalKey _selectedResultKey = GlobalKey();

  /// Returns a cached [JsonPositionMapper] for the current input text.
  JsonPositionMapper? _getMapper() {
    final input = ref.read(inputProvider);
    if (input == _lastMappedInput) return _positionMapper;
    _lastMappedInput = input;
    if (!input.contains('\n') || input.isEmpty) {
      return _positionMapper = null;
    }
    return _positionMapper = JsonPositionMapper.build(input);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFieldFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    _treeScrollController.dispose();
    _pathListScrollController.dispose();
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
    _searchDebounceTimer?.cancel();
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _pathListMode = false;
      _currentResultIndex = -1;
      _searchSubtreeOnly = false;
      _searchValueTypeFilter = {};
    });
  }

  int _searchDebounceMs() {
    final inputSize = ref.read(inputSizeProvider);
    return inputSize > PerformanceConstants.processingIndicatorThreshold
        ? PerformanceConstants.largeInputDebounceMs
        : PerformanceConstants.inputDebounceMs;
  }

  void _applySearchQuery() {
    if (!mounted) return;
    final next = _searchController.text;
    if (next == _searchQuery) return;
    _addToHistory(next);
    setState(() {
      _searchQuery = next;
      _currentResultIndex = 0;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      Duration(milliseconds: _searchDebounceMs()),
      _applySearchQuery,
    );
  }

  // -------------------------------------------------------------------------
  // Filter mode
  // -------------------------------------------------------------------------

  void _toggleFilterMode() {
    setState(() {
      _isFilterMode = !_isFilterMode;
      // Deactivate text search when switching to filter mode.
      if (_isFilterMode && _isSearchVisible) {
        _isSearchVisible = false;
        _clearSearch();
      }
      // Reset to list view whenever the panel is reopened.
      if (_isFilterMode) _filterShowList = true;
      // Conditions are intentionally kept when closing so the badge reflects
      // active filters and they reappear when the panel is reopened.
    });
  }

  /// Returns cached key suggestions, recomputing if the JSON input changed.
  List<KeySuggestion> _getKeySuggestions(dynamic parsedData) {
    final raw = ref.read(inputProvider);
    if (raw == _lastKeySuggestionInput) return _keySuggestions;
    _lastKeySuggestionInput = raw;
    _keySuggestions =
        parsedData != null ? JsonKeyCollector.collect(parsedData) : const [];
    return _keySuggestions;
  }

  void _setSearchScope(SearchScope scope) {
    _searchDebounceTimer?.cancel();
    final next = _searchController.text;
    setState(() {
      _searchScope = scope;
      _searchQuery = next;
      _currentResultIndex = 0;
    });
  }

  // -------------------------------------------------------------------------
  // Search enhancements
  // -------------------------------------------------------------------------

  /// Collects all matching paths with all active filters applied.
  List<String> _filteredPaths(dynamic data) {
    var paths = _collectMatchingPaths(
      data,
      _searchQuery,
      _searchScope,
      typeFilter: _searchValueTypeFilter,
    );
    if (_searchSubtreeOnly && _selectedPath.isNotEmpty) {
      final prefix = _selectedPath;
      paths = paths
          .where(
            (p) =>
                p == prefix ||
                p.startsWith('$prefix.') ||
                p.startsWith('$prefix['),
          )
          .toList();
    }
    return paths;
  }

  void _nextResult(List<String> paths) {
    if (paths.isEmpty) return;
    final next = (_currentResultIndex + 1) % paths.length;
    setState(() => _currentResultIndex = next);
    _updateSelectedPath(paths[next]);
    _scheduleScrollToResult(next, paths.length);
  }

  void _previousResult(List<String> paths) {
    if (paths.isEmpty) return;
    final prev =
        _currentResultIndex <= 0 ? paths.length - 1 : _currentResultIndex - 1;
    setState(() => _currentResultIndex = prev);
    _updateSelectedPath(paths[prev]);
    _scheduleScrollToResult(prev, paths.length);
  }

  /// Scrolls the path-results [ListView] so that the row at [index] is visible.
  ///
  /// Mirrors the retry logic used by [_scheduleScrollToHighlighted]: tries
  /// [Scrollable.ensureVisible] on [_selectedResultKey] first; if the widget
  /// isn't built yet, pre-jumps the list to an estimated offset and retries.
  static const int _maxResultScrollAttempts = 8;

  void _scheduleScrollToResult(int index, int total, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _selectedResultKey.currentContext;
      if (ctx != null) {
        if (_isNodeVisible(ctx)) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      } else if (attempt < _maxResultScrollAttempts) {
        if (attempt == 0) _preScrollPathList(index, total);
        _scheduleScrollToResult(index, total, attempt: attempt + 1);
      }
    });
  }

  /// Jumps [_pathListScrollController] to a proportional estimate of where
  /// [index] sits in the list so nearby items get built by the lazy renderer.
  void _preScrollPathList(int index, int total) {
    if (!_pathListScrollController.hasClients) return;
    final pos = _pathListScrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    final fraction = total > 0 ? index / total : 0.0;
    final target = (fraction * pos.maxScrollExtent).clamp(
      0.0,
      pos.maxScrollExtent,
    );
    _pathListScrollController.jumpTo(target);
  }

  /// Adds [query] to history, deduplicating and capping at 10 entries.
  void _addToHistory(String query) {
    if (query.trim().isEmpty) return;
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > 10) _searchHistory.removeLast();
  }

  Future<void> _copyAllResults(List<String> paths, dynamic data) async {
    final buffer = StringBuffer();
    for (final path in paths) {
      final value = _valueAtPath(data, path);
      buffer.writeln('$path = ${_serializeValueForCopy(value)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${paths.length} result${paths.length == 1 ? '' : 's'} to clipboard',
          style: GoogleFonts.jetBrainsMono(fontSize: AppDimensions.fontSizeS),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _serializeValueForCopy(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  void _toggleValueTypeFilter(String type) {
    setState(() {
      if (_searchValueTypeFilter.contains(type)) {
        _searchValueTypeFilter = Set.from(_searchValueTypeFilter)..remove(type);
      } else {
        _searchValueTypeFilter = Set.from(_searchValueTypeFilter)..add(type);
      }
      _currentResultIndex = 0;
    });
  }

  void _applyHistoryQuery(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.collapsed(offset: query.length);
    _searchDebounceTimer?.cancel();
    _addToHistory(query);
    setState(() {
      _searchQuery = query;
      _currentResultIndex = 0;
    });
  }

  /// Handles key events from the search field Focus widget.
  KeyEventResult _handleSearchKeyEvent(KeyEvent event, List<String> paths) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _toggleSearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _previousResult(paths);
      } else {
        _nextResult(paths);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _searchHint() => switch (_searchScope) {
    SearchScope.keysOnly => 'Search keys...',
    SearchScope.valuesOnly => 'Search values...',
    SearchScope.both => 'Search keys or values...',
  };

  /// Computes all ancestor paths of [path] that need to be force-expanded.
  ///
  /// For `$.users[0].profile.name` returns:
  /// `{'$', '$.users', '$.users[0]', '$.users[0].profile'}`
  Set<String> _ancestorPaths(String path) {
    final segments = JsonPath.breadcrumbTokens(path);
    final ancestors = <String>{};
    for (int i = 0; i < segments.length - 1; i++) {
      ancestors.add(_pathFromSegments(segments, i));
    }
    return ancestors;
  }

  /// Updates [_selectedPath] and [_forcedExpandedPaths], then schedules
  /// a scroll to bring the highlighted node into view.
  void _updateSelectedPath(String path) {
    setState(() {
      _selectedPath = path;
      _forcedExpandedPaths = _ancestorPaths(path);
    });
    _scheduleScrollToHighlighted();
  }

  /// Like [_updateSelectedPath] but also force-expands the target node itself.
  ///
  /// Used when navigating to a node from search/filter results: the clicked
  /// node is typically a container (e.g. `$.apis[0]`) that should open and
  /// reveal its children, not just be highlighted while staying collapsed.
  void _expandAndSelectPath(String path) {
    setState(() {
      _selectedPath = path;
      _forcedExpandedPaths = {..._ancestorPaths(path), path};
    });
    _scheduleScrollToHighlighted();
  }

  /// Calls [Scrollable.ensureVisible] on [_highlightedNodeKey].
  ///
  /// Because the outer [ListView] is lazy, the target widget may not be in the
  /// tree yet.  The method therefore:
  ///   1. Pre-scrolls the outer list to the approximate area of the target so
  ///      that Flutter builds the relevant subtree.
  ///   2. Retries up to [_maxScrollAttempts] post-frame callbacks, stopping as
  ///      soon as the key's context becomes available.
  static const int _maxScrollAttempts = 10;

  /// Returns `true` if the render object for [ctx] is fully visible inside
  /// the nearest [Scrollable] ancestor's viewport.
  bool _isNodeVisible(BuildContext ctx) {
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return false;
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return false;
    final scrollRO = scrollable.context.findRenderObject();
    if (scrollRO is! RenderBox) return false;
    final itemPos = ro.localToGlobal(Offset.zero, ancestor: scrollRO);
    final viewportHeight = scrollRO.size.height;
    return itemPos.dy >= 0 && itemPos.dy + ro.size.height <= viewportHeight;
  }

  void _scheduleScrollToHighlighted({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _highlightedNodeKey.currentContext;
      if (ctx != null) {
        // Skip scrolling if the node is already fully visible in the viewport.
        if (_isNodeVisible(ctx)) return;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      } else if (attempt < _maxScrollAttempts) {
        // Node not yet built — nudge the outer ListView toward the target area
        // so the lazy virtualiser renders the relevant items, then retry.
        if (attempt == 0) _preScrollToTarget();
        _scheduleScrollToHighlighted(attempt: attempt + 1);
      }
    });
  }

  /// Jumps the outer [ListView] to a proportional position estimated from
  /// the root-level index of [_selectedPath].
  ///
  /// This causes the lazy virtualiser to build items near the target, so
  /// subsequent [Scrollable.ensureVisible] calls can find the key.
  void _preScrollToTarget() {
    if (!_treeScrollController.hasClients) return;
    final pos = _treeScrollController.position;
    if (pos.maxScrollExtent <= 0) return;

    final parsedData = ref.read(parsedDataProvider);
    if (parsedData == null) return;

    final fraction = _estimateRootFraction(_selectedPath, parsedData);
    final target = (fraction * pos.maxScrollExtent).clamp(
      0.0,
      pos.maxScrollExtent,
    );
    _treeScrollController.jumpTo(target);
  }

  /// Returns a [0, 1] fraction representing roughly where the root ancestor
  /// of [path] sits inside the root-level collection.
  ///
  /// For arrays: extracts the first `[N]` index and divides by list length.
  /// For objects: finds the position of the root key in the key list.
  double _estimateRootFraction(String path, dynamic data) {
    final tokens = JsonPath.breadcrumbTokens(path);
    if (tokens.length < 2) return 0.0;

    final root = tokens[1];
    if (data is List && data.isNotEmpty) {
      if (root.startsWith('[') && root.endsWith(']')) {
        final idx = int.tryParse(root.substring(1, root.length - 1));
        if (idx != null) return idx / data.length;
      }
    } else if (data is Map<String, dynamic> && data.isNotEmpty) {
      if (!root.startsWith('[')) {
        final keys = data.keys.toList();
        final idx = keys.indexOf(root);
        if (idx >= 0) return idx / keys.length;
      }
    }
    return 0.0;
  }

  // -------------------------------------------------------------------------
  // Inline edit application
  // -------------------------------------------------------------------------

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

  Future<void> _commitDataChange(dynamic data) async {
    await ref.read(jsonAnalyzerProvider.notifier).updateFromParsedData(data);
  }

  /// Creates a deep copy of [data] via a JSON round-trip.
  ///
  /// Used to avoid mutating the object currently held in Riverpod state in-place
  /// before [_commitDataChange] succeeds.
  static dynamic _deepCopy(dynamic data) => jsonDecode(jsonEncode(data));

  /// Called by [LazyJsonTree] when a leaf value is edited inline.
  ///
  /// Navigates the current parsed data to the node at [path], updates it,
  /// re-serialises to formatted JSON, and pushes the change to the provider.
  Future<void> _applyEdit(String path, dynamic newValue) async {
    final parsedData = ref.read(parsedDataProvider);
    if (parsedData == null) return;

    final copy = _deepCopy(parsedData);
    final segments = JsonPath.toSegments(path);
    final ok = _setAtPath(copy, segments, newValue);
    if (!ok) return;

    await _commitDataChange(copy);
  }

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
    final copy = _deepCopy(parsedData);
    final segments = JsonPath.toSegments(path);

    switch (action) {
      case TreeNodeAction.delete:
        await _deleteNode(copy, segments);
        break;
      case TreeNodeAction.addKey:
        await _addKey(copy, segments);
        break;
      case TreeNodeAction.addItem:
        await _addItem(copy, segments);
        break;
      case TreeNodeAction.duplicate:
        await _duplicateNode(copy, segments);
        break;
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

    await _commitDataChange(data);
  }

  Future<void> _addKey(dynamic data, List<Object> segments) async {
    final node = _nodeAtSegments(data, segments);
    if (node is! Map<String, dynamic>) return;

    final keyName = await showDialog<String>(
      context: context,
      builder: (_) => const AddKeyDialog(),
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

    await _commitDataChange(data);
  }

  Future<void> _addItem(dynamic data, List<Object> segments) async {
    final node = _nodeAtSegments(data, segments);
    if (node is! List) return;

    node.add(null);

    await _commitDataChange(data);
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

    await _commitDataChange(data);
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

    // Editor → Tree: highlight the node corresponding to the editor cursor.
    ref.listen<int>(editorCursorLineProvider, (prev, next) {
      if (next < 0) return;
      final path = _getMapper()?.pathForLine(next);
      if (path != null && path != _selectedPath) {
        _updateSelectedPath(path);
      }
    });

    // Always compute filtered paths when search is active so navigation
    // and the counter work in both tree mode and path-list mode.
    final List<String> searchPaths =
        (_isSearchVisible && _searchQuery.isNotEmpty && parsedData != null)
        ? _filteredPaths(parsedData)
        : const [];

    // In path-list mode the results replace the tree view.
    final List<String>? pathResults = _pathListMode ? searchPaths : null;

    // Object filter results — shown as path-list only while _filterShowList
    // is true. Clicking a result sets _filterShowList=false to switch to tree.
    final List<String>? filterResults =
        (_isFilterMode &&
            _filterShowList &&
            _filterConditions.isNotEmpty &&
            parsedData != null)
        ? JsonObjectFilter.findMatching(parsedData, _filterConditions)
        : null;

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.keyF &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          if (!_isSearchVisible) {
            _toggleSearch();
          } else {
            _searchFieldFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, filterResultCount: filterResults?.length),
            if (_isSearchVisible)
              _buildSearchBar(searchPaths: searchPaths, parsedData: parsedData),
            if (_isFilterMode)
              JsonFilterBar(
                keySuggestions: _getKeySuggestions(parsedData),
                filters: _filterConditions,
                showList: _filterShowList,
                onFiltersChanged: (f) => setState(() {
                  _filterConditions = f;
                  _filterShowList = true; // reset to list when conditions change
                }),
                onToggleView: () =>
                    setState(() => _filterShowList = !_filterShowList),
              ),
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
                    pathResults: filterResults ?? pathResults,
                  ),
                  if (isProcessing)
                    const ProcessingOverlay(
                      message: 'Processing large JSON...',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, {int? filterResultCount}) {
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
          _buildObjectFilterButton(resultCount: filterResultCount),
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

  Widget _buildObjectFilterButton({int? resultCount}) {
    final active = _isFilterMode;
    // Show result count when available; fall back to conditions count so the
    // badge is always visible whenever conditions are active.
    final badgeCount = resultCount ?? _filterConditions.length;
    final showBadge = _filterConditions.isNotEmpty;
    return IconButton(
      tooltip: active ? 'Close object filter' : 'Filter by key-value conditions',
      icon: Badge(
        isLabelVisible: showBadge,
        label: Text('$badgeCount'),
        backgroundColor: AppColors.primary,
        child: Icon(
          Icons.manage_search,
          size: AppDimensions.iconSizeS,
          color: active ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      onPressed: _toggleFilterMode,
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

  Widget _buildSearchBar({
    required List<String> searchPaths,
    required dynamic parsedData,
  }) {
    final hasResults = searchPaths.isNotEmpty;
    final safeIndex = hasResults
        ? _currentResultIndex.clamp(0, searchPaths.length - 1)
        : -1;

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: search input + nav controls.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: Focus(
              onKeyEvent: (node, event) =>
                  _handleSearchKeyEvent(event, searchPaths),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                      focusNode: _searchFieldFocusNode,
                      autofocus: true,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: _searchHint(),
                        hintStyle: GoogleFonts.jetBrainsMono(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "X of Y" counter + ↑↓ navigation.
                  if (hasResults) ...[
                    Text(
                      '${safeIndex + 1} of ${searchPaths.length}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    _SearchIconBtn(
                      icon: Icons.keyboard_arrow_up,
                      tooltip: 'Previous result  (Shift+Enter)',
                      onTap: () => _previousResult(searchPaths),
                      active: false,
                    ),
                    _SearchIconBtn(
                      icon: Icons.keyboard_arrow_down,
                      tooltip: 'Next result  (Enter)',
                      onTap: () => _nextResult(searchPaths),
                      active: false,
                    ),
                    const SizedBox(width: 2),
                    // Copy all results to clipboard.
                    _SearchIconBtn(
                      icon: Icons.content_copy,
                      tooltip: 'Copy all ${searchPaths.length} result paths',
                      onTap: () => _copyAllResults(searchPaths, parsedData),
                      active: false,
                    ),
                    const SizedBox(width: 2),
                  ],
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      final hasText = value.text.isNotEmpty;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasText) ...[
                            _SearchIconBtn(
                              icon: Icons.close,
                              tooltip: 'Clear  (Esc)',
                              onTap: _clearSearch,
                              active: false,
                            ),
                            const SizedBox(width: 2),
                          ],
                          Container(
                            width: 1,
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: AppColors.border,
                          ),
                          _SearchIconBtn(
                            icon: _pathListMode
                                ? Icons.account_tree
                                : Icons.format_list_bulleted,
                            tooltip: _pathListMode
                                ? 'Show tree view'
                                : 'Show results as path list',
                            onTap: () {
                              _searchDebounceTimer?.cancel();
                              final next = _searchController.text;
                              setState(() {
                                _pathListMode = !_pathListMode;
                                _searchQuery = next;
                              });
                            },
                            active: _pathListMode,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Row 2: scope chips + subtree toggle.
          Padding(
            padding: const EdgeInsets.only(
              left: AppDimensions.paddingM,
              right: AppDimensions.paddingM,
              bottom: AppDimensions.paddingS,
            ),
            child: Row(
              children: [
                _buildScopeSelector(),
                const Spacer(),
                if (_selectedPath.isNotEmpty)
                  _ScopeChip(
                    label: 'Subtree',
                    icon: Icons.account_tree_outlined,
                    selected: _searchSubtreeOnly,
                    onSelected: () => setState(() {
                      _searchSubtreeOnly = !_searchSubtreeOnly;
                      _currentResultIndex = 0;
                    }),
                  ),
              ],
            ),
          ),
          // Row 3: value-type filter chips (shown when a query is active).
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.paddingM,
                right: AppDimensions.paddingM,
                bottom: AppDimensions.paddingS,
              ),
              child: _buildTypeFilterRow(),
            ),
          // Row 4: recent search history (shown when field is empty).
          if (_searchQuery.isEmpty && _searchHistory.isNotEmpty)
            _buildHistorySection(),
        ],
      ),
    );
  }

  Widget _buildScopeSelector() {
    return Row(
      children: [
        _ScopeChip(
          label: 'Keys',
          icon: Icons.vpn_key_outlined,
          selected: _searchScope == SearchScope.keysOnly,
          onSelected: () => _setSearchScope(SearchScope.keysOnly),
        ),
        const SizedBox(width: 6),
        _ScopeChip(
          label: 'Both',
          icon: Icons.manage_search,
          selected: _searchScope == SearchScope.both,
          onSelected: () => _setSearchScope(SearchScope.both),
        ),
        const SizedBox(width: 6),
        _ScopeChip(
          label: 'Values',
          icon: Icons.text_fields,
          selected: _searchScope == SearchScope.valuesOnly,
          onSelected: () => _setSearchScope(SearchScope.valuesOnly),
        ),
      ],
    );
  }

  /// Row of chips to restrict search matches to specific value types.
  Widget _buildTypeFilterRow() {
    return Row(
      children: [
        Text(
          'Type:',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Wrap(
          spacing: 4,
          children: [
            _typeFilterChip('Str', 'string', AppColors.jsonString),
            _typeFilterChip('Num', 'number', AppColors.jsonNumber),
            _typeFilterChip('Bool', 'boolean', AppColors.jsonBoolean),
            _typeFilterChip('Null', 'null', AppColors.jsonNull),
            _typeFilterChip('Obj', 'object', AppColors.jsonBracket),
            _typeFilterChip('Arr', 'array', AppColors.jsonBracket),
          ],
        ),
      ],
    );
  }

  Widget _typeFilterChip(String label, String type, Color color) {
    final active = _searchValueTypeFilter.contains(type);
    return GestureDetector(
      onTap: () => _toggleValueTypeFilter(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: active ? color : AppColors.textMuted,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Recent-query history shown below the search field when the query is empty.
  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        bottom: AppDimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _searchHistory
                .map(
                  (q) => GestureDetector(
                    onTap: () => _applyHistoryQuery(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusS),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        q,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Filter bar (2.4)
  // -------------------------------------------------------------------------

  void _toggleTypeFilter(String type) {
    setState(() {
      if (_hiddenTypes.contains(type)) {
        _hiddenTypes.remove(type);
      } else {
        _hiddenTypes.add(type);
      }
    });
  }

  void _resetTypeFilters() => setState(() => _hiddenTypes.clear());

  Color _typeColor(String type) => switch (type) {
    'object' || 'array' => AppColors.jsonBracket,
    'string' => AppColors.jsonString,
    'number' => AppColors.jsonNumber,
    'boolean' => AppColors.jsonBoolean,
    _ => AppColors.jsonNull,
  };

  Widget _buildFilterBar() {
    return TypeFilterBar(
      hiddenTypes: _hiddenTypes,
      typeColor: _typeColor,
      onToggleType: _toggleTypeFilter,
      onReset: _resetTypeFilters,
    );
  }

  // -------------------------------------------------------------------------
  // Breadcrumb bar
  // -------------------------------------------------------------------------

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
    return BreadcrumbBar(
      selectedPath: _selectedPath,
      buildPath: _pathFromSegments,
      onPathSelected: _updateSelectedPath,
    );
  }

  // -------------------------------------------------------------------------
  // Content
  // -------------------------------------------------------------------------

  Widget _buildContent({
    required dynamic parsedData,
    required bool isValid,
    required bool isEmpty,
    List<String>? pathResults,
  }) {
    if (isEmpty || !isValid || parsedData == null) {
      return _buildPlaceholder();
    }
    if (pathResults != null) {
      return _buildSearchResultsList(pathResults, parsedData);
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

  // -------------------------------------------------------------------------
  // Path-list search results
  // -------------------------------------------------------------------------

  /// Returns the value at [path] by navigating [data].
  dynamic _valueAtPath(dynamic data, String path) {
    return _nodeAtSegments(data, JsonPath.toSegments(path));
  }

  /// Compact string representation of [value] for the results list.
  String _valuePreview(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      final truncated = value.length > 60
          ? '${value.substring(0, 60)}\u2026'
          : value;
      return '"$truncated"';
    }
    if (value is Map) {
      final n = value.length;
      return '{$n ${n == 1 ? 'key' : 'keys'}}';
    }
    if (value is List) {
      final n = value.length;
      return '[$n ${n == 1 ? 'item' : 'items'}]';
    }
    return value.toString();
  }

  /// Color that represents the type of [value].
  Color _typeColorForValue(dynamic value) {
    if (value == null) return AppColors.jsonNull;
    if (value is String) return AppColors.jsonString;
    if (value is num) return AppColors.jsonNumber;
    if (value is bool) return AppColors.jsonBoolean;
    return AppColors.jsonBracket; // Map / List
  }

  /// Builds a scrollable list of matching [paths] with value previews.
  Widget _buildSearchResultsList(List<String> paths, dynamic data) {
    if (paths.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 32, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              'No matches for "$_searchQuery"',
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final safeIndex =
        paths.isEmpty ? -1 : _currentResultIndex.clamp(0, paths.length - 1);

    return ListView.builder(
      controller: _pathListScrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        final value = _valueAtPath(data, path);
        final isSelected = index == safeIndex;
        return _buildPathResultItem(path, value, isSelected, index);
      },
    );
  }

  /// Single row in the path results list.
  ///
  /// Tapping switches to tree view and scrolls to the matching node.
  Widget _buildPathResultItem(
    String path,
    dynamic value,
    bool isSelected,
    int index,
  ) {
    return InkWell(
      onTap: () {
        // Switch to tree view, expand the target node, and scroll to it.
        setState(() {
          _currentResultIndex = index;
          _pathListMode = false;
          _filterShowList = false; // hide filter path-list, show tree
        });
        _expandAndSelectPath(path);
        final line = _getMapper()?.lineForPath(path);
        if (line != null) {
          ref.read(treeSelectedPathProvider.notifier).state = path;
        }
      },
      child: AnimatedContainer(
        key: isSelected ? _selectedResultKey : null,
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right,
                size: 14,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: AppDimensions.fontSizeS,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _valuePreview(value),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: _typeColorForValue(value),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
      searchScope: _searchScope,
      expansionGeneration: _expansionGeneration,
      forceExpandAll: _forceExpandAll,
      sortKeys: settings.sortKeys,
      hiddenTypes: _hiddenTypes,
      highlightedPath: _selectedPath,
      forcedExpandedPaths: _forcedExpandedPaths,
      highlightedNodeKey: _highlightedNodeKey,
      scrollController: _treeScrollController,
      onPathSelected: (path) {
        _updateSelectedPath(path);
        // Tree → Editor: scroll editor to the matching line.
        final line = _getMapper()?.lineForPath(path);
        if (line != null) {
          ref.read(treeSelectedPathProvider.notifier).state = path;
        }
      },
      onValueChanged: _applyEdit,
      onNodeAction: _applyNodeAction,
    );
  }
}
