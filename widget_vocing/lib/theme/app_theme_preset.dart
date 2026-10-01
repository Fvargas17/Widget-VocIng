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
    required this.roles,
    required this.darkRoles,
    required this.themeData,
    required this.darkThemeData,
    this.cardGradient,
    this.darkCardGradient,
  });

  /// Id persistido en `shared_preferences`.
  final String id;

  /// Nombre visible en la pantalla de Configuración.
  final String displayName;

  /// Los 7 roles crudos de la variante clara, antes de pasar por
  /// [buildThemeFromRoles]. Se conservan aparte de [themeData] porque
  /// consumidores fuera del árbol de widgets (el widget nativo de Android,
  /// que no puede leer `Theme.of(context)`) necesitan los colores planos,
  /// no un `ThemeData`.
  final AppThemeRoles roles;

  /// Equivalente a [roles] para la variante oscura.
  final AppThemeRoles darkRoles;

  final ThemeData themeData;

  /// Variante oscura del mismo preset — misma identidad de color (primary/
  /// accent), pero fondo/card/texto invertidos para "Modo oscuro" en
  /// Configuración. Se activa con `darkModeNotifier`, independiente del
  /// preset elegido.
  final ThemeData darkThemeData;

  /// Degradado sutil de `card` a `softAccent` que usa `VocabularyCard` en vez
  /// de color plano. Vive aquí (no en `AppThemeRoles`) para no tocar el set
  /// fijo de 7 colores semánticos: es un dato *derivado*, no un rol nuevo.
  final Gradient? cardGradient;

  /// Equivalente a [cardGradient] para la variante oscura.
  final Gradient? darkCardGradient;
}

/// Construye el degradado sutil de un preset a partir de sus propios
/// [card]/[softAccent] — dos tonos que ya conviven en ese preset, así que el
/// degradado nunca desentona con el resto de la paleta.
LinearGradient _cardSkin(Color card, Color softAccent) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [card, softAccent],
  );
}

/// Arma un [AppThemePreset] completo a partir de sus roles claros/oscuros,
/// derivando `themeData`/`darkThemeData`/`cardGradient`/`darkCardGradient`
/// en un solo lugar — así el catálogo solo declara los 7+7 colores de cada
/// preset, sin repetirlos.
AppThemePreset _buildPreset({
  required String id,
  required String displayName,
  required AppThemeRoles roles,
  required AppThemeRoles darkRoles,
}) {
  return AppThemePreset(
    id: id,
    displayName: displayName,
    roles: roles,
    darkRoles: darkRoles,
    themeData: buildThemeFromRoles(roles),
    darkThemeData: buildThemeFromRoles(darkRoles, brightness: Brightness.dark),
    cardGradient: _cardSkin(roles.card, roles.softAccent),
    darkCardGradient: _cardSkin(darkRoles.card, darkRoles.softAccent),
  );
}

/// Catálogo de presets disponibles, en el orden en que se listan en
/// Configuración. Todos comparten el mismo verde salvia (`#8AA482`) como
/// `primary`, salvo "Serene Wellness" (el original, con su propio verde más
/// oscuro), y se diferencian por su color de acento/personalidad.
final List<AppThemePreset> appThemePresets = [
  _buildPreset(
    id: 'serene_wellness',
    displayName: 'Bosque Luminoso',
    roles: const AppThemeRoles(
      primary: Color(0xFF0E9E97),
      accent: Color(0xFFC97F22),
      background: Color(0xFFEAF6F4),
      card: Color(0xFFF4FBFA),
      text: Color(0xFF0B2624),
      textSecondary: Color(0xFF4C7570),
      softAccent: Color(0xFFCFEAE6),
    ),
    darkRoles: const AppThemeRoles(
      primary: Color(0xFF35D6CE),
      accent: Color(0xFF8C5A1E),
      background: Color(0xFF081F1D),
      card: Color(0xFF113A36),
      text: Color(0xFFEAFBF9),
      textSecondary: Color(0xFF86B8B2),
      softAccent: Color(0xFF1E5750),
    ),
  ),
  _buildPreset(
    id: 'cafe_claro',
    displayName: 'Café claro',
    roles: const AppThemeRoles(
      primary: Color(0xFF8AA482),
      accent: Color(0xFFB89B7A),
      background: Color(0xFFF5F1E8),
      card: Color(0xFFFFFDF8),
      text: Color(0xFF3D3A34),
      textSecondary: Color(0xFF756F64),
      softAccent: Color(0xFFE4D8C6),
    ),
    darkRoles: const AppThemeRoles(
      primary: Color(0xFF9DBB94),
      accent: Color(0xFF4A3B2C),
      background: Color(0xFF1C1815),
      card: Color(0xFF272019),
      text: Color(0xFFEDE7DD),
      textSecondary: Color(0xFFB3A99B),
      softAccent: Color(0xFF3A3024),
    ),
  ),
  _buildPreset(
    id: 'terracota',
    displayName: 'Terracota',
    roles: const AppThemeRoles(
      primary: Color(0xFF8AA482),
      accent: Color(0xFFB8755D),
      background: Color(0xFFF7F1E8),
      card: Color(0xFFFFFCF7),
      text: Color(0xFF39352F),
      textSecondary: Color(0xFF756D63),
      softAccent: Color(0xFFE8D6C7),
    ),
    darkRoles: const AppThemeRoles(
      primary: Color(0xFF9DBB94),
      accent: Color(0xFF5C3226),
      background: Color(0xFF1B1512),
      card: Color(0xFF261C17),
      text: Color(0xFFEFE6DD),
      textSecondary: Color(0xFFB8A99C),
      softAccent: Color(0xFF452A20),
    ),
  ),
  _buildPreset(
    id: 'cafe',
    displayName: 'Café',
    roles: const AppThemeRoles(
      primary: Color(0xFF8AA482),
      accent: Color(0xFF7A5C48),
      background: Color(0xFFF3EFE8),
      card: Color(0xFFFFFFFF),
      text: Color(0xFF302A25),
      textSecondary: Color(0xFF756A61),
      softAccent: Color(0xFFDED2C7),
    ),
    darkRoles: const AppThemeRoles(
      primary: Color(0xFF9DBB94),
      accent: Color(0xFF3D2E22),
      background: Color(0xFF17130F),
      card: Color(0xFF221B15),
      text: Color(0xFFECE4DA),
      textSecondary: Color(0xFFB2A89C),
      softAccent: Color(0xFF362B20),
    ),
  ),
  _buildPreset(
    id: 'azul_petroleo',
    displayName: 'Azul petróleo',
    roles: const AppThemeRoles(
      primary: Color(0xFF8AA482),
      accent: Color(0xFF42666A),
      background: Color(0xFFF2F5F2),
      card: Color(0xFFFFFFFF),
      text: Color(0xFF26302E),
      textSecondary: Color(0xFF687471),
      softAccent: Color(0xFFD7E3DF),
    ),
    darkRoles: const AppThemeRoles(
      primary: Color(0xFF9DBB94),
      accent: Color(0xFF1F3335),
      background: Color(0xFF10181A),
      card: Color(0xFF1B2427),
      text: Color(0xFFE4ECEB),
      textSecondary: Color(0xFFA9B8B6),
      softAccent: Color(0xFF253A3C),
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

/// `cardGradient` o `darkCardGradient` del preset [presetId] según
/// [darkModeEnabled] — la misma elección que hace `WidgetVocIngApp` para el
/// `ThemeData`, pero para el degradado que `VocabularyCard` no puede leer
/// desde `Theme.of(context)`.
Gradient? resolveActiveCardGradient(String presetId, bool darkModeEnabled) {
  final preset = resolveThemePreset(presetId);
  return darkModeEnabled ? preset.darkCardGradient : preset.cardGradient;
}

/// `roles` o `darkRoles` del preset [presetId] según [darkModeEnabled] — los
/// mismos 7 colores planos que arman su `ThemeData`, para consumidores que no
/// pueden leer `Theme.of(context)` (el widget nativo de Android, vía
/// `VocabularyStateService`).
AppThemeRoles resolveActiveThemeRoles(String presetId, bool darkModeEnabled) {
  final preset = resolveThemePreset(presetId);
  return darkModeEnabled ? preset.darkRoles : preset.roles;
}
