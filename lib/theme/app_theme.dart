import 'package:flutter/material.dart';

/// Paleta oficial do SysBarber: fundo grafite e destaque amarelo.
class AppColors {
  static const Color background = Color(0xFF151515); // grafite
  static const Color dark = Color(0xFF1B1B1B); // barras e folhas
  static const Color card = Color(0xFF212121);
  static const Color card2 = Color(0xFF2C2C2C); // campos e círculos de ícone
  static const Color amarelo = Color(0xFFFFD23F); // destaque principal
  static const Color border = Color(0x1FFFFFFF); // branco a 12%
  static const Color vidro = Color(0x1AFFFFFF); // branco a 10%: translúcidos
  static const Color text = Color(0xFFF5F5F5);
  static const Color muted = Color(0xFF9A9A9A);
  static const Color red = Color(0xFFFF5C5C);
  static const Color green = Color(0xFF4CD787);
}

/// Tipografia e tema global do aplicativo.
///
/// A fonte é **embarcada no APK** (declarada em `pubspec.yaml`), e não baixada
/// em tempo de execução: o app mantém a identidade visual mesmo sem conexão
/// com a internet.
class AppTheme {
  /// Família única do app: Montserrat, em quatro pesos (400 a 700).
  static const String fonte = 'Montserrat';

  /// Títulos e números de destaque.
  static TextStyle titulo({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fonte,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Texto do corpo do aplicativo.
  static TextStyle texto({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fonte,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData get tema {
    final base = ThemeData.dark(useMaterial3: true);
    // Campo preenchido: com a borda "de baixo" o rótulo flutuante fica dentro
    // do campo (com contorno, ele ficaria em cima da borda).
    const bordaCampo = UnderlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.amarelo,
        secondary: AppColors.amarelo,
        surface: AppColors.card,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: AppColors.text,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fonte,
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.text),
        actionsIconTheme: const IconThemeData(color: AppColors.text),
        titleTextStyle: titulo(size: 18, weight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: titulo(size: 18, weight: FontWeight.w600),
        contentTextStyle: texto(size: 14, color: AppColors.muted, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.dark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.card2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: texto(),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amarelo,
        linearTrackColor: AppColors.card2,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.amarelo,
          textStyle: texto(weight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.amarelo,
        foregroundColor: Colors.black,
        elevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedTextStyle: texto(weight: FontWeight.w600),
      ),
      // Abas em pílula: a selecionada fica amarela, como as categorias.
      tabBarTheme: TabBarThemeData(
        indicator: const ShapeDecoration(
          color: AppColors.amarelo,
          shape: StadiumBorder(),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.muted,
        labelStyle: texto(size: 13, weight: FontWeight.w600),
        unselectedLabelStyle: texto(size: 13, weight: FontWeight.w500),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card2,
        selectedColor: AppColors.amarelo,
        disabledColor: AppColors.card,
        checkmarkColor: Colors.black,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: texto(size: 13, weight: FontWeight.w500),
        secondaryLabelStyle: texto(
          size: 13,
          weight: FontWeight.w600,
          color: Colors.black,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.black : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.amarelo
              : AppColors.card2,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.amarelo
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: const BorderSide(color: AppColors.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.amarelo
              : AppColors.muted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: texto(size: 13, color: AppColors.muted),
        // O rótulo só fica amarelo no campo em edição.
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (s) => texto(
            size: 13,
            color: s.contains(WidgetState.focused)
                ? AppColors.amarelo
                : AppColors.muted,
          ),
        ),
        hintStyle: texto(size: 13, color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: bordaCampo,
        enabledBorder: bordaCampo,
        focusedBorder: bordaCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.amarelo, width: 2),
        ),
        errorBorder: bordaCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: bordaCampo.copyWith(
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
      ),
    );
  }
}
