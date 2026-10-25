import 'package:flutter/material.dart';

class AppSpacing {
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing28 = 28;
  static const double spacing32 = 32;
  static const double spacing36 = 36;
  static const double spacing40 = 40;
  static const double spacing44 = 44;
  static const double spacing48 = 48;
  static const double spacing52 = 52;
  static const double spacing56 = 56;
  static const double spacing60 = 60;
  static const double spacing64 = 64;
  static const double spacing68 = 68;
  static const double spacing72 = 72;
}

class AppRadius {
  static const double radius50 = 0;
  static const double radius100 = 4;
  static const double radius200 = 8;
  static const double radius300 = 12;
  static const double radius400 = 16;
  static const double radius500 = 24;
  static const double radius600 = 32;
}

class AppTypography {
  //HEADLINE
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle headline2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle subtitle1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle subtitle2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label1 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle label2 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

class AppColors {
  //PRIMARY
  static const primary50 = Color(0xFFF2EFFF);
  static const primary100 = Color(0xFFE4DFFF);
  static const primary200 = Color(0xFFC4B8FF);
  static const primary300 = Color(0xFFA99AFF);
  static const primary400 = Color(0xFF8977FF);
  static const primary500 = Color(0xFF7157FF); //base
  static const primary600 = Color(0xFF5C45E5);
  static const primary700 = Color(0xFF4936C2);
  static const primary800 = Color(0xFF382B95);
  static const primary900 = Color(0xFF271F73);

  //SECONDARY
  static const secondary50 = Color(0xFFF2EFFF);
  static const secondary100 = Color(0xFFE4DFFF);
  static const secondary200 = Color(0xFFC4B8FF);
  static const secondary300 = Color(0xFFA99AFF);
  static const secondary400 = Color(0xFF8977FF);
  static const secondary500 = Color(0xFF7157FF);
  static const secondary600 = Color(0xFF5C45E5);
  static const secondary700 = Color(0xFF4936C2);
  static const secondary800 = Color(0xFF382B95);
  static const secondary900 = Color(0xFF1F1773); // BASE

  // NEUTRAL
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8F8F7);
  static const neutral100 = Color(0xFFE6E5E4);
  static const neutral200 = Color(0xFFCCCCBC);
  static const neutral300 = Color(0xFFA9A9AA);
  static const neutral400 = Color(0xFF7D7D80);
  static const neutral500 = Color(0xFF5A5A5F);
  static const neutral600 = Color(0xFF424247);
  static const neutral700 = Color(0xFF2C2C32);
  static const neutral800 = Color(0xFF1C1C22); // BASE
  static const neutral900 = Color(0xFF0D0D0A);

  // ECHO
  static const echo50 = Color(0xFFFFE1EB);
  static const echo100 = Color(0xFFFFE0D1);
  static const echo200 = Color(0xFFFFC4A8);
  static const echo300 = Color(0xFFFFA17D);
  static const echo400 = Color(0xFFFF815C);
  static const echo500 = Color(0xFFFF6630); // BASE
  static const echo600 = Color(0xFFE84F18);
  static const echo700 = Color(0xFFC43F10);
  static const echo800 = Color(0xFF9E350D);
  static const echo900 = Color(0xFF7D2B0D);

  // PULSE
  static const pulse50 = Color(0xFFF3FFE1);
  static const pulse100 = Color(0xFFE7FFC1);
  static const pulse200 = Color(0xFFD2FB8D);
  static const pulse300 = Color(0xFFBDF65A);
  static const pulse400 = Color(0xFFA9EC35);
  static const pulse500 = Color(0xFF8DDC29); // BASE
  static const pulse600 = Color(0xFF70BE20);
  static const pulse700 = Color(0xFF55951D);
  static const pulse800 = Color(0xFF44751C);
  static const pulse900 = Color(0xFF365E19);

  // BLOOM
  static const bloom50 = Color(0xFFFFEFF5);
  static const bloom100 = Color(0xFFFFDCEB);
  static const bloom200 = Color(0xFFFFB3D1);
  static const bloom300 = Color(0xFFFF8AB7);
  static const bloom400 = Color(0xFFFF5C9C);
  static const bloom500 = Color(0xFFFF2E88); // BASE
  static const bloom600 = Color(0xFFDB1E70);
  static const bloom700 = Color(0xFFB61558);
  static const bloom800 = Color(0xFF921147);
  static const bloom900 = Color(0xFF6D0C37);

  // ERRORS
  static const error50 = Color(0xFFFFECEC);
  static const error100 = Color(0xFFFFCACA);
  static const error200 = Color(0xFFFF9999);
  static const error300 = Color(0xFFF76F72);
  static const error400 = Color(0xFFEB484B);
  static const error500 = Color(0xFFE03032);
  static const error600 = Color(0xFFC1262B); // BASE
  static const error700 = Color(0xFF9F1F20);
  static const error800 = Color(0xFF7A1819);
  static const error900 = Color(0xFF530E0E);

  // SUCCESS
  static const success50 = Color(0xFFF1FBEF);
  static const success100 = Color(0xFFD9F3D4);
  static const success200 = Color(0xFFB5E5AA);
  static const success300 = Color(0xFF8BD87B);
  static const success400 = Color(0xFF6BCD5B);
  static const success500 = Color(0xFF52C642);
  static const success600 = Color(0xFF3EAA37); // BASE
  static const success700 = Color(0xFF347E27);
  static const success800 = Color(0xFF285F1F);
  static const success900 = Color(0xFF0F280A);

  // INFO
  static const info50 = Color(0xFFE8F5FF);
  static const info100 = Color(0xFFC8E8FF);
  static const info200 = Color(0xFF9DD5F9);
  static const info300 = Color(0xFF72C2F0);
  static const info400 = Color(0xFF55B9E8);
  static const info500 = Color(0xFF45B0E9); // BASE
  static const info600 = Color(0xFF269BE0);
  static const info700 = Color(0xFF1E77C0);
  static const info800 = Color(0xFF185A98);
  static const info900 = Color(0xFF0D3261);

  // WARNING
  static const warning50 = Color(0xFFFFE4E1);
  static const warning100 = Color(0xFFFFE5BA);
  static const warning200 = Color(0xFFFFD18D);
  static const warning300 = Color(0xFFFFBD63);
  static const warning400 = Color(0xFFFFAB42); // BASE
  static const warning500 = Color(0xFFF5A11A);
  static const warning600 = Color(0xFFFD88A1);
  static const warning700 = Color(0xFFFAD701);
  static const warning800 = Color(0xFF7D5010);
  static const warning900 = Color(0xFF4E2F0D);
}

// TEMA AUDIOMACK (FUERA de la clase AppColors)
final ThemeData audioMack = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    // PRIMARY
    primary: AppColors.primary500,
    onPrimary: AppColors.neutral0,

    primaryContainer: AppColors.primary800,
    onPrimaryContainer: AppColors.primary50,

    primaryFixed: AppColors.primary500,
    primaryFixedDim: AppColors.primary600,

    onPrimaryFixed: AppColors.neutral0,
    onPrimaryFixedVariant: AppColors.primary50,

    // SECONDARY
    secondary: AppColors.secondary900,
    onSecondary: AppColors.neutral0,

    secondaryContainer: AppColors.secondary700,
    onSecondaryContainer: AppColors.neutral0,

    secondaryFixed: AppColors.secondary500,
    secondaryFixedDim: AppColors.secondary700,

    onSecondaryFixed: AppColors.neutral0,
    onSecondaryFixedVariant: AppColors.secondary50,

    // ERROR
    error: AppColors.error600,
    onError: AppColors.neutral0,

    errorContainer: AppColors.error800,
    onErrorContainer: AppColors.error50,

    // SURFACE
    surface: AppColors.neutral800,
    onSurface: AppColors.neutral0,

    surfaceDim: AppColors.neutral900,
    surfaceBright: AppColors.neutral700,

    surfaceContainerLowest: AppColors.neutral900,
    surfaceContainerLow: AppColors.neutral800,
    surfaceContainer: AppColors.neutral700,
    surfaceContainerHigh: AppColors.neutral600,
    surfaceContainerHighest: AppColors.neutral500,

    onSurfaceVariant: AppColors.neutral200,

    outline: AppColors.neutral500,
    outlineVariant: AppColors.neutral700,
  ),
);
