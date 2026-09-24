import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/vocabulary_repository.dart';
import '../models/vocabulary_item.dart';
import 'card_density_service.dart';
import 'learned_words_service.dart';

const _currentIdPrefsKey = 'vocab_state_current_id';
const _historyIdsPrefsKey = 'vocab_state_history_ids';

/// Máximo de ids previos que se recuerdan en el historial persistido, para
/// no dejarlo crecer de forma indefinida (igual límite que el historial en
/// memoria que usaba antes `HomeScreen`).
const _maxHistorySize = 10;

const _widgetAndroidName = 'VocabularyAppWidgetProvider';
const _widgetQualifiedAndroidName =
    'com.example.widget_vocing.VocabularyAppWidgetProvider';

/// Permite a los tests omitir la sincronización con el widget nativo (que
/// depende de un MethodChannel de plataforma sin implementación real en el
/// entorno de test).
@visibleForTesting
bool debugSkipWidgetSync = false;

/// Snapshot inmutable del estado de vocabulario en un momento dado: catálogo
/// completo, ids aprendidos, palabra actualmente visible e historial de
/// navegación (solo ids, se resuelven contra [items] cuando hace falta).
class VocabularyStateSnapshot {
  const VocabularyStateSnapshot({
    required this.items,
    required this.learnedIds,
    required this.currentItem,
    required this.historyIds,
  });

  final List<VocabularyItem> items;
  final Set<String> learnedIds;
  final VocabularyItem? currentItem;
  final List<String> historyIds;

  List<VocabularyItem> get activeItems =>
      items.where((item) => !learnedIds.contains(item.id)).toList();
}

/// Única fuente de verdad de "cuál es la palabra actual" y "cuál es el
/// historial de navegación", persistida en `SharedPreferences` para que
/// tanto `HomeScreen` como el callback en background del widget nativo de
/// Android (que corre en un isolate headless nuevo en cada interacción)
/// compartan exactamente el mismo estado y comportamiento.
///
/// Ningún método cachea nada en memoria de instancia: cada llamada recarga
/// el catálogo (`loadVocabulary`) y las palabras aprendidas
/// (`getLearnedWordIds`) desde cero, porque el callback nativo no puede
/// depender de estado en memoria de una ejecución anterior.
class VocabularyStateService {
  const VocabularyStateService();

  Future<VocabularyStateSnapshot> loadState() async {
    final items = await loadVocabulary();
    final learnedIds = await getLearnedWordIds();
    final prefs = await SharedPreferences.getInstance();
    final historyIds = _readHistory(prefs);

    final active =
        items.where((item) => !learnedIds.contains(item.id)).toList();
    final persistedId = prefs.getString(_currentIdPrefsKey);
    VocabularyItem? current = persistedId == null
        ? null
        : _findActive(active, persistedId);
    current ??= _pickRandom(active);

    if (current?.id != persistedId) {
      await _writeCurrentId(prefs, current?.id);
    }

    final snapshot = VocabularyStateSnapshot(
      items: items,
      learnedIds: learnedIds,
      currentItem: current,
      historyIds: historyIds,
    );
    await _syncWidget(snapshot);
    return snapshot;
  }

  Future<VocabularyStateSnapshot> peekState() => loadState();

  /// Empuja el modo compacto/grande actual al widget nativo. Se llama desde
  /// `SettingsScreen` porque alternar la densidad no pasa por ningún otro
  /// mutador de esta clase (no cambia la palabra actual ni el historial).
  Future<void> syncWidgetCardDensity() => loadState();

  Future<VocabularyStateSnapshot> goToNextWord() async {
    final items = await loadVocabulary();
    final learnedIds = await getLearnedWordIds();
    final prefs = await SharedPreferences.getInstance();
    final active =
        items.where((item) => !learnedIds.contains(item.id)).toList();

    final currentId = prefs.getString(_currentIdPrefsKey);
    final current = currentId == null ? null : _findActive(active, currentId);

    if (active.length <= 1) {
      final snapshot = VocabularyStateSnapshot(
        items: items,
        learnedIds: learnedIds,
        currentItem: current ?? _pickRandom(active),
        historyIds: _readHistory(prefs),
      );
      await _syncWidget(snapshot);
      return snapshot;
    }

    final random = Random();
    var next = current;
    while (next?.id == current?.id) {
      next = active[random.nextInt(active.length)];
    }

    var historyIds = _readHistory(prefs);
    if (current != null) {
      historyIds = [...historyIds, current.id];
      if (historyIds.length > _maxHistorySize) {
        historyIds = historyIds.sublist(historyIds.length - _maxHistorySize);
      }
    }

    await _writeCurrentId(prefs, next?.id);
    await _writeHistory(prefs, historyIds);

    final snapshot = VocabularyStateSnapshot(
      items: items,
      learnedIds: learnedIds,
      currentItem: next,
      historyIds: historyIds,
    );
    await _syncWidget(snapshot);
    return snapshot;
  }

  Future<VocabularyStateSnapshot> goToPreviousWord() async {
    final items = await loadVocabulary();
    final learnedIds = await getLearnedWordIds();
    final prefs = await SharedPreferences.getInstance();

    final active =
        items.where((item) => !learnedIds.contains(item.id)).toList();

    var historyIds = _readHistory(prefs);
    VocabularyItem? previous;
    while (historyIds.isNotEmpty && previous == null) {
      final candidateId = historyIds.last;
      historyIds = historyIds.sublist(0, historyIds.length - 1);
      previous = _findActive(active, candidateId);
    }

    final currentId = prefs.getString(_currentIdPrefsKey);
    final current =
        previous ?? (currentId == null ? null : _findActive(active, currentId));

    if (previous != null) {
      await _writeCurrentId(prefs, previous.id);
      await _writeHistory(prefs, historyIds);
    }

    final snapshot = VocabularyStateSnapshot(
      items: items,
      learnedIds: learnedIds,
      currentItem: current,
      historyIds: historyIds,
    );
    await _syncWidget(snapshot);
    return snapshot;
  }

  Future<VocabularyStateSnapshot> markCurrentAsLearned() async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString(_currentIdPrefsKey);
    if (currentId == null) return loadState();

    await markWordAsLearned(currentId);

    final items = await loadVocabulary();
    final learnedIds = await getLearnedWordIds();
    final active =
        items.where((item) => !learnedIds.contains(item.id)).toList();
    final next = _pickRandom(active);

    await _writeCurrentId(prefs, next?.id);

    final snapshot = VocabularyStateSnapshot(
      items: items,
      learnedIds: learnedIds,
      currentItem: next,
      historyIds: _readHistory(prefs),
    );
    await _syncWidget(snapshot);
    return snapshot;
  }

  VocabularyItem? _findActive(List<VocabularyItem> active, String id) {
    for (final item in active) {
      if (item.id == id) return item;
    }
    return null;
  }

  VocabularyItem? _pickRandom(List<VocabularyItem> active) {
    if (active.isEmpty) return null;
    return active[Random().nextInt(active.length)];
  }

  List<String> _readHistory(SharedPreferences prefs) =>
      prefs.getStringList(_historyIdsPrefsKey) ?? const [];

  Future<void> _writeHistory(SharedPreferences prefs, List<String> ids) =>
      prefs.setStringList(_historyIdsPrefsKey, ids);

  Future<void> _writeCurrentId(SharedPreferences prefs, String? id) {
    if (id == null) return prefs.remove(_currentIdPrefsKey);
    return prefs.setString(_currentIdPrefsKey, id);
  }

  Future<void> _syncWidget(VocabularyStateSnapshot snapshot) async {
    if (debugSkipWidgetSync) return;
    try {
      final current = snapshot.currentItem;
      await HomeWidget.saveWidgetData<String>('widget_word', current?.word ?? '');
      await HomeWidget.saveWidgetData<String>(
        'widget_pronunciation',
        current?.pronunciation ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_example',
        current?.example ?? '',
      );
      await HomeWidget.saveWidgetData<bool>(
        'widget_has_previous',
        snapshot.historyIds.isNotEmpty,
      );
      await HomeWidget.saveWidgetData<bool>(
        'widget_has_next',
        snapshot.activeItems.length > 1,
      );
      await HomeWidget.saveWidgetData<bool>(
        'widget_empty',
        current == null,
      );
      await HomeWidget.saveWidgetData<bool>(
        'widget_compact_mode',
        await getCardDensity() == CardDensity.compact,
      );
      await HomeWidget.updateWidget(
        androidName: _widgetAndroidName,
        qualifiedAndroidName: _widgetQualifiedAndroidName,
      );
    } catch (_) {
      // Sin plugin nativo registrado (p. ej. en tests) o sin widget agregado
      // al home screen: no hay nada que sincronizar, se ignora en silencio.
    }
  }
}
