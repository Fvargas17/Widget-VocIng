import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_course.dart';

const _languageCoursePrefsKey = 'selected_language_course';

/// Curso de idioma elegido en Configuración. Ver `LanguageCourse` para qué
/// implica (vocabulario que se muestra + idioma de la interfaz).
Future<LanguageCourse> getLanguageCourse() async {
  final prefs = await SharedPreferences.getInstance();
  return LanguageCourse.fromId(prefs.getString(_languageCoursePrefsKey));
}

Future<void> setLanguageCourse(LanguageCourse course) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_languageCoursePrefsKey, course.id);
}
