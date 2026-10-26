import 'package:flutter/material.dart';

class AppTheme {
  static const forestGreen = Color(0xFF176B3A);
  static const needsAttention = Color(0xFFFFC107);
  static const errorRed = Color(0xFFB3261E);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: forestGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: forestGreen,
          secondary: needsAttention,
          error: errorRed,
        );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(56, 56),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(18),
        labelStyle: TextStyle(fontSize: 18),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 20),
        bodyMedium: TextStyle(fontSize: 18),
        titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      ),
    );
  }
}
