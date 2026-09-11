import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme_preset.dart';

const _themePresetPrefsKey = 'selected_theme_preset_id';

/// Id del preset de tema elegido por el usuario en Configuración. Si no hay
/// ninguno guardado todavía, retorna [defaultThemePresetId].
Future<String> getSelectedThemePresetId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_themePresetPrefsKey) ?? defaultThemePresetId;
}

Future<void> setSelectedThemePresetId(String presetId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themePresetPrefsKey, presetId);
}
