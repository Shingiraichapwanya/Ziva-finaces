import 'package:flutter/material.dart';

class ZivaTheme {
  // Dark Obsidian Palette ported from Web Dashboard
  static const Color bgCore = Color(0xFF07090E);
  static const Color bgSurface = Color(0xFF0E131F);
  static const Color bgCard = Color(0xFF111827);
  static const Color bgCardHover = Color(0xFF1A2438);
  static const Color bgElevated = Color(0xFF161E31);

  // Borders
  static const Color borderCard = Color(0x1FFFFFFF); // 12% white
  static const Color borderSubtle = Color(0x12FFFFFF); // 7% white
  static const Color borderFocus = Color(0x80F59E0B);

  // African Gold & Amber Primary Accents
  static const Color gold300 = Color(0xFFFDE68A);
  static const Color gold400 = Color(0xFFFBBF24);
  static const Color gold500 = Color(0xFFF59E0B);
  static const Color gold600 = Color(0xFFD97706);
  static const Color goldGlow = Color(0x40F59E0B);

  // Semantic Colors
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emeraldBg = Color(0x2610B981);

  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color roseBg = Color(0x26F43F5E);

  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyanBg = Color(0x2606B6D4);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Global ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgCore,
      colorScheme: const ColorScheme.dark(
        primary: gold500,
        secondary: cyan400,
        surface: bgSurface,
        background: bgCore,
        error: rose500,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      cardTheme: CardTheme(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderCard),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgCore,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold500,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderCard),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderCard),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderCard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: gold500, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
      ),
    );
  }
}
