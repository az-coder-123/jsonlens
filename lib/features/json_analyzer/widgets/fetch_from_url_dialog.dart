import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/json_fetcher.dart';
import '../providers/json_analyzer_provider.dart';

/// Dialog that fetches JSON from an HTTP URL and loads it into the editor.
///
/// Features:
/// - URL input with validation
/// - HTTP method selector (GET / POST)
/// - Dynamic key-value header rows
/// - Optional POST body input
/// - Response preview before loading
/// - Clear error messages for every failure mode
class FetchFromUrlDialog extends ConsumerStatefulWidget {
  const FetchFromUrlDialog({super.key});

  @override
  ConsumerState<FetchFromUrlDialog> createState() => _FetchFromUrlDialogState();
}

class _FetchFromUrlDialogState extends ConsumerState<FetchFromUrlDialog> {
  final _urlController = TextEditingController();
  final _bodyController = TextEditingController();
  final _urlFocus = FocusNode();

  String _method = 'GET';
  final List<_HeaderRow> _headers = [];

  bool _isFetching = false;

  /// Non-null after a successful fetch — holds the raw JSON string to preview.
  String? _previewJson;

  /// Non-null after a failed fetch — holds the error message.
  String? _errorMessage;

  int? _responseStatusCode;

  @override
  void dispose() {
    _urlController.dispose();
    _bodyController.dispose();
    _urlFocus.dispose();
    for (final h in _headers) {
      h.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _fetch() async {
    setState(() {
      _isFetching = true;
      _previewJson = null;
      _errorMessage = null;
      _responseStatusCode = null;
    });

    final url = _urlController.text.trim();
    final headers = <String, String>{};
    for (final row in _headers) {
      final k = row.keyController.text.trim();
      final v = row.valueController.text.trim();
      if (k.isNotEmpty) headers[k] = v;
    }

    final result = await JsonFetcher.fetch(
      url: url,
      method: _method,
      headers: headers,
      body: _method == 'POST' ? _bodyController.text : '',
    );

    if (!mounted) return;
    setState(() {
      _isFetching = false;
      _responseStatusCode = result.statusCode;
      if (result.isOk) {
        // Pretty-print for preview.
        _previewJson = const JsonEncoder.withIndent('  ').convert(result.data);
        _errorMessage = null;
      } else {
        _previewJson = null;
        _errorMessage = result.error;
      }
    });
  }

  void _loadIntoEditor() {
    if (_previewJson == null) return;
    ref.read(jsonAnalyzerProvider.notifier).updateInput(_previewJson!);
    Navigator.of(context).pop();
  }

  void _addHeaderRow() {
    setState(() => _headers.add(_HeaderRow()));
  }

  void _removeHeaderRow(int index) {
    setState(() {
      _headers[index].dispose();
      _headers.removeAt(index);
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle(),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUrlRow(),
                    const SizedBox(height: AppDimensions.paddingM),
                    _buildHeadersSection(),
                    if (_method == 'POST') ...[
                      const SizedBox(height: AppDimensions.paddingM),
                      _buildBodySection(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppDimensions.paddingM),
                      _buildErrorBanner(_errorMessage!),
                    ],
                    if (_previewJson != null) ...[
                      const SizedBox(height: AppDimensions.paddingM),
                      _buildPreviewSection(_previewJson!),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_download_outlined,
            color: AppColors.primary,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          const Text(
            'Fetch JSON from URL',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: AppDimensions.iconSizeM),
            color: AppColors.textSecondary,
            splashRadius: 18,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlRow() {
    return Row(
      children: [
        // Method selector
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _method,
              dropdownColor: AppColors.surface,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: _method == 'POST'
                    ? AppColors.warning
                    : AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
              items: const [
                DropdownMenuItem(value: 'GET', child: Text('GET')),
                DropdownMenuItem(value: 'POST', child: Text('POST')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'GET'),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.paddingS),
        // URL field
        Expanded(
          child: TextField(
            controller: _urlController,
            focusNode: _urlFocus,
            autofocus: true,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textPrimary,
            ),
            decoration: _fieldDecoration('https://example.com/api/data.json'),
            onSubmitted: (_) => _isFetching ? null : _fetch(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Headers',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppDimensions.fontSizeS,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addHeaderRow,
              icon: const Icon(Icons.add, size: AppDimensions.iconSizeS),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        if (_headers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingXS,
            ),
            child: Text(
              'No custom headers — Accept: application/json is sent by default.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: AppDimensions.fontSizeS,
              ),
            ),
          )
        else
          ...List.generate(_headers.length, (i) => _buildHeaderRow(i)),
      ],
    );
  }

  Widget _buildHeaderRow(int index) {
    final row = _headers[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: row.keyController,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textPrimary,
              ),
              decoration: _fieldDecoration('Header name'),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingXS),
          Expanded(
            child: TextField(
              controller: row.valueController,
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textPrimary,
              ),
              decoration: _fieldDecoration('Value'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: AppDimensions.iconSizeS),
            color: AppColors.textMuted,
            splashRadius: 14,
            tooltip: 'Remove',
            onPressed: () => _removeHeaderRow(index),
          ),
        ],
      ),
    );
  }

  Widget _buildBodySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request body',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppDimensions.fontSizeS,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        TextField(
          controller: _bodyController,
          maxLines: 5,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.textPrimary,
          ),
          decoration: _fieldDecoration('{ "key": "value" }'),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: AppDimensions.iconSizeS,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: AppDimensions.fontSizeS,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(String json) {
    final lineCount = '\n'.allMatches(json).length + 1;
    final charCount = json.length;
    final statusLabel = _responseStatusCode != null
        ? ' · HTTP $_responseStatusCode'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: AppDimensions.iconSizeS,
            ),
            const SizedBox(width: AppDimensions.paddingXS),
            Text(
              'Valid JSON$statusLabel · $lineCount lines · $charCount chars',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: AppDimensions.fontSizeS,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Text(
              // Show at most the first 80 lines for performance.
              _truncatePreview(json, maxLines: 80),
              style: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          if (_previewJson == null) ...[
            ElevatedButton.icon(
              onPressed: _isFetching ? null : _fetch,
              icon: _isFetching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Icon(Icons.download, size: AppDimensions.iconSizeS),
              label: Text(_isFetching ? 'Fetching…' : 'Fetch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _previewJson = null;
                _errorMessage = null;
                _responseStatusCode = null;
              }),
              icon: const Icon(Icons.refresh, size: AppDimensions.iconSizeS),
              label: const Text('Re-fetch'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingS),
            ElevatedButton.icon(
              onPressed: _loadIntoEditor,
              icon: const Icon(
                Icons.open_in_browser,
                size: AppDimensions.iconSizeS,
              ),
              label: const Text('Load into editor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: AppDimensions.fontSizeS,
        fontFamily: 'JetBrains Mono',
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
    );
  }

  String _truncatePreview(String json, {required int maxLines}) {
    final lines = json.split('\n');
    if (lines.length <= maxLines) return json;
    return '${lines.take(maxLines).join('\n')}\n… (${lines.length - maxLines} more lines)';
  }
}

/// Mutable container for a header key-value pair row.
class _HeaderRow {
  final keyController = TextEditingController();
  final valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
