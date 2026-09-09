import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/vocabulary_item.dart';

const _vocabularyAssetPath = 'assets/data/vocabulary.json';

/// Nombre del subdirectorio, dentro del directorio de documentos de la app,
/// donde se guardan los packs de vocabulario descargados.
const packsDirectoryName = 'vocabulary_packs';

/// Permite a los tests de widgets omitir la lectura de packs descargados:
/// los tests no deben depender de I/O de archivos real (ver
/// `test/widget_test.dart`), que además no puede completarse de forma
/// fiable dentro del reloj simulado de flutter_test.
@visibleForTesting
bool debugSkipDownloadedPacks = false;

Future<List<VocabularyItem>> loadVocabulary() async {
  final baseItems = await _loadBaseVocabulary();
  final downloadedItems = await _loadDownloadedPacks();

  final byId = <String, VocabularyItem>{};
  for (final item in [...baseItems, ...downloadedItems]) {
    byId[item.id] = item;
  }
  return byId.values.toList();
}

Future<List<VocabularyItem>> _loadBaseVocabulary() async {
  final raw = await rootBundle.loadString(_vocabularyAssetPath);
  return _parseItems(raw);
}

Future<List<VocabularyItem>> _loadDownloadedPacks() async {
  if (debugSkipDownloadedPacks) return const [];

  final directory = await _packsDirectory();
  if (!await directory.exists()) return const [];

  final items = <VocabularyItem>[];
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final raw = await entity.readAsString();
    items.addAll(_parseItems(raw));
  }
  return items;
}

List<VocabularyItem> _parseItems(String raw) {
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((item) => VocabularyItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<Directory> _packsDirectory() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return Directory('${documentsDir.path}/$packsDirectoryName');
}
