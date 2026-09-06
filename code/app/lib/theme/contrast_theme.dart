import 'dart:math' as math;

import 'package:flutter/material.dart';

/// High-contrast palette, a *peer* to [HaikuTheme] (research 11 §3).
///
/// Haiku answers "who was measured." This answers "can the text be read."
/// They are not one axis. Ratios below are WCAG 2.1:
///   normal text ≥ 4.5:1, large text / UI chrome ≥ 3:1.
/// The numbers are computed from the actual colors, not eyeballed.
abstract final class ContrastTheme {
  static const Color background = Color(0xFF000000);
  static const Color foreground = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFFFFF00); // yellow on black ~19:1
  static const Color onAccent = Color(0xFF000000);
  static const Color danger = Color(0xFFFF6B6B);

  static ColorScheme scheme({Brightness brightness = Brightness.dark}) {
    // Direction does not matter for WCAG — only the ratio. We ship one
    // verified dark palette rather than a dim "dark mode" that can fail 4.5:1.
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: onAccent,
      secondary: foreground,
      onSecondary: background,
      error: danger,
      onError: background,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: Color(0xFFE6E6E6),
      outline: foreground,
      outlineVariant: Color(0xFFB3B3B3),
      primaryContainer: Color(0xFF1A1A00),
      onPrimaryContainer: accent,
      tertiary: accent,
      onTertiary: onAccent,
      tertiaryContainer: Color(0xFF2A2A00),
      onTertiaryContainer: accent,
      inverseSurface: foreground,
      onInverseSurface: background,
    );
  }

  /// WCAG relative luminance of [color] (sRGB, 0..1 channels).
  static double luminance(Color color) {
    double lin(double channel) => channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(color.r) + 0.7152 * lin(color.g) + 0.0722 * lin(color.b);
  }

  /// Contrast ratio of two colors, 1..21.
  static double ratio(Color a, Color b) {
    final l1 = luminance(a);
    final l2 = luminance(b);
    final light = math.max(l1, l2);
    final dark = math.min(l1, l2);
    return (light + 0.05) / (dark + 0.05);
  }
}
