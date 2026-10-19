import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores manuales de la guía. Ejemplo: AppColors.primary.shade100.
abstract final class AppColors {
  static const primary = MaterialColor(0xFF765FFF, {
    50: Color(0xFFF2EFFF),
    100: Color(0xFFE5DEFF),
    200: Color(0xFFCABBFF),
    300: Color(0xFFB0A0FF),
    400: Color(0xFF8B79FF),
    500: Color(0xFF765FFF),
    600: Color(0xFF5C46E5),
    700: Color(0xFF4933C2),
    800: Color(0xFF38259E),
    900: Color(0xFF1F1373),
  });

  // Misma escala violeta; la base secundaria corresponde al tono 900.
  static const secondary = MaterialColor(0xFF1F1373, {
    50: Color(0xFFF2EFFF),
    100: Color(0xFFE5DEFF),
    200: Color(0xFFCABBFF),
    300: Color(0xFFB0A0FF),
    400: Color(0xFF8B79FF),
    500: Color(0xFF765FFF),
    600: Color(0xFF5C46E5),
    700: Color(0xFF4933C2),
    800: Color(0xFF38259E),
    900: Color(0xFF1F1373),
  });

  static const neutral = MaterialColor(0xFF121217, {
    0: Color(0xFFFFFFFF),
    50: Color(0xFFF6F6F7),
    100: Color(0xFFE8E8EA),
    200: Color(0xFFC9C9CE),
    300: Color(0xFF9A9AA3),
    400: Color(0xFF70707A),
    500: Color(0xFF4A4A54),
    600: Color(0xFF2E2E36),
    700: Color(0xFF1C1C22),
    800: Color(0xFF121217),
    900: Color(0xFF07070A),
  });

  /// Pasado: memoria y sonidos conocidos.
  static const echo = MaterialColor(0xFFFF6E30, {
    50: Color(0xFFFFF1EB),
    100: Color(0xFFFFE0D1),
    200: Color(0xFFFFC0A3),
    300: Color(0xFFFFA075),
    400: Color(0xFFFF8852),
    500: Color(0xFFFF6E30),
    600: Color(0xFFE5551A),
    700: Color(0xFFBF4310),
    800: Color(0xFF993308),
    900: Color(0xFF6E2204),
  });

  /// Presente: reproducción y actividad actual.
  static const pulse = MaterialColor(0xFFAAE648, {
    50: Color(0xFFF7FFE5),
    100: Color(0xFFEFFFC9),
    200: Color(0xFFDEFE99),
    300: Color(0xFFCCFB6E),
    400: Color(0xFFBAF159),
    500: Color(0xFFAAE648),
    600: Color(0xFF91CC32),
    700: Color(0xFF74A622),
    800: Color(0xFF587F18),
    900: Color(0xFF3A560E),
  });

  /// Futuro: descubrimiento y exploración.
  static const bloom = MaterialColor(0xFFF42E84, {
    50: Color(0xFFFFEEF5),
    100: Color(0xFFFFDCEB),
    200: Color(0xFFFFB3D1),
    300: Color(0xFFFF8AB7),
    400: Color(0xFFF8589C),
    500: Color(0xFFF42E84),
    600: Color(0xFFD81C70),
    700: Color(0xFFB5125B),
    800: Color(0xFF8E0846),
    900: Color(0xFF66032F),
  });

  static const background = Color(0xFF121217);
  static const surface = Color(0xFF1C1C22);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC9C9CE);
  static const error = Color(0xFFB82628);
  static const success = Color(0xFF49A837);
}

abstract final class AppTheme {
  /// Tema oscuro con roles explícitos, sin generación automática de colores.
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.background,
      primaryContainer: Color(0xFF38259E),
      onPrimaryContainer: Color(0xFFF2EFFF),
      secondary: AppColors.secondary,
      onSecondary: AppColors.textPrimary,
      secondaryContainer: Color(0xFF4933C2),
      onSecondaryContainer: Color(0xFFF2EFFF),
      tertiary: AppColors.pulse,
      onTertiary: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: Color(0xFF07070A),
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: Color(0xFF2E2E36),
      surfaceContainerHighest: Color(0xFF4A4A54),
      outline: Color(0xFF9A9AA3),
      outlineVariant: Color(0xFF4A4A54),
      error: Color(0xFFF79FA0),
      onError: Color(0xFF3D0B0C),
      errorContainer: AppColors.error,
      onErrorContainer: Color(0xFFFFECEC),
    );
    final textTheme = GoogleFonts.lexendTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 102,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 43,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 33,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.25,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.4,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
        ),
      ),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
