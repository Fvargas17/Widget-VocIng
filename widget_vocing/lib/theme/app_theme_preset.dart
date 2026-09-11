import 'package:flutter/material.dart';

import 'app_theme_builder.dart';
import 'app_theme_roles.dart';

/// Un preset de tema seleccionable desde la pantalla de Configuración.
/// Agregar un preset nuevo es solo sumar una entrada a [appThemePresets]
/// con sus [AppThemeRoles] — [buildThemeFromRoles] arma el `ThemeData`.
@immutable
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.displayName,
    required this.themeData,
  });

  /// Id persistido en `shared_preferences`.
  final String id;

  /// Nombre visible en la pantalla de Configuración.
  final String displayName;

  final ThemeData themeData;
}

/// Catálogo de presets disponibles, en el orden en que se listan en
/// Configuración. Todos comparten el mismo verde salvia (`#8AA482`) como
/// `primary`, salvo "Serene Wellness" (el original, con su propio verde más
/// oscuro), y se diferencian por su color de acento/personalidad.
final List<AppThemePreset> appThemePresets = [
  AppThemePreset(
    id: 'serene_wellness',
    displayName: 'Serene Wellness',
    themeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF5C7A52),
        accent: Color(0xFF8AA482),
        background: Color(0xFF8AA482),
        card: Color(0xFFEBD8C3),
        text: Color(0xFF2B2B2B),
        textSecondary: Color(0xFF5C5C52),
        softAccent: Color(0xFFEAD9BB),
      ),
    ),
  ),
  AppThemePreset(
    id: 'cafe_claro',
    displayName: 'Café claro',
    themeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF8AA482),
        accent: Color(0xFFB89B7A),
        background: Color(0xFFF5F1E8),
        card: Color(0xFFFFFDF8),
        text: Color(0xFF3D3A34),
        textSecondary: Color(0xFF756F64),
        softAccent: Color(0xFFE4D8C6),
      ),
    ),
  ),
  AppThemePreset(
    id: 'terracota',
    displayName: 'Terracota',
    themeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF8AA482),
        accent: Color(0xFFB8755D),
        background: Color(0xFFF7F1E8),
        card: Color(0xFFFFFCF7),
        text: Color(0xFF39352F),
        textSecondary: Color(0xFF756D63),
        softAccent: Color(0xFFE8D6C7),
      ),
    ),
  ),
  AppThemePreset(
    id: 'cafe',
    displayName: 'Café',
    themeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF8AA482),
        accent: Color(0xFF7A5C48),
        background: Color(0xFFF3EFE8),
        card: Color(0xFFFFFFFF),
        text: Color(0xFF302A25),
        textSecondary: Color(0xFF756A61),
        softAccent: Color(0xFFDED2C7),
      ),
    ),
  ),
  AppThemePreset(
    id: 'azul_petroleo',
    displayName: 'Azul petróleo',
    themeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF8AA482),
        accent: Color(0xFF42666A),
        background: Color(0xFFF2F5F2),
        card: Color(0xFFFFFFFF),
        text: Color(0xFF26302E),
        textSecondary: Color(0xFF687471),
        softAccent: Color(0xFFD7E3DF),
      ),
    ),
  ),
];

const String defaultThemePresetId = 'serene_wellness';

/// Busca un preset por id; si no existe (p. ej. quedó guardado un id de un
/// preset que ya no está en el catálogo), cae al primero disponible.
AppThemePreset resolveThemePreset(String id) {
  return appThemePresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => appThemePresets.first,
  );
}
