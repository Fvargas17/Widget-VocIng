import 'dart:ui' show Locale;

/// Idiomas en los que puede estar la **interfaz** de la app. No es la lista de
/// idiomas que se estudian: eso lo define `LanguageCourse` (ver
/// `lib/models/language_course.dart`), y el idioma de la UI se deriva del
/// idioma base de cada curso. Por eso aquí no hay francés: ningún curso parte
/// del francés todavía.
enum AppLocale {
  es('es'),
  en('en');

  const AppLocale(this.code);

  /// Código ISO que se le pasa a `MaterialApp.locale`.
  final String code;

  Locale get flutterLocale => Locale(code);

  /// Resuelve un `Locale` de Flutter al idioma de la app, cayendo a [es]
  /// cuando el sistema pide uno que no soportamos.
  static AppLocale fromLanguageCode(String? languageCode) {
    for (final locale in values) {
      if (locale.code == languageCode) return locale;
    }
    return AppLocale.es;
  }
}

/// Un texto con sus dos variantes de idioma, ambas obligatorias por
/// constructor: así el compilador impide dejar una traducción a medias.
///
/// Se usa para los textos que viven dentro de un **catálogo de datos** (el
/// nombre de un preset de tema, de una mascota, de un curso) en vez de en
/// `AppStrings`, para que el nombre siga viviendo junto a la cosa que nombra
/// y agregar una entrada nueva al catálogo no implique tocar dos archivos.
class LocalizedText {
  const LocalizedText({required this.es, required this.en});

  final String es;
  final String en;

  String resolve(AppLocale locale) => switch (locale) {
    AppLocale.es => es,
    AppLocale.en => en,
  };
}
