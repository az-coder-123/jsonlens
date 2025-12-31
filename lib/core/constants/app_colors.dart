import 'package:flutter/material.dart';

/// Application color constants for JSONLens.
///
/// Defines the dark theme color palette used throughout the app.
abstract final class AppColors {
  // Background colors
  static const Color background = Color(0xFF1E1E1E);
  static const Color surface = Color(0xFF252526);
  static const Color surfaceVariant = Color(0xFF2D2D30);

  // Text colors
  static const Color textPrimary = Color(0xFFD4D4D4);
  static const Color textSecondary = Color(0xFF808080);
  static const Color textMuted = Color(0xFF6A6A6A);

  // Accent colors
  static const Color primary = Color(0xFF569CD6);
  static const Color secondary = Color(0xFF4EC9B0);
  static const Color accent = Color(0xFFDCDCAA);

  // Status colors
  static const Color success = Color(0xFF4EC9B0);
  static const Color error = Color(0xFFF44747);
  static const Color warning = Color(0xFFCE9178);

  // JSON syntax highlighting colors
  static const Color jsonKey = Color(0xFF9CDCFE);
  static const Color jsonString = Color(0xFFCE9178);
  static const Color jsonNumber = Color(0xFFB5CEA8);
  static const Color jsonBoolean = Color(0xFF569CD6);
  static const Color jsonNull = Color(0xFF569CD6);
  static const Color jsonBracket = Color(0xFFD4D4D4);

  // Border colors
  static const Color border = Color(0xFF3C3C3C);
  static const Color borderFocused = Color(0xFF007ACC);

  // Button colors
  static const Color buttonPrimary = Color(0xFF0E639C);
  static const Color buttonHover = Color(0xFF1177BB);
}
