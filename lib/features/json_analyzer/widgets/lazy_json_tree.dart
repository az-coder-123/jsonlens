import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import 'container_node_header.dart';
import 'inline_editor.dart';
import 'leaf_node_content.dart';
import 'node_children.dart';

part '_context_menu_item.dart';
part '_lazy_node.dart';

// ---------------------------------------------------------------------------
// Node action enum
// ---------------------------------------------------------------------------

/// Actions available in the tree node right-click / long-press context menu.
enum TreeNodeAction { addKey, addItem, delete, duplicate }

// ---------------------------------------------------------------------------
// Search scope
// ---------------------------------------------------------------------------

/// Which parts of each JSON node are matched during tree search.
enum SearchScope {
  /// Match against both keys and values (default).
  both,

  /// Match only against node keys.
  keysOnly,

  /// Match only against leaf values.
  valuesOnly,
}

// ---------------------------------------------------------------------------
// Search helpers
// ---------------------------------------------------------------------------

/// Returns true if [key] or [value] (recursively) matches [query] under [scope].
bool _matchesSearch(
  String key,
  dynamic value,
  String query, [
  SearchScope scope = SearchScope.both,
]) {
  if (query.isEmpty) return false;
  final q = query.toLowerCase();
  final checkKeys = scope != SearchScope.valuesOnly;
  final checkValues = scope != SearchScope.keysOnly;
  if (checkKeys && key.toLowerCase().contains(q)) return true;
  if (value is Map<String, dynamic>) {
    return value.entries.any((e) => _matchesSearch(e.key, e.value, q, scope));
  }
  if (value is List) {
    for (int i = 0; i < value.length; i++) {
      if (_matchesSearch('[$i]', value[i], q, scope)) return true;
    }
    return false;
  }
  if (checkValues) return value.toString().toLowerCase().contains(q);
  return false;
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
// Type helper
// ---------------------------------------------------------------------------

/// Returns the canonical type name for [v], used by the type-filter feature.
///
/// Possible return values: `'object'`, `'array'`, `'string'`, `'number'`,
/// `'boolean'`, `'null'`.
String _typeOf(dynamic v) {
  if (v == null) return 'null';
  if (v is Map) return 'object';
  if (v is List) return 'array';
  if (v is bool) return 'boolean'; // must precede num check
  if (v is num) return 'number';
  return 'string';
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

  /// Set of type names whose nodes should be hidden.
  ///
  /// Possible values: `'object'`, `'array'`, `'string'`, `'number'`,
  /// `'boolean'`, `'null'`. An empty set means all types are visible.
  final Set<String> hiddenTypes;

  /// JSON path of the node to visually highlight (editor ↔ tree sync).
  ///
  /// When non-null and matching a node's own path, that node row is tinted
  /// with a subtle primary-colour background.
  final String? highlightedPath;

  /// Paths that must be force-expanded regardless of depth setting.
  ///
  /// Used during editor→tree sync to auto-open all ancestors of the
  /// highlighted node so that [Scrollable.ensureVisible] can reach it.
  final Set<String> forcedExpandedPaths;

  /// GlobalKey attached to the currently highlighted node's container so that
  /// [Scrollable.ensureVisible] can scroll to it.
  final GlobalKey? highlightedNodeKey;

  /// Optional controller for the root-level [ListView].
  ///
  /// Pass this from the parent so that the parent can pre-scroll the outer
  /// list (which uses lazy rendering) before [Scrollable.ensureVisible] is
  /// called on the highlighted node's key.
  final ScrollController? scrollController;

  /// Which parts of each node (keys, values, or both) to match during search.
  final SearchScope searchScope;

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
    this.hiddenTypes = const {},
    this.highlightedPath,
    this.forcedExpandedPaths = const {},
    this.highlightedNodeKey,
    this.scrollController,
    this.searchScope = SearchScope.both,
  });

  @override
  Widget build(BuildContext context) {
    if (data is List) {
      final list = data as List;
      return ListView.builder(
        controller: scrollController,
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
          searchScope: searchScope,
          expansionGeneration: expansionGeneration,
          forceExpandAll: forceExpandAll,
          sortKeys: sortKeys,
          onPathSelected: onPathSelected,
          onValueChanged: onValueChanged,
          onNodeAction: onNodeAction,
          hiddenTypes: hiddenTypes,
          highlightedPath: highlightedPath,
          forcedExpandedPaths: forcedExpandedPaths,
          highlightedNodeKey: highlightedNodeKey,
        ),
      );
    }

    final Map<String, dynamic> root = data is Map<String, dynamic>
        ? data as Map<String, dynamic>
        : <String, dynamic>{'root': data};
    var entries = root.entries.toList();
    if (sortKeys) entries.sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      controller: scrollController,
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
          searchScope: searchScope,
          expansionGeneration: expansionGeneration,
          forceExpandAll: forceExpandAll,
          sortKeys: sortKeys,
          onPathSelected: onPathSelected,
          onValueChanged: onValueChanged,
          onNodeAction: onNodeAction,
          hiddenTypes: hiddenTypes,
          highlightedPath: highlightedPath,
          forcedExpandedPaths: forcedExpandedPaths,
          highlightedNodeKey: highlightedNodeKey,
        );
      },
    );
  }
}
