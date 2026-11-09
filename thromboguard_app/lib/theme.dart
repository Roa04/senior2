import 'package:flutter/material.dart';

/// Colors lifted directly from the HTML mockups (login.html, homenormal.html, etc.)
class AppColors {
  static const navy = Color(0xFF03045E);
  static const blue = Color(0xFF0077B6);
  static const bg = Color(0xFFF0F4F8);
  static const bgCard = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const grey = Color(0xFF718096);
  static const mutedGrey = Color(0xFFA0AEC0);

  static const green = Color(0xFF10B981);
  static const greenBg = Color(0xFFE6F9F0);
  static const greenText = Color(0xFF065F46);

  static const amber = Color(0xFFF59E0B);
  static const amberBg = Color(0xFFFFFBEB);
  static const amberText = Color(0xFFB45309);

  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFEE2E2);
  static const redDark = Color(0xFF7F1D1D);
  static const redText = Color(0xFF991B1B);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
    ),
    fontFamily: 'Segoe UI',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );
}
