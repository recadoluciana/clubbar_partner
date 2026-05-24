import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: const Color(0xFF080808),

    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFF5C542),
      secondary: const Color(0xFFF5C542),

      surface: const Color(0xFF111111),

      onPrimary: Colors.black,
      onSurface: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      elevation: 0,

      backgroundColor: Colors.black,

      foregroundColor: Color(0xFFF5C542),

      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF111111),

      elevation: 0,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,

      fillColor: const Color(0xFF111111),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: Color(0xFF222222)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: Color(0xFFF5C542), width: 2),
      ),

      labelStyle: const TextStyle(color: Colors.white70),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF5C542),

        foregroundColor: Colors.black,

        minimumSize: const Size(120, 52),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),

    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),

      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}
