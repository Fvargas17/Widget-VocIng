import 'package:flutter/material.dart';

/// Set común de roles semánticos que debe definir cada preset de tema.
/// Mantener esta lista corta y estable es lo que permite que agregar un
/// preset nuevo sea solo rellenar estos 7 colores — ver
/// `lib/theme/app_theme_builder.dart` para cómo se traducen a un
/// `ThemeData` completo, y `lib/theme/app_theme_preset.dart` para el
/// catálogo de presets.
@immutable
class AppThemeRoles {
  const AppThemeRoles({
    required this.primary,
    required this.accent,
    required this.background,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.softAccent,
  });

  /// Color de marca principal: FAB y acciones destacadas.
  final Color primary;

  /// Color secundario "de personalidad" del preset: AppBar.
  final Color accent;

  /// Fondo general del Scaffold.
  final Color background;

  /// Fondo de las Cards y del Drawer.
  final Color card;

  /// Color de texto principal.
  final Color text;

  /// Color de texto secundario (ej. pronunciación en `VocabularyCard`).
  final Color textSecondary;

  /// Acento suave para resaltados (ListTile seleccionado, contenedores
  /// secundarios, bordes sutiles).
  final Color softAccent;
}
