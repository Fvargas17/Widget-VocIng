import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_vocing/models/language_course.dart';
import 'package:widget_vocing/models/vocabulary_item.dart';

/// Validaciones sobre los archivos de contenido del repo (packs base de
/// `assets/data/` e índice + packs de `content/packs/`).
///
/// Se leen con `dart:io` en vez de `rootBundle` a propósito: así el test no
/// toca canales de plataforma ni el reloj simulado de `flutter_test`, y puede
/// revisar también `content/packs/`, que no viaja como asset. El directorio de
/// trabajo al correr `flutter test` es la raíz del paquete.
void main() {
  final baseAssetPaths = {
    LanguageCourse.esEn: 'assets/data/vocabulary_es_en.json',
    LanguageCourse.enFr: 'assets/data/vocabulary_en_fr.json',
  };
  const packsDir = 'content/packs';

  List<Map<String, dynamic>> readItems(String path) {
    final raw = File(path).readAsStringSync();
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> readIndex() => (jsonDecode(
    File('$packsDir/index.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  test('cada curso tiene su pack base y todas sus palabras lo declaran', () {
    for (final course in LanguageCourse.values) {
      final path = baseAssetPaths[course];
      expect(path, isNotNull, reason: 'Falta el pack base de ${course.id}');
      final items = readItems(path!);
      expect(items, isNotEmpty);
      for (final json in items) {
        expect(
          json['course'],
          course.id,
          reason: '${json['id']} debería declarar course ${course.id}',
        );
      }
    }
  });

  test('el índice de packs es coherente con los archivos de cada pack', () {
    for (final entry in readIndex()) {
      final packId = entry['id'] as String;
      final file = entry['file'] as String;
      final course = LanguageCourse.fromId(entry['course'] as String?);

      expect(
        entry['course'],
        course.id,
        reason: '$packId tiene un course desconocido: ${entry['course']}',
      );

      final items = readItems('$packsDir/$file');
      expect(
        items.length,
        entry['wordCount'],
        reason: 'El wordCount de $packId no coincide con $file',
      );

      for (final json in items) {
        expect(
          json['course'],
          course.id,
          reason: '${json['id']} no coincide con el curso de $packId',
        );
        expect(
          json['id'] as String,
          startsWith('${packId}_'),
          reason: 'El id ${json['id']} no corresponde a $packId',
        );
      }
    }
  });

  test(
    'todas las palabras parsean y sus ids son únicos en todo el contenido',
    () {
      final seenIds = <String, String>{};
      final paths = [
        ...baseAssetPaths.values,
        for (final entry in readIndex()) '$packsDir/${entry['file'] as String}',
      ];

      for (final path in paths) {
        for (final json in readItems(path)) {
          final item = VocabularyItem.fromJson(json);
          expect(item.word, isNotEmpty);
          expect(item.pronunciation, isNotEmpty);
          expect(item.description, isNotEmpty);
          expect(item.translation, isNotEmpty);
          expect(item.example, isNotEmpty);

          final previous = seenIds[item.id];
          expect(
            previous,
            isNull,
            reason: 'El id ${item.id} está repetido ($previous y $path)',
          );
          seenIds[item.id] = path;
        }
      }
    },
  );

  test('cada pack ES→EN tiene su variante EN→FR con las mismas palabras', () {
    final index = readIndex();
    final byId = {for (final entry in index) entry['id'] as String: entry};

    final esEnPacks = index.where(
      (entry) =>
          LanguageCourse.fromId(entry['course'] as String?) ==
          LanguageCourse.esEn,
    );
    expect(esEnPacks, isNotEmpty);

    for (final entry in esEnPacks) {
      final packId = entry['id'] as String;
      // pack_000N ↔ pack_fr_000N
      final counterpartId = packId.replaceFirst('pack_', 'pack_fr_');
      final counterpart = byId[counterpartId];
      expect(
        counterpart,
        isNotNull,
        reason: 'Falta la variante en francés de $packId ($counterpartId)',
      );
      expect(
        counterpart!['wordCount'],
        entry['wordCount'],
        reason: '$counterpartId no tiene tantas palabras como $packId',
      );
    }
  });
}
