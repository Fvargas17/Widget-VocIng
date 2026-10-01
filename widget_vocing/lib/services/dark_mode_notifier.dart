import 'package:flutter/foundation.dart';

import 'dark_mode_service.dart';

/// Si el modo oscuro está activo actualmente. `SettingsScreen` lo actualiza
/// al alternar "Modo oscuro" y `WidgetVocIngApp` (en `main.dart`) lo escucha
/// para elegir entre `themeData` y `darkThemeData` del preset activo.
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(
  defaultDarkModeEnabled,
);
