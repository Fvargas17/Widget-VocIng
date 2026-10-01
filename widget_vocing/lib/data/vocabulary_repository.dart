import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/language_course.dart';
import '../models/vocabulary_item.dart';

/// Pack base embebido de cada curso. Agregar un curso = sumar su archivo aquí
/// (y en `pubspec.yaml` basta con que viva dentro de `assets/data/`).
const Map<LanguageCourse, String> _vocabularyAssetPaths = {
  LanguageCourse.esEn: 'assets/data/vocabulary_es_en.json',
  LanguageCourse.enFr: 'assets/data/vocabulary_en_fr.json',
};

/// Nombre del subdirectorio, dentro del directorio de documentos de la app,
/// donde se guardan los packs de vocabulario descargados.
const packsDirectoryName = 'vocabulary_packs';

/// Permite a los tests de widgets omitir la lectura de packs descargados:
/// los tests no deben depender de I/O de archivos real (ver
/// `test/widget_test.dart`), que además no puede completarse de forma
/// fiable dentro del reloj simulado de flutter_test.
@visibleForTesting
bool debugSkipDownloadedPacks = false;

/// Catálogo de palabras del curso [course]: su pack base embebido más los
/// packs descargados de ese mismo curso, deduplicando por `id`.
///
/// El curso es un parámetro requerido (y no una lectura interna de
/// `getLanguageCourse()`) para que el isolate headless del widget nativo
/// decida explícitamente con qué curso trabaja: ahí hay que leer las prefs
/// con `reload()` antes (ver `VocabularyStateService`).
Future<List<VocabularyItem>> loadVocabulary(LanguageCourse course) async {
  final baseItems = await _loadBaseVocabulary(course);
  final downloadedItems = await _loadDownloadedPacks(course);

  final byId = <String, VocabularyItem>{};
  for (final item in [...baseItems, ...downloadedItems]) {
    byId[item.id] = item;
  }
  return byId.values.toList();
}

Future<List<VocabularyItem>> _loadBaseVocabulary(LanguageCourse course) async {
  final raw = await rootBundle.loadString(_vocabularyAssetPaths[course]!);
  return _parseItems(raw, course);
}

Future<List<VocabularyItem>> _loadDownloadedPacks(LanguageCourse course) async {
  if (debugSkipDownloadedPacks) return const [];

  final directory = await _packsDirectory();
  if (!await directory.exists()) return const [];

  final items = <VocabularyItem>[];
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final raw = await entity.readAsString();
    items.addAll(_parseItems(raw, course));
  }
  return items;
}

/// Parsea un archivo de contenido y deja solo las palabras de [course]. El
/// filtro va aquí (y no en el nombre del archivo) porque los packs
/// descargados se descubren escaneando el directorio: el escaneo no sabe de
/// cursos, pero cada palabra sí declara el suyo.
List<VocabularyItem> _parseItems(String raw, LanguageCourse course) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((item) => VocabularyItem.fromJson(item as Map<String, dynamic>))
      .where((item) => item.course == course)
      .toList();
}

Future<Directory> _packsDirectory() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return Directory('${documentsDir.path}/$packsDirectoryName');
}
