import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/json_schema_validator.dart';
import '../providers/json_analyzer_provider.dart';

/// Panel that lets users paste a JSON Schema and validate the current
/// document against it.
///
/// Displays a schema input field, a Validate button, and an error list.
class JsonSchemaPanel extends ConsumerStatefulWidget {
  const JsonSchemaPanel({super.key});

  @override
  ConsumerState<JsonSchemaPanel> createState() => _JsonSchemaPanelState();
}

class _JsonSchemaPanelState extends ConsumerState<JsonSchemaPanel> {
  final _schemaController = TextEditingController();
  final _schemaFocus = FocusNode();

  SchemaValidationResult? _result;
  bool _validated = false;

  @override
  void dispose() {
    _schemaController.dispose();
    _schemaFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _validate() {
    final schemaText = _schemaController.text.trim();
    if (schemaText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a JSON Schema first.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final jsonText = ref.read(inputProvider);
    if (jsonText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No JSON document to validate.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = JsonSchemaValidator.validate(schemaText, jsonText);
    setState(() {
      _result = result;
      _validated = true;
    });
  }

  void _clearSchema() {
    _schemaController.clear();
    setState(() {
      _result = null;
      _validated = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: schema input
        Expanded(flex: 2, child: _buildSchemaInput()),
        const VerticalDivider(width: 1, color: AppColors.border),
        // Right: validation results
        Expanded(flex: 3, child: _buildResultsPanel()),
      ],
    );
  }

  Widget _buildSchemaInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.schema,
          label: 'JSON Schema',
          actions: [
            _headerBtn(
              icon: Icons.clear_all,
              tooltip: 'Clear schema',
              onPressed: _clearSchema,
            ),
          ],
        ),
        Expanded(
          child: TextField(
            controller: _schemaController,
            focusNode: _schemaFocus,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
              border: InputBorder.none,
              hintText:
                  '{\n  "\$schema": "http://json-schema.org/draft-07/schema#",\n  "type": "object",\n  "properties": { ... }\n}',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ),
        _buildValidateButton(),
      ],
    );
  }

  Widget _buildValidateButton() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: AppDimensions.buttonHeight,
        child: ElevatedButton.icon(
          onPressed: _validate,
          icon: const Icon(
            Icons.verified_outlined,
            size: AppDimensions.iconSizeS,
          ),
          label: const Text('Validate against document'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(icon: Icons.checklist, label: 'Validation Results'),
        Expanded(child: _buildResultsContent()),
      ],
    );
  }

  Widget _buildResultsContent() {
    if (!_validated || _result == null) {
      return _buildPlaceholder(
        icon: Icons.schema_outlined,
        message: 'Paste a JSON Schema and press Validate.',
      );
    }

    if (_result!.schemaParseError != null) {
      return _buildSchemaError(_result!.schemaParseError!);
    }

    if (_result!.isValid) {
      return _buildValidBadge();
    }

    return _buildErrorList(_result!.errors);
  }

  Widget _buildPlaceholder({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 32),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: AppDimensions.fontSizeS,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSchemaError(String error) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppDimensions.iconSizeS,
              ),
              SizedBox(width: AppDimensions.paddingXS),
              Text(
                'Schema Error',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: AppDimensions.fontSizeS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            error,
            style: GoogleFonts.jetBrainsMono(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidBadge() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 40),
          const SizedBox(height: AppDimensions.paddingS),
          const Text(
            'Valid',
            style: TextStyle(
              color: AppColors.success,
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          const Text(
            'Document conforms to the schema.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppDimensions.fontSizeS,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorList(List<SchemaValidationError> errors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingXS,
          ),
          color: AppColors.error.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppDimensions.iconSizeS,
              ),
              const SizedBox(width: AppDimensions.paddingXS),
              Text(
                '${errors.length} error${errors.length == 1 ? '' : 's'} found',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: AppDimensions.fontSizeS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Error rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingXS,
            ),
            itemCount: errors.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) =>
                _buildErrorRow(errors[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorRow(SchemaValidationError error, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path + constraint badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingXS,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: Text(
                  error.constraint,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingS),
              Expanded(
                child: Text(
                  error.path,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: AppDimensions.fontSizeS,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          // Message
          Text(
            error.message,
            style: const TextStyle(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared header / button helpers
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    List<Widget> actions = const [],
  }) {
    return Container(
      height: AppDimensions.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeS,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.paddingXS),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppDimensions.fontSizeS,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }

  Widget _headerBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: AppDimensions.iconSizeS),
      tooltip: tooltip,
      color: AppColors.textSecondary,
      splashRadius: 16,
      onPressed: onPressed,
    );
  }
}
