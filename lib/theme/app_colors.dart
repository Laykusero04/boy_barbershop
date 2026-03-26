import 'package:flutter/material.dart';

/// Semantic palette for Boy Barbershop — dirty white surfaces, brown primary, blue accents.
abstract final class AppColors {
  AppColors._();

  /// Warm off-white (not pure white).
  static const Color dirtyWhite = Color(0xFFF5F0E8);
  static const Color dirtyWhiteDim = Color(0xFFEDE8E0);

  /// Primary brown family (brand / main actions).
  static const Color brown = Color(0xFF5D4037);
  static const Color brownDark = Color(0xFF3E2723);
  static const Color brownContainer = Color(0xFFD7CCC8);
  static const Color onBrownContainer = Color(0xFF2D1B18);

  /// Blue accent (links, focus, secondary emphasis).
  static const Color blueAccent = Color(0xFF1976D2);
  static const Color blueContainer = Color(0xFFE3F2FD);
  static const Color onBlueContainer = Color(0xFF0D47A1);

  static const Color outlineMuted = Color(0xFF8D6E63);
}
