import 'package:shared_preferences/shared_preferences.dart';

const _learnedWordsPrefsKey = 'learned_word_ids';

/// Ids de [VocabularyItem] que el usuario marcó como aprendidas/dominadas.
/// Estas palabras se excluyen del pool de selección aleatoria en
/// `HomeScreen`, y se listan en la pantalla "Palabras aprendidas".
Future<Set<String>> getLearnedWordIds() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_learnedWordsPrefsKey)?.toSet() ?? {};
}

Future<void> markWordAsLearned(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await getLearnedWordIds();
  current.add(id);
  await prefs.setStringList(_learnedWordsPrefsKey, current.toList());
}

Future<void> unmarkWordAsLearned(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await getLearnedWordIds();
  current.remove(id);
  await prefs.setStringList(_learnedWordsPrefsKey, current.toList());
}
