import 'dart:math';

import 'package:flutter/material.dart';

import '../data/vocabulary_repository.dart';
import '../models/vocabulary_item.dart';
import '../services/pack_service.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _random = Random();
  List<VocabularyItem>? _items;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    loadVocabulary().then((items) {
      setState(() {
        _items = items;
        _currentIndex = _random.nextInt(items.length);
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
    final items = _items!;
    if (items.length <= 1) return;
    var nextIndex = _currentIndex;
    while (nextIndex == _currentIndex) {
      nextIndex = _random.nextInt(items.length);
    }
    setState(() {
      _currentIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget VocIng')),
      drawer: const AppDrawer(currentScreen: AppScreen.home),
      body: Center(
        child: items == null
            ? const CircularProgressIndicator()
            : VocabularyCard(item: items[_currentIndex]),
      ),
      floatingActionButton: items == null
          ? null
          : FloatingActionButton(
              onPressed: _showNextWord,
              tooltip: 'Otra palabra',
              child: const Icon(Icons.refresh),
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
