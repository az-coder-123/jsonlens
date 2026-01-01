import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_dimensions.dart';

class DepthDialog extends StatefulWidget {
  final int initial;
  const DepthDialog({super.key, required this.initial});

  @override
  State<DepthDialog> createState() => _DepthDialogState();
}

class _DepthDialogState extends State<DepthDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tree settings', style: GoogleFonts.jetBrainsMono()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Default expanded depth', style: GoogleFonts.jetBrainsMono()),
          const SizedBox(height: AppDimensions.paddingS),
          DropdownButton<int>(
            value: _value,
            items: List.generate(7, (i) => i)
                .map(
                  (i) => DropdownMenuItem(value: i, child: Text(i.toString())),
                )
                .toList(),
            onChanged: (v) => setState(() => _value = v ?? _value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.jetBrainsMono()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text('Save', style: GoogleFonts.jetBrainsMono()),
        ),
      ],
    );
  }
}
