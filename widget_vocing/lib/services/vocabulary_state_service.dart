import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/vocabulary_repository.dart';
import '../l10n/app_strings.dart';
import '../models/vocabulary_item.dart';
import '../theme/app_theme_preset.dart';
import 'card_density_service.dart';
import 'dark_mode_service.dart';
import 'language_course_service.dart';
import 'learned_words_service.dart';
import 'theme_service.dart';

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
/// Android compartan exactamente el mismo estado y comportamiento.
///
/// Ningún método cachea nada en memoria de instancia: cada llamada recarga
/// el catálogo (`loadVocabulary`) y las palabras aprendidas
/// (`getLearnedWordIds`) desde cero. **Ojo:** el isolate headless que
/// `home_widget` usa para los botones del widget NO es nuevo en cada toque
/// — `HomeWidgetBackgroundService.kt` guarda el `FlutterEngine` en un
/// `companion object` y lo reutiliza mientras el proceso siga vivo. Como el
/// paquete `shared_preferences` cachea todas las claves en memoria la
/// primera vez que se llama `getInstance()` **por isolate** (`_completer`
/// estático en `shared_preferences_legacy.dart`), ese isolate reutilizado
/// nunca se enteraba de cambios hechos por la app en primer plano (ej.
/// cambiar el preset de tema en Configuración): seguía viendo el snapshot
/// de la primera vez que se calentó. Por eso `_freshPrefs()` llama
/// `reload()` antes de leer nada.
///
/// **Orden importante:** el curso de idioma activo (`getLanguageCourse()`) y
/// las demás preferencias de apariencia se leen siempre *después* de
/// `_freshPrefs()`. `reload()` refresca el mapa cacheado completo de ese
/// isolate, así que cualquier `getX()` posterior ve valores frescos; leerlas
/// antes traería el snapshot viejo y el widget seguiría mostrando palabras
/// del curso anterior.
class VocabularyStateService {
  const VocabularyStateService();

  Future<VocabularyStateSnapshot> loadState() async {
    final prefs = await _freshPrefs();
    final items = await loadVocabulary(await getLanguageCourse());
    final learnedIds = await getLearnedWordIds();
    final historyIds = _readHistory(prefs);

    final active = items
        .where((item) => !learnedIds.contains(item.id))
        .toList();
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

  /// Empuja al widget nativo la densidad y los colores de tema actuales.
  /// Se llama desde `SettingsScreen` al tocar cualquiera de esos ajustes,
  /// porque ninguno pasa por otro mutador de esta clase (no cambian la
  /// palabra actual ni el historial).
  Future<void> syncWidgetAppearance() => loadState();

  /// Olvida la palabra actual y el historial, y vuelve a cargar el estado.
  /// Lo llama `SettingsScreen` al cambiar de curso: los ids guardados son del
  /// curso anterior, así que `loadState()` elige una palabra del curso nuevo
  /// y la empuja al widget nativo de inmediato.
  ///
  /// (Limpiar el historial no es imprescindible —`goToPreviousWord` ya salta
  /// los ids que no existen en el pool activo— pero deja el estado coherente
  /// en vez de arrastrar ids muertos del otro idioma.)
  Future<VocabularyStateSnapshot> resetCourseState() async {
    final prefs = await _freshPrefs();
    await prefs.remove(_currentIdPrefsKey);
    await prefs.remove(_historyIdsPrefsKey);
    return loadState();
  }

  Future<VocabularyStateSnapshot> goToNextWord() async {
    final prefs = await _freshPrefs();
    final items = await loadVocabulary(await getLanguageCourse());
    final learnedIds = await getLearnedWordIds();
    final active = items
        .where((item) => !learnedIds.contains(item.id))
        .toList();

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
    final prefs = await _freshPrefs();
    final items = await loadVocabulary(await getLanguageCourse());
    final learnedIds = await getLearnedWordIds();

    final active = items
        .where((item) => !learnedIds.contains(item.id))
        .toList();

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
    final prefs = await _freshPrefs();
    final currentId = prefs.getString(_currentIdPrefsKey);
    if (currentId == null) return loadState();

    await markWordAsLearned(currentId);

    final items = await loadVocabulary(await getLanguageCourse());
    final learnedIds = await getLearnedWordIds();
    final active = items
        .where((item) => !learnedIds.contains(item.id))
        .toList();
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

  /// `SharedPreferences.getInstance()` + `reload()`: ver el comentario de
  /// la clase — sin el `reload()`, el isolate headless del widget reutiliza
  /// para siempre el snapshot de la primera vez que se calentó.
  Future<SharedPreferences> _freshPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
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
      await HomeWidget.saveWidgetData<String>(
        'widget_word',
        current?.word ?? '',
      );
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
      await HomeWidget.saveWidgetData<bool>('widget_empty', current == null);
      // El único texto fijo del widget nativo. Viaja desde aquí (en vez de
      // vivir en el Kotlin) porque su idioma depende del curso activo, que
      // solo conoce el lado Dart.
      final course = await getLanguageCourse();
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_text',
        appStringsFor(course.uiLocale).widgetAllLearned,
      );
      await HomeWidget.saveWidgetData<bool>(
        'widget_compact_mode',
        await getCardDensity() == CardDensity.compact,
      );
      final presetId = await getSelectedThemePresetId();
      final darkModeEnabled = await getDarkModeEnabled();
      final roles = resolveActiveThemeRoles(presetId, darkModeEnabled);
      await HomeWidget.saveWidgetData<String>(
        'widget_color_card',
        _colorToHex(roles.card),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_color_button',
        _colorToHex(roles.primary),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_color_text',
        _colorToHex(roles.text),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_color_text_secondary',
        _colorToHex(roles.textSecondary),
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

  /// `#AARRGGBB`, el mismo formato que entiende `android.graphics.Color.
  /// parseColor()`. Se manda como `String` en vez de `int`: los colores con
  /// canal alfa (`0xFF......`) superan el rango de un `Int32` con signo, así
  /// que el codec de Flutter los serializa como `Long` del lado de Kotlin —
  /// pero `HomeWidgetPlugin` los guarda con el tipo que llega por el canal
  /// (`putInt` o `putLong` según el caso), y leerlos siempre con `getInt()`
  /// revienta con `ClassCastException` cuando terminaron como `Long`. Un
  /// string hexadecimal no tiene esa ambigüedad de tipo.
  String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
