import 'package:flutter_test/flutter_test.dart';
import 'package:widget_vocing/l10n/app_locale.dart';
import 'package:widget_vocing/l10n/app_strings.dart';
import 'package:widget_vocing/models/language_course.dart';
import 'package:widget_vocing/models/vocabulary_item.dart';

void main() {
  group('LanguageCourse', () {
    test('resuelve un curso por su id', () {
      expect(LanguageCourse.fromId('es_en'), LanguageCourse.esEn);
      expect(LanguageCourse.fromId('en_fr'), LanguageCourse.enFr);
    });

    test('cae al curso por defecto con un id nulo o desconocido', () {
      // Null = contenido publicado antes de que existieran los cursos, que
      // siempre fue ES→EN; desconocido = un curso retirado del catálogo.
      expect(LanguageCourse.fromId(null), defaultLanguageCourse);
      expect(LanguageCourse.fromId('de_ru'), defaultLanguageCourse);
      expect(defaultLanguageCourse, LanguageCourse.esEn);
    });

    test('el idioma de la UI es el idioma base del curso', () {
      expect(LanguageCourse.esEn.uiLocale, AppLocale.es);
      expect(LanguageCourse.enFr.uiLocale, AppLocale.en);
    });
  });

  group('VocabularyItem.fromJson', () {
    const json = {
      'id': 'test_0001',
      'word': 'RÉUSSIR',
      'pronunciation': 'ray-ew-SEER',
      'description': 'Mener quelque chose à bien.',
      'translation': 'To achieve something.',
      'example': 'Elle a réussi.',
    };

    test('sin campo course, la palabra se considera ES→EN', () {
      expect(VocabularyItem.fromJson(json).course, LanguageCourse.esEn);
    });

    test('con campo course, respeta el curso declarado', () {
      final item = VocabularyItem.fromJson({...json, 'course': 'en_fr'});
      expect(item.course, LanguageCourse.enFr);
    });
  });

  group('AppStrings', () {
    test('devuelve textos distintos por idioma', () {
      final es = appStringsFor(AppLocale.es);
      final en = appStringsFor(AppLocale.en);
      expect(es.markAsLearned, 'Marcar como aprendida');
      expect(en.markAsLearned, 'Mark as learned');
      expect(es.widgetAllLearned, isNot(en.widgetAllLearned));
    });

    test('pluraliza los conteos en los dos idiomas', () {
      final es = appStringsFor(AppLocale.es);
      final en = appStringsFor(AppLocale.en);
      expect(es.wordCount(1), '1 palabra');
      expect(es.wordCount(7), '7 palabras');
      expect(en.wordCount(1), '1 word');
      expect(en.wordCount(7), '7 words');
    });

    test('LocalizedText resuelve cada variante', () {
      const text = LocalizedText(es: 'Reno', en: 'Reindeer');
      expect(text.resolve(AppLocale.es), 'Reno');
      expect(text.resolve(AppLocale.en), 'Reindeer');
    });

    test('un idioma de sistema no soportado cae a español', () {
      expect(AppLocale.fromLanguageCode('fr'), AppLocale.es);
      expect(AppLocale.fromLanguageCode(null), AppLocale.es);
      expect(AppLocale.fromLanguageCode('en'), AppLocale.en);
    });
  });
}
