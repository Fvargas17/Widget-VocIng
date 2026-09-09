import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/vocabulary_item.dart';

const _vocabularyAssetPath = 'assets/data/vocabulary.json';

Future<List<VocabularyItem>> loadVocabulary() async {
  final raw = await rootBundle.loadString(_vocabularyAssetPath);
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((item) => VocabularyItem.fromJson(item as Map<String, dynamic>))
      .toList();
}
