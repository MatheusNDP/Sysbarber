import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color black = Color(0xFF0A0A0A);
  static const Color background = Color(0xFF0A0A0A);
  static const Color dark = Color(0xFF141414);
  static const Color card = Color(0xFF1C1C1C);
  static const Color card2 = Color(0xFF242424);
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8C96A);
  static const Color goldDim = Color(0x26C9A84C);
  static const Color border = Color(0x33C9A84C);
  static const Color text = Color(0xFFF0ECE0);
  static const Color muted = Color(0xFF888888);
  static const Color textMuted = Color(0xFF888888);
  static const Color red = Color(0xFFE05252);
  static const Color green = Color(0xFF52C878);
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.gold,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.goldLight,
        surface: AppColors.card,
        background: AppColors.background,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: AppColors.text,
        onBackground: AppColors.text,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.gold,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.gold),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
    );
  }

  static TextStyle goldLabel({double size = 11}) => GoogleFonts.dmSans(
        color: AppColors.gold,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      );

  static TextStyle title({double size = 22}) => GoogleFonts.playfairDisplay(
        color: AppColors.text,
        fontSize: size,
        fontWeight: FontWeight.w700,
      );

  static TextStyle subtitle({double size = 13}) => GoogleFonts.dmSans(
        color: AppColors.muted,
        fontSize: size,
      );
}
