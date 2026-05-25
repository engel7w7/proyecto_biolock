import 'package:flutter/material.dart';

class BioLockThemes {
  static final darkTheme = ThemeData.dark().copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0F1419),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1F5BA6),
      secondary: Color(0xFF17A697),
      surface: Color(0xFF1A1F2E),
      error: Color(0xFFE53935),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1F2E),
      elevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F5BA6),
        foregroundColor: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFF0F0F0),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFFB0B0B0),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}
