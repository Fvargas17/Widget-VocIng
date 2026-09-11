import 'package:flutter/foundation.dart';

import '../theme/app_theme_preset.dart';

/// Id del preset de tema activo actualmente. `SettingsScreen` lo actualiza
/// al elegir un preset y `WidgetVocIngApp` (en `main.dart`) lo escucha para
/// reconstruir el `MaterialApp` con el tema correspondiente.
final ValueNotifier<String> selectedThemePresetIdNotifier =
    ValueNotifier<String>(defaultThemePresetId);
