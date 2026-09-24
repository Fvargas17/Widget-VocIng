import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vocabulary_item.dart';
import '../services/card_density_notifier.dart';
import '../services/card_density_service.dart';
import '../services/favorites_service.dart';
import '../services/pack_service.dart';
import '../services/sound_service.dart';
import '../services/theme_notifier.dart';
import '../services/vocabulary_state_service.dart';
import '../theme/app_theme_preset.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stateService = const VocabularyStateService();
  VocabularyStateSnapshot? _snapshot;
  Set<String> _favoriteIds = {};
  bool _showLearnedFeedback = false;
  Timer? _learnedFeedbackTimer;

  List<VocabularyItem>? get _items => _snapshot?.items;
  VocabularyItem? get _currentItem => _snapshot?.currentItem;
  bool get _hasHistory => _snapshot?.historyIds.isNotEmpty ?? false;
  List<VocabularyItem> get _activeItems => _snapshot?.activeItems ?? const [];

  @override
  void dispose() {
    _learnedFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _stateService.loadState().then((snapshot) {
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      _checkForNewPacks();
    });
    getFavoriteWordIds().then((ids) {
      if (!mounted) return;
      setState(() => _favoriteIds = ids.toSet());
    });
  }

  Future<void> _checkForNewPacks() async {
    final newPacks = await checkForNewUndismissedPacks();
    if (newPacks.isEmpty || !mounted) return;

    final totalWords = newPacks.fold<int>(
      0,
      (sum, pack) => sum + pack.wordCount,
    );
    final packNames = newPacks.map((pack) => pack.name).join(', ');

    final shouldViewPacks = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contenido nuevo disponible'),
        content: Text(
          'Hay $totalWords palabras nuevas disponibles ($packNames). '
          'Puedes descargarlas desde Administrar packs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ver'),
          ),
        ],
      ),
    );

    await dismissPacks(newPacks);
    if (!mounted || shouldViewPacks != true) return;

    await Navigator.of(context).pushNamed('/packs');
    if (!mounted) return;

    final refreshed = await _stateService.peekState();
    if (!mounted) return;
    setState(() => _snapshot = refreshed);
  }

  Future<void> _showNextWord() async {
    playAppSound(AppSound.navigate);
    final snapshot = await _stateService.goToNextWord();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _showPreviousWord() async {
    playAppSound(AppSound.navigate);
    final snapshot = await _stateService.goToPreviousWord();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _markCurrentAsLearned() async {
    playAppSound(AppSound.learned);
    final snapshot = await _stateService.markCurrentAsLearned();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
    _flashLearnedFeedback();
  }

  Future<void> _toggleFavorite() async {
    final current = _currentItem;
    if (current == null) return;
    playAppSound(AppSound.favorite);
    final isFavorite = await toggleFavoriteWord(current.id);
    if (!mounted) return;
    setState(() {
      if (isFavorite) {
        _favoriteIds.add(current.id);
      } else {
        _favoriteIds.remove(current.id);
      }
    });
  }

  void _flashLearnedFeedback() {
    _learnedFeedbackTimer?.cancel();
    setState(() => _showLearnedFeedback = true);
    _learnedFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showLearnedFeedback = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final current = _currentItem;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget VocIng')),
      drawer: const AppDrawer(currentScreen: AppScreen.home),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : current == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '¡Has aprendido todas las palabras disponibles!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onDoubleTap: _markCurrentAsLearned,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.94,
                                      end: 1,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: ValueListenableBuilder<CardDensity>(
                              valueListenable: cardDensityNotifier,
                              builder: (context, density, _) => VocabularyCard(
                                key: ValueKey(current.id),
                                item: current,
                                isFavorite: _favoriteIds.contains(current.id),
                                onToggleFavorite: _toggleFavorite,
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
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 88),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LearnedFeedbackBadge(visible: _showLearnedFeedback),
                        FilledButton.icon(
                          onPressed: _markCurrentAsLearned,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Marcar como aprendida'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: items == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'prev_word_fab',
                  onPressed: _hasHistory ? _showPreviousWord : null,
                  tooltip: 'Palabra anterior',
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 24),
                FloatingActionButton(
                  heroTag: 'next_word_fab',
                  onPressed: current == null || _activeItems.length <= 1
                      ? null
                      : _showNextWord,
                  tooltip: 'Otra palabra',
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
    );
  }
}

/// Feedback visual breve al marcar una palabra como aprendida. Implementación
/// mínima a propósito (un texto que aparece y se desvanece) — para
/// reemplazarla por algo más elaborado más adelante solo hay que cambiar el
/// contenido de este widget, sin tocar el resto de `HomeScreen`.
class LearnedFeedbackBadge extends StatelessWidget {
  const LearnedFeedbackBadge({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '¡Aprendida!',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Tamaños derivados de [CardDensity]: en `compact` se reduce todo (margen,
/// padding, tipografía) a la mitad-ish sin ocultar ningún campo.
class _CardSizes {
  const _CardSizes({
    required this.margin,
    required this.paddingTop,
    required this.paddingRest,
    required this.wordFontSize,
    required this.pronunciationFontSize,
    required this.descriptionFontSize,
    required this.translationFontSize,
    required this.exampleFontSize,
    required this.gapAfterWord,
    required this.gapAfterPronunciation,
    required this.gapAfterDescription,
    required this.gapAfterTranslation,
  });

  factory _CardSizes.of(CardDensity density) {
    return density == CardDensity.compact
        ? const _CardSizes(
            margin: 12,
            paddingTop: 16,
            paddingRest: 16,
            wordFontSize: 22,
            pronunciationFontSize: 13,
            descriptionFontSize: 15,
            translationFontSize: 13,
            exampleFontSize: 13,
            gapAfterWord: 2,
            gapAfterPronunciation: 12,
            gapAfterDescription: 8,
            gapAfterTranslation: 12,
          )
        : const _CardSizes(
            margin: 24,
            paddingTop: 24,
            paddingRest: 24,
            wordFontSize: 30,
            pronunciationFontSize: 16,
            descriptionFontSize: 18,
            translationFontSize: 16,
            exampleFontSize: 16,
            gapAfterWord: 4,
            gapAfterPronunciation: 20,
            gapAfterDescription: 12,
            gapAfterTranslation: 20,
          );
  }

  final double margin;
  final double paddingTop;
  final double paddingRest;
  final double wordFontSize;
  final double pronunciationFontSize;
  final double descriptionFontSize;
  final double translationFontSize;
  final double exampleFontSize;
  final double gapAfterWord;
  final double gapAfterPronunciation;
  final double gapAfterDescription;
  final double gapAfterTranslation;
}

class VocabularyCard extends StatelessWidget {
  const VocabularyCard({
    super.key,
    required this.item,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.density = CardDensity.large,
    this.cardGradient,
  });

  final VocabularyItem item;
  final bool isFavorite;

  /// Si es `null`, la tarjeta se dibuja sin la estrella de favoritos.
  final VoidCallback? onToggleFavorite;

  final CardDensity density;

  /// Degradado sutil del preset activo. Si es `null`, la tarjeta usa el
  /// color plano que ya trae `CardThemeData`.
  final Gradient? cardGradient;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizes = _CardSizes.of(density);
    final cardTheme = Theme.of(context).cardTheme;
    final borderRadius =
        (cardTheme.shape as RoundedRectangleBorder?)?.borderRadius
            as BorderRadius? ??
        BorderRadius.circular(24);

    final content = Padding(
      // El padding superior es menor que el resto porque la estrella ya
      // aporta su propio margen visual arriba.
      padding: EdgeInsets.fromLTRB(
        sizes.paddingRest,
        onToggleFavorite == null ? sizes.paddingTop : sizes.paddingTop / 3,
        sizes.paddingRest,
        sizes.paddingRest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // La estrella ocupa su propia fila en vez de ir superpuesta en un
          // `Stack`: así nunca tapa palabras largas, y no queda parcialmente
          // fuera del área que recibe toques.
          if (onToggleFavorite != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onToggleFavorite,
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                tooltip: isFavorite
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.word,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sizes.wordFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: sizes.gapAfterWord),
          Text(
            '/${item.pronunciation}/',
            style: TextStyle(
              fontSize: sizes.pronunciationFontSize,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: sizes.gapAfterPronunciation),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: sizes.descriptionFontSize),
          ),
          SizedBox(height: sizes.gapAfterDescription),
          Text(
            item.translation,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: sizes.translationFontSize),
          ),
          SizedBox(height: sizes.gapAfterTranslation),
          Text(
            '“${item.example}”',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: sizes.exampleFontSize,
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.all(sizes.margin),
      color: cardGradient == null ? null : Colors.transparent,
      child: cardGradient == null
          ? content
          : Container(
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: borderRadius,
              ),
              child: content,
            ),
    );
  }
}
