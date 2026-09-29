import 'package:shared_preferences/shared_preferences.dart';

const _darkModePrefsKey = 'dark_mode_enabled';

const bool defaultDarkModeEnabled = false;

Future<bool> getDarkModeEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_darkModePrefsKey) ?? defaultDarkModeEnabled;
}

Future<void> setDarkModeEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_darkModePrefsKey, enabled);
}
