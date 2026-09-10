import 'dart:math';

import 'package:flutter/material.dart';

import '../data/vocabulary_repository.dart';
import '../models/vocabulary_item.dart';
import '../services/learned_words_service.dart';
import '../services/pack_service.dart';
import '../widgets/app_drawer.dart';

/// Máximo de palabras previas que se recuerdan en memoria para el botón
/// "atrás", para no dejar crecer el historial de forma indefinida.
const _maxHistorySize = 10;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _random = Random();
  List<VocabularyItem>? _items;
  Set<String> _learnedIds = {};
  VocabularyItem? _currentItem;
  final List<VocabularyItem> _history = [];

  List<VocabularyItem> get _activeItems =>
      _items!.where((item) => !_learnedIds.contains(item.id)).toList();

  @override
  void initState() {
    super.initState();
    Future.wait([loadVocabulary(), getLearnedWordIds()]).then((results) {
      final items = results[0] as List<VocabularyItem>;
      final learnedIds = results[1] as Set<String>;
      final active =
          items.where((item) => !learnedIds.contains(item.id)).toList();
      setState(() {
        _items = items;
        _learnedIds = learnedIds;
        _currentItem = active.isEmpty
            ? null
            : active[_random.nextInt(active.length)];
      });
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

    final updatedItems = await loadVocabulary();
    if (!mounted) return;
    setState(() {
      _items = updatedItems;
    });
  }

  void _showNextWord() {
    final active = _activeItems;
    if (active.length <= 1) return;
    var next = _currentItem;
    while (next?.id == _currentItem?.id) {
      next = active[_random.nextInt(active.length)];
    }
    setState(() {
      final current = _currentItem;
      if (current != null) {
        _history.add(current);
        if (_history.length > _maxHistorySize) {
          _history.removeAt(0);
        }
      }
      _currentItem = next;
    });
  }

  void _showPreviousWord() {
    if (_history.isEmpty) return;
    setState(() {
      _currentItem = _history.removeLast();
    });
  }

  Future<void> _markCurrentAsLearned() async {
    final current = _currentItem;
    if (current == null) return;
    await markWordAsLearned(current.id);
    if (!mounted) return;
    setState(() {
      _learnedIds = {..._learnedIds, current.id};
      final active = _activeItems;
      _currentItem =
          active.isEmpty ? null : active[_random.nextInt(active.length)];
    });
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
                      VocabularyCard(item: current),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _markCurrentAsLearned,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Marcar como aprendida'),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: items == null
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'prev_word_fab',
                  onPressed: _history.isEmpty ? null : _showPreviousWord,
                  tooltip: 'Palabra anterior',
                  child: const Icon(Icons.arrow_back),
                ),
                FloatingActionButton(
                  heroTag: 'next_word_fab',
                  onPressed:
                      current == null || _activeItems.length <= 1
                          ? null
                          : _showNextWord,
                  tooltip: 'Otra palabra',
                  child: const Icon(Icons.refresh),
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
          children: [
            Text(
              item.word,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '/${item.pronunciation}/',
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
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
