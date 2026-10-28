import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primary,
    tertiary: AppColors.tertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerLow: AppColors.surfaceContainerLow,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppText.roboto,
    scaffoldBackgroundColor: Colors.white,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(color: AppColors.outlineVariant, thickness: 0.5, space: 0.5),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.onSurface,
      contentTextStyle: AppText.small.copyWith(color: Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.primary),
  );
}
