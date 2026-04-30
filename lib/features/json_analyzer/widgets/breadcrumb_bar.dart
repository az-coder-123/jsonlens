import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/json_path.dart';

class BreadcrumbBar extends StatelessWidget {
  final String selectedPath;
  final String Function(List<String> segments, int upTo) buildPath;
  final ValueChanged<String> onPathSelected;

  const BreadcrumbBar({
    super.key,
    required this.selectedPath,
    required this.buildPath,
    required this.onPathSelected,
  });

  @override
  Widget build(BuildContext context) {
    final segments = JsonPath.breadcrumbTokens(selectedPath);

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
                      onTap: () => onPathSelected(buildPath(segments, i)),
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
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: selectedPath));
              if (!context.mounted) return;
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
}

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
