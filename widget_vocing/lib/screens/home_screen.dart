import 'package:flutter/material.dart';

import '../models/vocabulary_item.dart';
import '../services/pack_service.dart';
import '../services/vocabulary_state_service.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stateService = const VocabularyStateService();
  VocabularyStateSnapshot? _snapshot;

  List<VocabularyItem>? get _items => _snapshot?.items;
  VocabularyItem? get _currentItem => _snapshot?.currentItem;
  bool get _hasHistory => _snapshot?.historyIds.isNotEmpty ?? false;
  List<VocabularyItem> get _activeItems => _snapshot?.activeItems ?? const [];

  @override
  void initState() {
    super.initState();
    _stateService.loadState().then((snapshot) {
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      _checkForNewPacks();
    });
  }

  Future<void> _checkForNewPacks() async {
    final newPacks = await checkForNewUndismissedPacks();
    if (newPacks.isEmpty || !mounted) return;

    final totalWords = newPacks.fold<int>(0, (sum, pack) => sum + pack.wordCount);
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
    final snapshot = await _stateService.goToNextWord();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _showPreviousWord() async {
    final snapshot = await _stateService.goToPreviousWord();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  Future<void> _markCurrentAsLearned() async {
    final snapshot = await _stateService.markCurrentAsLearned();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final current = _currentItem;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget VocIng')),
      drawer: const AppDrawer(currentScreen: AppScreen.home),
      body: Center(
        child: items == null
            ? const CircularProgressIndicator()
            : current == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '¡Has aprendido todas las palabras disponibles!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                            child: child,
                          ),
                        ),
                        child: VocabularyCard(
                          key: ValueKey(current.id),
                          item: current,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _markCurrentAsLearned,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Marcar como aprendida'),
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
                  onPressed:
                      current == null || _activeItems.length <= 1
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

class VocabularyCard extends StatelessWidget {
  const VocabularyCard({super.key, required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.word,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '/${item.pronunciation}/',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              item.translation,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              '“${item.example}”',
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
