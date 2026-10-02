import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0C1D19);
  static const card2 = Color(0xFF102720);
  static const green = Color(0xFF39E58C);
  static const green2 = Color(0xFF0BCB76);
  static const muted = Color(0xFF91A9A0);
  static const red = Color(0xFFFF5470);

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark),
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(color: card, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFF10242D),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: muted),
    ),
  );
}
