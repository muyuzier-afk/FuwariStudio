import 'package:flutter/material.dart';

ThemeData buildAppTheme({
  required Brightness brightness,
  required Color seedColor,
  required bool useMiSansFont,
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  const miSansFallback = <String>[
    'Noto Sans SC',
    'PingFang SC',
    'Microsoft YaHei',
    'Segoe UI',
    'Roboto',
  ];

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: useMiSansFont ? 'MiSans' : null,
    fontFamilyFallback: useMiSansFont ? miSansFallback : null,
    scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
    cardColor: isDark ? const Color(0xFF0B0B0B) : Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? Colors.black : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: isDark ? 0 : 0.4,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
