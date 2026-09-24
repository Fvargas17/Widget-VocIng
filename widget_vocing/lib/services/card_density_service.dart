import 'package:shared_preferences/shared_preferences.dart';

const _cardDensityPrefsKey = 'card_density';

/// Tamaño visual de `VocabularyCard` y del widget nativo: `large` es el
/// tamaño original, `compact` reduce paddings y tipografía sin ocultar
/// contenido.
enum CardDensity { compact, large }

const CardDensity defaultCardDensity = CardDensity.large;

Future<CardDensity> getCardDensity() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_cardDensityPrefsKey);
  return stored == CardDensity.compact.name
      ? CardDensity.compact
      : defaultCardDensity;
}

Future<void> setCardDensity(CardDensity density) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cardDensityPrefsKey, density.name);
}
