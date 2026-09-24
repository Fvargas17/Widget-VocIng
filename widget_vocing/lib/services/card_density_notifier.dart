import 'package:flutter/foundation.dart';

import 'card_density_service.dart';

/// Densidad de tarjeta activa actualmente. `SettingsScreen` lo actualiza al
/// alternar "Modo compacto" y `HomeScreen`/`FavoritesScreen` lo escuchan para
/// redibujar `VocabularyCard` sin pasar por Navigator.
final ValueNotifier<CardDensity> cardDensityNotifier = ValueNotifier<
  CardDensity
>(defaultCardDensity);
