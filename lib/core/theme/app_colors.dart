import 'package:flutter/material.dart';

/// Centralised colour palette for MAAT Kiosk.
/// All colours are defined once here so changes propagate everywhere.
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0A0A0A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9B9B9B);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── Actions ───────────────────────────────────────────────────────────────
  static const Color actionPrimary = Color(0xFF000000);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF34C759);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);

  // ── Borders / Dividers ────────────────────────────────────────────────────
  static const Color border = Color(0xFFE8E8E8);
  static const Color divider = Color(0xFFF0F0F0);

  // ── Class tag palette ────────────────────────────────────────────────────
  static const Color tagGreen = Color(0xFF30A046);
  static const Color tagOrange = Color(0xFFE07B00);
  static const Color tagBlue = Color(0xFF0066CC);
  static const Color tagRed = Color(0xFFD70015);
  static const Color tagPurple = Color(0xFF4B44C8);

  static const List<Color> tagColors = [
    tagGreen,
    tagOrange,
    tagBlue,
    tagRed,
    tagPurple,
  ];

  /// Returns a consistent colour for a given tag string.
  static Color colorForTag(String tag) =>
      tagColors[tag.hashCode.abs() % tagColors.length];
}
