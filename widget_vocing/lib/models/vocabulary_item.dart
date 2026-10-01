import 'language_course.dart';

class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.word,
    required this.pronunciation,
    required this.description,
    required this.translation,
    required this.example,
    required this.course,
  });

  final String id;
  final String word;
  final String pronunciation;
  final String description;
  final String translation;
  final String example;

  /// Curso al que pertenece la palabra. Define en qué idioma está cada uno de
  /// los campos de arriba (ver la tabla en [LanguageCourse]) y hace que
  /// `loadVocabulary()` la incluya solo cuando ese curso está activo.
  final LanguageCourse course;

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      id: json['id'] as String,
      word: json['word'] as String,
      pronunciation: json['pronunciation'] as String,
      description: json['description'] as String,
      translation: json['translation'] as String,
      example: json['example'] as String,
      // `course` ausente → ES→EN: los packs descargados antes de esta etapa
      // no traen el campo, y todo el contenido de entonces era inglés.
      course: LanguageCourse.fromId(json['course'] as String?),
    );
  }
}
