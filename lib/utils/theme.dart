import 'package:flutter/material.dart';

class FuelixTheme {
  // Brand colors matching the add-on specifications
  static const Color darkBg = Color(0xFF0A0A0F);
  static const Color darkCard = Color(0xFF16161D);
  static const Color lightBg = Color(0xFFFAFAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  
  static const Color accentOrange = Color(0xFF8B5CF6); // Brand Primary Accent (mapped from Orange)
  static const Color accentLime = Color(0xFF2DD4F0);   // Brand Secondary Accent (mapped from Lime)
  
  static const Color textDarkPrimary = Color(0xFF111114);
  static const Color textDarkSecondary = Color(0xFF6C6E72);
  static const Color textLightPrimary = Color(0xFFF2F2F5);
  static const Color textLightSecondary = Color(0xFFA1A3A7);

  // Common card decorations
  static BorderRadius cardRadius = BorderRadius.circular(20);
  
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF6D28D9),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6D28D9),
        secondary: Color(0xFF0891B2),
        surface: lightBg,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: lightBg,
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6D28D9),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDarkPrimary),
        titleTextStyle: TextStyle(
          color: textDarkPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCard,
        selectedItemColor: Color(0xFF6D28D9),
        unselectedItemColor: textDarkSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF8B5CF6),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8B5CF6),
        secondary: Color(0xFF2DD4F0),
        surface: darkBg,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: Color(0xFF8B5CF6),
        unselectedItemColor: textLightSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
