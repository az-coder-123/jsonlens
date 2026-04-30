import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/curl_parser.dart';
import '../../../core/utils/json_fetcher.dart';
import '../providers/json_analyzer_provider.dart';

/// Dialog that fetches JSON from an HTTP URL and loads it into the editor.
///
/// Features:
/// - URL input with validation
/// - HTTP method selector (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS)
/// - Dynamic key-value header rows
/// - Optional request body (shown for POST, PUT, PATCH)
/// - Import from cURL command string
/// - Response preview before loading
/// - Clear error messages for every failure mode
class HttpRequestDialog extends ConsumerStatefulWidget {
  const HttpRequestDialog({super.key});

  @override
  ConsumerState<HttpRequestDialog> createState() => _HttpRequestDialogState();
}

class _HttpRequestDialogState extends ConsumerState<HttpRequestDialog> {
  final _urlController = TextEditingController();
  final _bodyController = TextEditingController();
  final _curlController = TextEditingController();
  final _urlFocus = FocusNode();

  String _method = 'GET';
  final List<_HeaderRow> _headers = [];

  bool _isFetching = false;
  bool _showCurlInput = false;
  String? _curlError;

  /// Non-null after a successful fetch — holds the raw JSON string to preview.
  String? _previewJson;

  /// Non-null after a failed fetch — holds the error message.
  String? _errorMessage;

  int? _responseStatusCode;

  @override
  void dispose() {
    _urlController.dispose();
    _bodyController.dispose();
    _curlController.dispose();
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
      body: JsonFetcher.methodHasBody(_method) ? _bodyController.text : '',
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

  // Parses the pasted cURL command and populates all request fields.
  void _applyCurl() {
    final raw = _curlController.text.trim();
    if (raw.isEmpty) return;

    try {
      final cmd = CurlParser.parse(raw);

      // Populate URL & method.
      _urlController.text = cmd.url;

      final upperMethod = cmd.method.toUpperCase();
      final validMethod = JsonFetcher.supportedMethods.contains(upperMethod)
          ? upperMethod
          : 'GET';

      // Replace existing headers with parsed ones.
      for (final h in _headers) {
        h.dispose();
      }
      _headers.clear();
      for (final entry in cmd.headers.entries) {
        final row = _HeaderRow();
        row.keyController.text = entry.key;
        row.valueController.text = entry.value;
        _headers.add(row);
      }

      // Populate body.
      _bodyController.text = cmd.body;

      setState(() {
        _method = validMethod;
        _showCurlInput = false;
        _curlError = null;
        // Reset previous results.
        _previewJson = null;
        _errorMessage = null;
        _responseStatusCode = null;
      });

      _curlController.clear();
    } on FormatException catch (e) {
      setState(() => _curlError = e.message);
    }
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
                    if (_showCurlInput) ...[
                      _buildCurlSection(),
                      const SizedBox(height: AppDimensions.paddingM),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: AppDimensions.paddingM),
                    ],
                    _buildUrlRow(),
                    const SizedBox(height: AppDimensions.paddingM),
                    _buildHeadersSection(),
                    if (JsonFetcher.methodHasBody(_method)) ...[
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
            'HTTP Request',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              _showCurlInput = !_showCurlInput;
              _curlError = null;
            }),
            icon: Icon(
              Icons.terminal,
              size: AppDimensions.iconSizeS,
              color: _showCurlInput
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            label: Text(
              'Import cURL',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeS,
                color: _showCurlInput
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
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

  Widget _buildCurlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.terminal,
              size: AppDimensions.iconSizeS,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimensions.paddingXS),
            const Text(
              'Paste cURL command',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppDimensions.fontSizeS,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        TextField(
          controller: _curlController,
          maxLines: 4,
          style: GoogleFonts.jetBrainsMono(
            fontSize: AppDimensions.fontSizeS,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
          decoration: _fieldDecoration(
            'curl -X POST https://api.example.com/data \\\n  -H "Authorization: Bearer token" \\\n  -d \'{"key":"value"}\'',
          ),
        ),
        if (_curlError != null) ...[
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            _curlError!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: AppDimensions.fontSizeS,
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.paddingS),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _applyCurl,
            icon: const Icon(Icons.input, size: AppDimensions.iconSizeS),
            label: const Text('Apply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              foregroundColor: AppColors.textPrimary,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
            ),
          ),
        ),
      ],
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
                color: _methodColor(_method),
                fontWeight: FontWeight.w700,
              ),
              items: JsonFetcher.supportedMethods
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        m,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: AppDimensions.fontSizeS,
                          color: _methodColor(m),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
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

  /// Returns a color for each HTTP method following REST API convention.
  Color _methodColor(String method) => switch (method) {
    'GET' => AppColors.secondary, // teal — safe read
    'POST' => AppColors.warning, // orange — create
    'PUT' => const Color(0xFF569CD6), // blue — full replace
    'PATCH' => const Color(0xFFB5CEA8), // green — partial update
    'DELETE' => AppColors.error, // red — destructive
    'HEAD' => AppColors.textSecondary,
    _ => AppColors.textSecondary, // OPTIONS, fallback
  };

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
