import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const ink = Color(0xFF17221B);
    const moss = Color(0xFF3C6E4E);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: moss, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F4ED),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }
}
