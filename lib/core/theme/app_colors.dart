import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1B4F72);        // Deep Navy
  static const Color primaryLight = Color(0xFF2E86C1);   // Ocean Blue
  static const Color primaryContainer = Color(0xFFD6EAF8); // Soft Blue
  static const Color secondary = Color(0xFF27AE60);      // Emerald Green
  static const Color secondaryLight = Color(0xFF58D68D); // Mint
  static const Color secondaryContainer = Color(0xFFD5F5E3); // Pale Green
  static const Color tertiary = Color(0xFFF39C12);       // Amber Gold
  static const Color tertiaryContainer = Color(0xFFFEF9E7); // Pale Gold

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color income = Color(0xFF27AE60);
  static const Color expense = Color(0xFFE74C3C);
  static const Color transfer = Color(0xFF8E44AD);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF2980B9);

  // ── Light Theme Neutrals ──────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8FAFB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF0F4F8);
  static const Color onSurfaceLight = Color(0xFF1A202C);
  static const Color onSurfaceVariantLight = Color(0xFF4A5568);
  static const Color outlineLight = Color(0xFFCBD5E0);
  static const Color outlineVariantLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFEDF2F7);

  // ── Dark Theme Neutrals ───────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F1923);
  static const Color surfaceDark = Color(0xFF1A2535);
  static const Color surfaceVariantDark = Color(0xFF243044);
  static const Color onSurfaceDark = Color(0xFFF7FAFC);
  static const Color onSurfaceVariantDark = Color(0xFFA0AEC0);
  static const Color outlineDark = Color(0xFF2D3748);
  static const Color outlineVariantDark = Color(0xFF4A5568);
  static const Color dividerDark = Color(0xFF2D3748);

  // ── Category Color Palette ─────────────────────────────────────────────────
  static const List<Color> categoryPalette = [
    Color(0xFF3498DB), // Blue — Food
    Color(0xFF27AE60), // Green — Health
    Color(0xFFE74C3C), // Red — Shopping
    Color(0xFFF39C12), // Amber — Transport
    Color(0xFF9B59B6), // Purple — Entertainment
    Color(0xFF1ABC9C), // Teal — Bills
    Color(0xFFE67E22), // Orange — Education
    Color(0xFF2ECC71), // Light Green — Salary
    Color(0xFF34495E), // Dark Grey — Others
    Color(0xFFE91E63), // Pink — Gifts
    Color(0xFF00BCD4), // Cyan — Travel
    Color(0xFFFF5722), // Deep Orange — Dining
  ];

  // ── Gradient ──────────────────────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const Gradient incomeGradient = LinearGradient(
    colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
  );

  static const Gradient expenseGradient = LinearGradient(
    colors: [Color(0xFFC0392B), Color(0xFFE74C3C)],
  );
}
