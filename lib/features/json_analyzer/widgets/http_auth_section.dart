import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

/// Auth quick-fill panel for HTTP request dialogs.
///
/// Manages its own auth type and credential fields.
/// Calls [onApply] with the generated Authorization header value so the
/// parent can insert it into the request headers.
class HttpAuthSection extends StatefulWidget {
  /// Called when the user taps "Apply to headers".
  ///
  /// Receives the ready-to-use Authorization header value (e.g.
  /// `"Bearer <token>"` or `"Basic <base64>"`).
  final void Function(String headerValue) onApply;

  const HttpAuthSection({super.key, required this.onApply});

  @override
  State<HttpAuthSection> createState() => _HttpAuthSectionState();
}

class _HttpAuthSectionState extends State<HttpAuthSection> {
  /// Current auth type: 'none' | 'bearer' | 'basic'.
  String _authType = 'none';

  final _tokenController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _apply() {
    String? headerValue;
    if (_authType == 'bearer') {
      final token = _tokenController.text.trim();
      if (token.isEmpty) return;
      headerValue = 'Bearer $token';
    } else if (_authType == 'basic') {
      final user = _userController.text.trim();
      final pass = _passController.text;
      final encoded = base64Encode(utf8.encode('$user:$pass'));
      headerValue = 'Basic $encoded';
    }
    if (headerValue == null) return;
    widget.onApply(headerValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lock_outline,
              size: AppDimensions.iconSizeS,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimensions.paddingXS),
            const Text(
              'Auth',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppDimensions.fontSizeS,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            _typeChip('none', 'No Auth'),
            const SizedBox(width: 6),
            _typeChip('bearer', 'Bearer Token'),
            const SizedBox(width: 6),
            _typeChip('basic', 'Basic Auth'),
          ],
        ),
        if (_authType == 'bearer') ...[
          const SizedBox(height: AppDimensions.paddingS),
          _textField(_tokenController, 'Token'),
        ],
        if (_authType == 'basic') ...[
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            children: [
              Expanded(child: _textField(_userController, 'Username')),
              const SizedBox(width: AppDimensions.paddingS),
              Expanded(
                child: _textField(_passController, 'Password', obscure: true),
              ),
            ],
          ),
        ],
        if (_authType != 'none') ...[
          const SizedBox(height: AppDimensions.paddingS),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check, size: AppDimensions.iconSizeS),
              label: const Text('Apply to headers'),
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
      ],
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _authType == value;
    return GestureDetector(
      onTap: () => setState(() => _authType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: GoogleFonts.jetBrainsMono(
        fontSize: AppDimensions.fontSizeS,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
