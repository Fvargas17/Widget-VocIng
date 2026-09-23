import 'package:shared_preferences/shared_preferences.dart';

const _favoriteWordsPrefsKey = 'favorite_word_ids';

/// Ids de [VocabularyItem] que el usuario marcó con la estrella de favoritos,
/// **en el orden en que los fue agregando** — por eso se maneja como `List` y
/// no como `Set` (a diferencia de `learned_words_service.dart`, donde el orden
/// no importa): la pantalla "Palabras favoritas" recorre esa lista tal cual,
/// sin aleatoriedad.
///
/// Es estado paralelo e independiente del de `VocabularyStateService`: marcar
/// una palabra como favorita no cambia la palabra visible ni el historial, y
/// las favoritas se listan aunque ya estén aprendidas.
Future<List<String>> getFavoriteWordIds() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_favoriteWordsPrefsKey) ?? const [];
}

Future<void> addFavoriteWord(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final current = [...await getFavoriteWordIds()];
  if (current.contains(id)) return;
  current.add(id);
  await prefs.setStringList(_favoriteWordsPrefsKey, current);
}

Future<void> removeFavoriteWord(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final current = [...await getFavoriteWordIds()]..remove(id);
  await prefs.setStringList(_favoriteWordsPrefsKey, current);
}

/// Alterna el estado de favorito de [id] y devuelve el estado resultante
/// (`true` si quedó marcada).
Future<bool> toggleFavoriteWord(String id) async {
  final current = await getFavoriteWordIds();
  if (current.contains(id)) {
    await removeFavoriteWord(id);
    return false;
  }
  await addFavoriteWord(id);
  return true;
}
