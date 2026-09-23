import 'package:flutter/material.dart';

import 'app_theme_roles.dart';

/// Construye un `ThemeData` (Material 3) completo a partir de los 7 roles
/// de [AppThemeRoles]. Todos los presets del catálogo pasan por aquí, así
/// que agregar un preset nuevo no requiere tocar esta función, solo definir
/// sus roles en `app_theme_preset.dart`.
ThemeData buildThemeFromRoles(AppThemeRoles roles) {
  final colorScheme = ColorScheme.light(
    primary: roles.primary,
    onPrimary: Colors.white,
    primaryContainer: roles.softAccent,
    onPrimaryContainer: roles.text,
    secondary: roles.accent,
    onSecondary: Colors.white,
    secondaryContainer: roles.softAccent,
    onSecondaryContainer: roles.text,
    surface: roles.background,
    onSurface: roles.text,
    surfaceContainer: roles.card,
    onSurfaceVariant: roles.textSecondary,
    outline: roles.softAccent,
  );

  final baseTextTheme = ThemeData.light().textTheme;
  final textTheme = baseTextTheme.copyWith(
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: roles.text,
    ),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: roles.text,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: roles.text),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: roles.text),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: roles.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: roles.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: roles.card,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.all(12),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: roles.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: roles.card,
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: roles.primary,
      selectedTileColor: roles.softAccent,
      iconColor: roles.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: roles.primary,
      linearTrackColor: roles.softAccent,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: roles.primary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: roles.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
