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

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
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
      onPathSelected: (path) => setState(() => _selectedPath = path),
    );
  }
}

// ---------------------------------------------------------------------------
// Breadcrumb segment widget
// ---------------------------------------------------------------------------

/// A single clickable segment in the breadcrumb navigation bar.
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
