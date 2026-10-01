import 'package:flutter/foundation.dart';

import '../models/language_course.dart';

/// Curso de idioma activo. `SettingsScreen` lo actualiza al elegir otro
/// idioma y `WidgetVocIngApp` lo escucha para reconstruir la `MaterialApp`
/// con el `locale` nuevo — igual que `selectedThemePresetIdNotifier` y
/// `darkModeNotifier`, porque cambiar de curso cambia toda la UI, no solo una
/// pantalla.
final ValueNotifier<LanguageCourse> languageCourseNotifier =
    ValueNotifier<LanguageCourse>(defaultLanguageCourse);
