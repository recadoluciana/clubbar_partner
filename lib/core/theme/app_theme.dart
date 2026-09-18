import 'package:flutter/material.dart';

import 'clubbar_colors.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,

      scaffoldBackgroundColor: Colors.white,

      textTheme: ThemeData.light().textTheme.apply(fontSizeFactor: 0.92),

      colorScheme: ColorScheme.fromSeed(
        seedColor: ClubbarColors.primaria,
        brightness: Brightness.light,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),

      cardTheme: const CardThemeData(color: Colors.white, elevation: 2),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ClubbarColors.primaria, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ClubbarColors.primaria,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClubbarColors.primaria,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ClubbarColors.primaria,
        foregroundColor: Colors.white,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ClubbarColors.primaria,
      ),

      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: ClubbarColors.primariaClaro,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: ClubbarColors.primariaEscuro),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData.dark();
  }
}
