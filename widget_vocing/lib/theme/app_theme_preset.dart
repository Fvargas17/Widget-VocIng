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
    required this.darkThemeData,
    this.cardGradient,
    this.darkCardGradient,
  });

  /// Id persistido en `shared_preferences`.
  final String id;

  /// Nombre visible en la pantalla de Configuración.
  final String displayName;

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
    cardGradient: _cardSkin(const Color(0xFFEBD8C3), const Color(0xFFEAD9BB)),
    darkThemeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF9DBB94),
        accent: Color(0xFF3E5236),
        background: Color(0xFF14180F),
        card: Color(0xFF20281A),
        text: Color(0xFFEDEBE3),
        textSecondary: Color(0xFFB8B6A9),
        softAccent: Color(0xFF33422C),
      ),
      brightness: Brightness.dark,
    ),
    darkCardGradient: _cardSkin(
      const Color(0xFF20281A),
      const Color(0xFF33422C),
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
    cardGradient: _cardSkin(const Color(0xFFFFFDF8), const Color(0xFFE4D8C6)),
    darkThemeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF9DBB94),
        accent: Color(0xFF4A3B2C),
        background: Color(0xFF1C1815),
        card: Color(0xFF272019),
        text: Color(0xFFEDE7DD),
        textSecondary: Color(0xFFB3A99B),
        softAccent: Color(0xFF3A3024),
      ),
      brightness: Brightness.dark,
    ),
    darkCardGradient: _cardSkin(
      const Color(0xFF272019),
      const Color(0xFF3A3024),
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
    cardGradient: _cardSkin(const Color(0xFFFFFCF7), const Color(0xFFE8D6C7)),
    darkThemeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF9DBB94),
        accent: Color(0xFF5C3226),
        background: Color(0xFF1B1512),
        card: Color(0xFF261C17),
        text: Color(0xFFEFE6DD),
        textSecondary: Color(0xFFB8A99C),
        softAccent: Color(0xFF452A20),
      ),
      brightness: Brightness.dark,
    ),
    darkCardGradient: _cardSkin(
      const Color(0xFF261C17),
      const Color(0xFF452A20),
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
    cardGradient: _cardSkin(const Color(0xFFFFFFFF), const Color(0xFFDED2C7)),
    darkThemeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF9DBB94),
        accent: Color(0xFF3D2E22),
        background: Color(0xFF17130F),
        card: Color(0xFF221B15),
        text: Color(0xFFECE4DA),
        textSecondary: Color(0xFFB2A89C),
        softAccent: Color(0xFF362B20),
      ),
      brightness: Brightness.dark,
    ),
    darkCardGradient: _cardSkin(
      const Color(0xFF221B15),
      const Color(0xFF362B20),
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
    cardGradient: _cardSkin(const Color(0xFFFFFFFF), const Color(0xFFD7E3DF)),
    darkThemeData: buildThemeFromRoles(
      const AppThemeRoles(
        primary: Color(0xFF9DBB94),
        accent: Color(0xFF1F3335),
        background: Color(0xFF10181A),
        card: Color(0xFF1B2427),
        text: Color(0xFFE4ECEB),
        textSecondary: Color(0xFFA9B8B6),
        softAccent: Color(0xFF253A3C),
      ),
      brightness: Brightness.dark,
    ),
    darkCardGradient: _cardSkin(
      const Color(0xFF1B2427),
      const Color(0xFF253A3C),
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
