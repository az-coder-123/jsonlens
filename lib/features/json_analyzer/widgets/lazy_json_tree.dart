import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// A lazy JSON tree widget that only builds children when a node is expanded.
///
/// This reduces initial rendering cost for large JSON documents. It supports
/// specifying `defaultExpandedDepth` so nodes are expanded up to that depth
/// automatically on first build.
class LazyJsonTree extends StatelessWidget {
  final dynamic data;
  final int defaultExpandedDepth;

  const LazyJsonTree({
    super.key,
    required this.data,
    this.defaultExpandedDepth = 1,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure we use a concrete Map type so downstream map() returns List<Widget>
    final Map<String, dynamic> root = data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{'root': data};

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: root.entries.map((MapEntry<String, dynamic> e) {
        return _LazyNode(
          keyName: e.key,
          value: e.value,
          depth: 0,
          defaultExpandedDepth: defaultExpandedDepth,
        );
      }).toList(),
    );
  }
}

class _LazyNode extends StatefulWidget {
  final String keyName;
  final dynamic value;
  final int depth;
  final int defaultExpandedDepth;

  const _LazyNode({
    required this.keyName,
    required this.value,
    required this.depth,
    required this.defaultExpandedDepth,
  });

  @override
  State<_LazyNode> createState() => _LazyNodeState();
}

class _LazyNodeState extends State<_LazyNode> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.depth < widget.defaultExpandedDepth;
  }

  Widget _buildValuePreview() {
    if (widget.value is Map) {
      return Text('{...}', style: _valueStyle());
    } else if (widget.value is List) {
      return Text('[...]', style: _valueStyle());
    } else {
      return Text(_formatScalar(widget.value), style: _valueStyle());
    }
  }

  TextStyle _keyStyle() => GoogleFonts.jetBrainsMono(
    color: AppColors.jsonKey,
    fontSize: AppDimensions.fontSizeM,
  );

  TextStyle _valueStyle() => GoogleFonts.jetBrainsMono(
    color: AppColors.jsonString,
    fontSize: AppDimensions.fontSizeM,
  );

  String _formatScalar(dynamic v) {
    if (v == null) return 'null';
    if (v is String) {
      return '"${v.length > 80 ? '${v.substring(0, 80)}...' : v}"';
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isContainer = widget.value is Map || widget.value is List;

    if (!isContainer) {
      return Padding(
        padding: EdgeInsets.only(left: widget.depth * 12.0, top: 4, bottom: 4),
        child: Row(
          children: [
            Text('${widget.keyName}: ', style: _keyStyle()),
            _buildValuePreview(),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 12.0, top: 4, bottom: 4),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) async {
          if (v) {
            final sw = Stopwatch()..start();
            setState(() => _expanded = true);
            // Allow a frame to build children then measure
            await Future.delayed(Duration(milliseconds: 1));
            sw.stop();
            // Log expansion cost for profiling (visible in console)
            // ignore: avoid_print
            print(
              'Expanded node ${widget.keyName} at depth ${widget.depth} in ${sw.elapsedMilliseconds} ms',
            );
          } else {
            setState(() => _expanded = false);
          }
        },
        title: Row(
          children: [
            Text('${widget.keyName}: ', style: _keyStyle()),
            _buildValuePreview(),
          ],
        ),
        children: [_buildChildrenWidget()],
      ),
    );
  }

  /// Builds children either eagerly (when small) or with a lazy builder
  /// when the number of children exceeds the virtualization threshold.
  Widget _buildChildrenWidget() {
    final v = widget.value;

    // Helper to detect number of children
    int childCount() {
      if (v is Map<String, dynamic>) return v.length;
      if (v is List) return v.length;
      return 0;
    }

    final count = childCount();
    const virtualizationThreshold = 64; // tune this as needed

    // If no container children, return empty
    if (count == 0) return const SizedBox.shrink();

    // If below threshold, build eagerly (keeps layout simple)
    if (count <= virtualizationThreshold) {
      if (v is Map<String, dynamic>) {
        final entries = (v).entries.toList();
        return Column(
          children: entries
              .map(
                (e) => _LazyNode(
                  keyName: e.key,
                  value: e.value,
                  depth: widget.depth + 1,
                  defaultExpandedDepth: widget.defaultExpandedDepth,
                ),
              )
              .toList(),
        );
      }

      if (v is List) {
        final list = v;
        return Column(
          children: List.generate(
            list.length,
            (i) => _LazyNode(
              keyName: '[$i]',
              value: list[i],
              depth: widget.depth + 1,
              defaultExpandedDepth: widget.defaultExpandedDepth,
            ),
          ),
        );
      }
    }

    // For large child lists, use a builder to virtualize child creation.
    if (v is Map<String, dynamic>) {
      final entries = v.entries.toList();
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          return _LazyNode(
            keyName: e.key,
            value: e.value,
            depth: widget.depth + 1,
            defaultExpandedDepth: widget.defaultExpandedDepth,
          );
        },
      );
    }

    if (v is List) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: v.length,
        itemBuilder: (context, index) {
          return _LazyNode(
            keyName: '[$index]',
            value: v[index],
            depth: widget.depth + 1,
            defaultExpandedDepth: widget.defaultExpandedDepth,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
