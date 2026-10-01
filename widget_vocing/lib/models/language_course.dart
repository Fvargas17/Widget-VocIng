import '../l10n/app_locale.dart';

/// Un curso de idioma: de qué idioma parte el usuario y cuál está aprendiendo.
/// Es lo que elige el toggle "Idioma" de Configuración, y determina dos cosas
/// a la vez:
///
/// 1. **Qué vocabulario se muestra** — `loadVocabulary()` filtra el catálogo
///    por este curso, así que pool aleatorio, widget nativo, favoritos y
///    aprendidas quedan separados por curso sin tocar sus servicios.
/// 2. **El idioma de la interfaz** — [uiLocale] es el idioma *base* del curso.
///    No hay un ajuste de idioma de UI aparte a propósito: si estudias francés
///    partiendo del inglés, la app entera está en inglés.
///
/// Convención de los campos de `VocabularyItem` según el curso:
///
/// | curso   | word    | pronunciation          | description | translation | example |
/// |---------|---------|------------------------|-------------|-------------|---------|
/// | `es_en` | inglés  | fonética en español    | inglés      | español     | inglés  |
/// | `en_fr` | francés | fonética en inglés     | francés     | inglés      | francés |
///
/// Es decir: `description` siempre va en el idioma que se aprende y
/// `translation` en el idioma del que se parte.
///
/// Agregar un curso = una entrada aquí + sus archivos de contenido con el
/// mismo `id` en el campo `course` de cada palabra.
///
/// Vive en `models/` (y no dentro de su service, como `Pet` o `CardDensity`)
/// porque `VocabularyItem` lo necesita y la capa de modelos no debe importar
/// servicios.
enum LanguageCourse {
  esEn(
    id: 'es_en',
    uiLocale: AppLocale.es,
    name: LocalizedText(es: 'Español → Inglés', en: 'Spanish → English'),
  ),
  enFr(
    id: 'en_fr',
    uiLocale: AppLocale.en,
    name: LocalizedText(es: 'Inglés → Francés', en: 'English → French'),
  );

  const LanguageCourse({
    required this.id,
    required this.uiLocale,
    required this.name,
  });

  /// Valor persistido en `shared_preferences` y escrito en el campo `course`
  /// de cada palabra de los JSON de contenido.
  final String id;

  /// Idioma base del curso, que es también el idioma de la interfaz.
  final AppLocale uiLocale;

  /// Nombre visible en el selector de Configuración.
  final LocalizedText name;

  /// Busca un curso por su [id]; cae a [defaultLanguageCourse] cuando el id
  /// es nulo (contenido viejo sin el campo `course`, que siempre fue ES→EN) o
  /// desconocido (un curso que ya no existe en el catálogo).
  static LanguageCourse fromId(String? id) {
    for (final course in values) {
      if (course.id == id) return course;
    }
    return defaultLanguageCourse;
  }
}

const LanguageCourse defaultLanguageCourse = LanguageCourse.esEn;
