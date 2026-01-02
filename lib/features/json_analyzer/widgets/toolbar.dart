import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/clipboard_helper.dart';
import '../../../core/utils/file_helper.dart';
import '../providers/json_analyzer_provider.dart';

/// Toolbar widget with action buttons for JSON operations.
///
/// Provides buttons for Format, Minify, Clear, Copy, and Paste operations.
class Toolbar extends ConsumerWidget {
  /// Callback for showing feedback messages.
  final void Function(String message) onShowMessage;

  const Toolbar({super.key, required this.onShowMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = ref.watch(isValidProvider);
    final isEmpty = ref.watch(isEmptyProvider);
    final output = ref.watch(outputProvider);

    return Container(
      height: AppDimensions.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.format_align_left,
            label: AppStrings.format,
            onPressed: isValid && !isEmpty
                ? () async => await _handleFormat(ref)
                : null,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          _ToolbarButton(
            icon: Icons.compress,
            label: AppStrings.minify,
            onPressed: isValid && !isEmpty
                ? () async => await _handleMinify(ref)
                : null,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          const Spacer(),

          // File group: Open, Save
          _ToolbarButton(
            icon: Icons.folder_open,
            label: AppStrings.open,
            onPressed: () async => await _handleOpen(ref),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          _ToolbarButton(
            icon: Icons.save,
            label: AppStrings.save,
            onPressed: isValid && output.isNotEmpty
                ? () async => await _handleSave(output)
                : null,
          ),
          const SizedBox(width: AppDimensions.paddingM),
          SizedBox(
            height: 24,
            child: VerticalDivider(color: AppColors.border, thickness: 1),
          ),
          const SizedBox(width: AppDimensions.paddingM),

          // Edit group: Paste, Clear
          FutureBuilder<bool>(
            future: ClipboardHelper.hasText(),
            builder: (context, snapshot) {
              final hasText = snapshot.data ?? false;
              return _ToolbarButton(
                icon: Icons.content_paste,
                label: AppStrings.paste,
                onPressed: hasText ? () => _handlePaste(ref) : null,
              );
            },
          ),
          const SizedBox(width: AppDimensions.paddingS),
          _ToolbarButton(
            icon: Icons.clear_all,
            label: AppStrings.clear,
            onPressed: !isEmpty ? () => _handleClear(ref) : null,
          ),
          const SizedBox(width: AppDimensions.paddingM),
          SizedBox(
            height: 24,
            child: VerticalDivider(color: AppColors.border, thickness: 1),
          ),
          const SizedBox(width: AppDimensions.paddingM),

          // Export group: Copy
          _ToolbarButton(
            icon: Icons.content_copy,
            label: AppStrings.copy,
            onPressed: isValid && output.isNotEmpty
                ? () => _handleCopy(output)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleFormat(WidgetRef ref) async {
    await ref.read(jsonAnalyzerProvider.notifier).format();
    onShowMessage(AppStrings.formatted);
  }

  Future<void> _handleMinify(WidgetRef ref) async {
    await ref.read(jsonAnalyzerProvider.notifier).minify();
    onShowMessage(AppStrings.minified);
  }

  void _handleClear(WidgetRef ref) {
    ref.read(jsonAnalyzerProvider.notifier).clear();
    onShowMessage(AppStrings.cleared);
  }

  Future<void> _handlePaste(WidgetRef ref) async {
    final text = await ClipboardHelper.paste();
    if (text != null && text.isNotEmpty) {
      ref.read(jsonAnalyzerProvider.notifier).pasteFromClipboard(text);
      onShowMessage(AppStrings.pastedFromClipboard);
    } else {
      onShowMessage(AppStrings.clipboardEmpty);
    }
  }

  Future<void> _handleCopy(String output) async {
    final success = await ClipboardHelper.copy(output);
    if (success) {
      onShowMessage(AppStrings.copiedToClipboard);
    }
  }

  Future<void> _handleSave(String output) async {
    // Suggest a sensible filename
    final suggested = 'data.json';
    final outcome = await FileHelper.saveTextFile(
      suggestedName: suggested,
      contents: output,
    );

    switch (outcome.status) {
      case SaveStatus.saved:
        // If we have a path (fallback or explicit), include it in the feedback
        if (outcome.path != null) {
          onShowMessage('${AppStrings.savedToFile}: ${outcome.path}');
        } else {
          onShowMessage(AppStrings.savedToFile);
        }
        break;
      case SaveStatus.cancelled:
        onShowMessage(AppStrings.saveCancelled);
        break;
      case SaveStatus.failed:
        onShowMessage(AppStrings.saveFailed);
        break;
    }
  }

  Future<void> _handleOpen(WidgetRef ref) async {
    final outcome = await FileHelper.openTextFile();

    switch (outcome.status) {
      case OpenStatus.opened:
        // If successful, push content into provider to update input
        if (outcome.contents != null) {
          await ref
              .read(jsonAnalyzerProvider.notifier)
              .updateInput(outcome.contents!);
          if (outcome.path != null) {
            onShowMessage('${AppStrings.loadedFromFile}: ${outcome.path}');
          } else {
            onShowMessage(AppStrings.loadedFromFile);
          }
        }
        break;
      case OpenStatus.cancelled:
        onShowMessage(AppStrings.loadCancelled);
        break;
      case OpenStatus.failed:
        onShowMessage(AppStrings.loadFailed);
        break;
    }
  }
}

/// Individual toolbar button widget.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: AppDimensions.iconSizeS,
          color: isEnabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isEnabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          side: BorderSide(
            color: isEnabled
                ? AppColors.border
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
