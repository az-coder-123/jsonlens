import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/http_request_entry.dart';
import '../providers/http_request_history_provider.dart';

/// Returns the display color associated with an HTTP [method] verb.
Color httpMethodColor(String method) => switch (method.toUpperCase()) {
  'GET' => const Color(0xFF61AFEF),
  'POST' => const Color(0xFF98C379),
  'PUT' => const Color(0xFFE5C07B),
  'PATCH' => const Color(0xFFE5C07B),
  'DELETE' => const Color(0xFFE06C75),
  'HEAD' => const Color(0xFF56B6C2),
  _ => const Color(0xFFABB2BF),
};

/// Panel displaying recent and saved HTTP requests.
///
/// Calls [onRestoreEntry] when the user taps a row to load it into the dialog.
class HttpHistoryPanel extends ConsumerWidget {
  /// Called when the user selects a history / saved entry to restore.
  final void Function(HttpRequestEntry entry) onRestoreEntry;

  const HttpHistoryPanel({super.key, required this.onRestoreEntry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histState = ref.watch(httpRequestHistoryProvider);
    final hasContent =
        histState.history.isNotEmpty || histState.saved.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(ref, histState),
        if (!hasContent)
          _buildEmpty()
        else ...[
          if (histState.saved.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingXS),
            _buildGroup(context, ref, 'Saved', histState.saved, isSaved: true),
          ],
          if (histState.history.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingXS),
            _buildGroup(
              context,
              ref,
              'Recent',
              histState.history,
              isSaved: false,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildHeader(WidgetRef ref, HttpRequestHistoryState histState) {
    return Row(
      children: [
        const Icon(
          Icons.history,
          size: AppDimensions.iconSizeS,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppDimensions.paddingXS),
        const Text(
          'History & Saved',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppDimensions.fontSizeS,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (histState.history.isNotEmpty)
          TextButton(
            onPressed: () async {
              await ref
                  .read(httpRequestHistoryProvider.notifier)
                  .clearHistory();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              'Clear history',
              style: TextStyle(fontSize: AppDimensions.fontSizeS),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Text(
        'No requests yet. Successful fetches are saved automatically.',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: AppDimensions.fontSizeS,
        ),
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    WidgetRef ref,
    String label,
    List<HttpRequestEntry> entries, {
    required bool isSaved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        ...entries.map((e) => _buildRow(context, ref, e, isSaved: isSaved)),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    HttpRequestEntry entry, {
    required bool isSaved,
  }) {
    return InkWell(
      onTap: () => onRestoreEntry(entry),
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            _buildMethodBadge(entry.method),
            const SizedBox(width: 8),
            _buildEntryInfo(entry),
            _buildSaveButton(context, ref, entry, isSaved: isSaved),
            _buildDeleteButton(ref, entry, isSaved: isSaved),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodBadge(String method) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: httpMethodColor(method).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: httpMethodColor(method),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEntryInfo(HttpRequestEntry entry) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.name != null)
            Text(
              entry.name!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppDimensions.fontSizeS,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            entry.url,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    WidgetRef ref,
    HttpRequestEntry entry, {
    required bool isSaved,
  }) {
    return IconButton(
      icon: Icon(
        isSaved ? Icons.edit_outlined : Icons.star_border,
        size: 15,
        color: AppColors.textMuted,
      ),
      tooltip: isSaved ? 'Rename' : 'Save',
      onPressed: () => _promptSave(context, ref, entry),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildDeleteButton(
    WidgetRef ref,
    HttpRequestEntry entry, {
    required bool isSaved,
  }) {
    return IconButton(
      icon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
      tooltip: 'Remove',
      onPressed: () async {
        if (isSaved) {
          await ref
              .read(httpRequestHistoryProvider.notifier)
              .deleteSaved(entry.id);
        } else {
          await ref
              .read(httpRequestHistoryProvider.notifier)
              .deleteHistory(entry.id);
        }
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Future<void> _promptSave(
    BuildContext context,
    WidgetRef ref,
    HttpRequestEntry entry,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => SaveRequestDialog(initial: entry.name ?? ''),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(httpRequestHistoryProvider.notifier)
        .saveRequest(entry, name.trim());
  }
}

/// Dialog that prompts the user to enter a name for a saved HTTP request.
///
/// Properly disposes its [TextEditingController] via [StatefulWidget] lifecycle.
class SaveRequestDialog extends StatefulWidget {
  final String initial;

  const SaveRequestDialog({super.key, this.initial = ''});

  @override
  State<SaveRequestDialog> createState() => _SaveRequestDialogState();
}

class _SaveRequestDialogState extends State<SaveRequestDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
        'Save request',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeL,
        ),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeM,
        ),
        decoration: InputDecoration(
          hintText: 'Enter a name\u2026',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
