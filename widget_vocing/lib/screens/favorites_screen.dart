import 'package:flutter/material.dart';

import '../data/vocabulary_repository.dart';
import '../models/vocabulary_item.dart';
import '../services/card_density_notifier.dart';
import '../services/card_density_service.dart';
import '../services/favorites_service.dart';
import '../services/sound_service.dart';
import '../services/theme_notifier.dart';
import '../theme/app_theme_preset.dart';
import '../widgets/app_drawer.dart';
import 'home_screen.dart' show VocabularyCard;

/// Repaso de las palabras marcadas con la estrella. Comparte el aspecto de
/// `HomeScreen` (misma `VocabularyCard`, mismos botones de navegación), pero
/// con tres diferencias deliberadas:
///
/// 1. El recorrido es **en el orden en que se agregaron** a favoritos, no
///    aleatorio, así que su posición es un simple índice local.
/// 2. **No excluye las palabras aprendidas** — una lista curada a mano no
///    debería vaciarse sola.
/// 3. No usa `VocabularyStateService`: su índice es propio y no altera la
///    palabra actual de Inicio ni la del widget nativo de Android.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<VocabularyItem>? _favoriteItems;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await loadVocabulary();
    final favoriteIds = await getFavoriteWordIds();
    final byId = {for (final item in items) item.id: item};

    // Se recorre la lista de ids (no la de items) para conservar el orden de
    // agregado; los ids cuya palabra ya no existe en el catálogo —p. ej. si
    // se eliminó el pack que la traía— simplemente se omiten.
    final favorites = [
      for (final id in favoriteIds)
        if (byId[id] != null) byId[id]!,
    ];

    if (!mounted) return;
    setState(() {
      _favoriteItems = favorites;
      _index = _index.clamp(0, favorites.isEmpty ? 0 : favorites.length - 1);
    });
  }

  void _goTo(int index) {
    playAppSound(AppSound.navigate);
    setState(() => _index = index);
  }

  Future<void> _removeCurrentFromFavorites() async {
    final current = _currentItem;
    if (current == null) return;
    playAppSound(AppSound.favorite);
    await removeFavoriteWord(current.id);
    if (!mounted) return;

    final remaining = [..._favoriteItems ?? const <VocabularyItem>[]]
      ..removeWhere((item) => item.id == current.id);
    setState(() {
      _favoriteItems = remaining;
      // Al quitar la última de la lista, el índice se pasaría del final.
      if (_index >= remaining.length) {
        _index = remaining.isEmpty ? 0 : remaining.length - 1;
      }
    });
  }

  VocabularyItem? get _currentItem {
    final favorites = _favoriteItems;
    if (favorites == null || favorites.isEmpty) return null;
    return favorites[_index];
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favoriteItems;
    return Scaffold(
      appBar: AppBar(title: const Text('Palabras favoritas')),
      drawer: const AppDrawer(currentScreen: AppScreen.favorites),
      body: favorites == null
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes palabras favoritas.\n'
                  'Marca la estrella de una tarjeta para agregarla aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          : SafeArea(child: _buildContent(context, favorites)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: favorites == null || favorites.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'prev_favorite_fab',
                  onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                  tooltip: 'Favorita anterior',
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 24),
                FloatingActionButton(
                  heroTag: 'next_favorite_fab',
                  onPressed: _index < favorites.length - 1
                      ? () => _goTo(_index + 1)
                      : null,
                  tooltip: 'Siguiente favorita',
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
    );
  }

  Widget _buildContent(BuildContext context, List<VocabularyItem> favorites) {
    final current = favorites[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<String>(
                value: current.id,
                isExpanded: true,
                items: [
                  for (final item in favorites)
                    DropdownMenuItem(value: item.id, child: Text(item.word)),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  _goTo(favorites.indexWhere((item) => item.id == id));
                },
              ),
              const SizedBox(height: 4),
              Text(
                favorites.length == 1
                    ? '1 palabra en favoritos'
                    : '${favorites.length} palabras en favoritos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            // El margen inferior deja libre la zona donde el Scaffold
            // superpone los dos FAB (`centerFloat`) sobre el body.
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: ValueListenableBuilder<CardDensity>(
                  valueListenable: cardDensityNotifier,
                  builder: (context, density, _) => VocabularyCard(
                    key: ValueKey(current.id),
                    item: current,
                    isFavorite: true,
                    onToggleFavorite: _removeCurrentFromFavorites,
                    density: density,
                    cardGradient: resolveThemePreset(
                      selectedThemePresetIdNotifier.value,
                    ).cardGradient,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
