import 'package:flutter/material.dart';

import '../data/vocabulary_repository.dart';
import '../l10n/app_strings.dart';
import '../models/vocabulary_item.dart';
import '../services/language_course_service.dart';
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
    // El catálogo ya viene filtrado por curso, así que la lista (y su
    // conteo en el AppBar) solo refleja el idioma que se está estudiando.
    final allItems = await loadVocabulary(await getLanguageCourse());
    final learnedIds = await getLearnedWordIds();
    if (!mounted) return;
    setState(() {
      _learnedItems = allItems
          .where((item) => learnedIds.contains(item.id))
          .toList();
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
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          learnedItems == null
              ? strings.learnedWords
              : strings.learnedWordsWithCount(learnedItems.length),
        ),
      ),
      drawer: const AppDrawer(currentScreen: AppScreen.learned),
      body: _buildBody(context, learnedItems),
    );
  }

  Widget _buildBody(BuildContext context, List<VocabularyItem>? learnedItems) {
    final strings = AppStrings.of(context);
    if (learnedItems == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (learnedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.learnedEmpty, textAlign: TextAlign.center),
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
              tooltip: strings.unmark,
              onPressed: () => _unmark(item),
            ),
          ),
        );
      },
    );
  }
}
