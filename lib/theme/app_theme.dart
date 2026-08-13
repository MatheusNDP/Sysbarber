import 'package:flutter/material.dart';

/// Paleta oficial do SysBarber: tema escuro premium, preto e dourado.
class AppColors {
  static const Color background = Color(0xFF0A0A0A); // preto
  static const Color dark = Color(0xFF141414);
  static const Color card = Color(0xFF1C1C1C);
  static const Color card2 = Color(0xFF242424);
  static const Color gold = Color(0xFFC9A84C); // dourado principal
  static const Color goldLight = Color(0xFFE8C96A);
  static const Color border = Color(0x33C9A84C);
  static const Color text = Color(0xFFF0ECE0); // off-white
  static const Color muted = Color(0xFF888888);
  static const Color red = Color(0xFFE05252);
  static const Color green = Color(0xFF52C878);
}

/// Tipografia e tema global do aplicativo.
///
/// As duas famílias são **embarcadas no APK** (declaradas em `pubspec.yaml`),
/// e não baixadas em tempo de execução: o app mantém a identidade visual mesmo
/// sem conexão com a internet.
class AppTheme {
  /// Família serifada — títulos, logo e números de destaque.
  static const String fonteSerif = 'Playfair Display';

  /// Família de interface — corpo do aplicativo.
  static const String fonteSans = 'DM Sans';

  /// Fonte serifada usada em títulos, logo e números de destaque.
  static TextStyle serif({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fonteSerif,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Fonte de interface usada no corpo do aplicativo.
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fonteSans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData get tema {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.goldLight,
        surface: AppColors.card,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSurface: AppColors.text,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fonteSans,
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.gold),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: AppTheme.sans(size: 13, color: AppColors.muted),
        hintStyle: AppTheme.sans(size: 13, color: AppColors.muted),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}
