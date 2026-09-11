import 'package:flutter/material.dart';

import '../data/vocabulary_repository.dart';
import '../models/vocabulary_item.dart';
import '../services/learned_words_service.dart';
import '../widgets/app_drawer.dart';

class LearnedWordsScreen extends StatefulWidget {
  const LearnedWordsScreen({super.key});

  @override
  State<LearnedWordsScreen> createState() => _LearnedWordsScreenState();
}

class _LearnedWordsScreenState extends State<LearnedWordsScreen> {
  List<VocabularyItem>? _learnedItems;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final allItems = await loadVocabulary();
    final learnedIds = await getLearnedWordIds();
    if (!mounted) return;
    setState(() {
      _learnedItems =
          allItems.where((item) => learnedIds.contains(item.id)).toList();
    });
  }

  Future<void> _unmark(VocabularyItem item) async {
    await unmarkWordAsLearned(item.id);
    if (!mounted) return;
    setState(() {
      _learnedItems?.removeWhere((i) => i.id == item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final learnedItems = _learnedItems;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          learnedItems == null
              ? 'Palabras aprendidas'
              : 'Palabras aprendidas (${learnedItems.length})',
        ),
      ),
      drawer: const AppDrawer(currentScreen: AppScreen.learned),
      body: _buildBody(learnedItems),
    );
  }

  Widget _buildBody(List<VocabularyItem>? learnedItems) {
    if (learnedItems == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (learnedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no has marcado ninguna palabra como aprendida.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: learnedItems.length,
      itemBuilder: (context, index) {
        final item = learnedItems[index];
        return Card(
          child: ListTile(
            title: Text(item.word),
            subtitle: Text(item.translation),
            trailing: IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Desmarcar',
              onPressed: () => _unmark(item),
            ),
          ),
        );
      },
    );
  }
}
