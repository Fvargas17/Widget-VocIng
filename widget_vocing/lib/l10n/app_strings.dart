import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import 'app_locale.dart';

/// Todos los textos visibles de la app, en los dos idiomas de interfaz.
///
/// Cada string declara sus dos variantes **en la misma línea**, en vez de
/// vivir en un archivo por idioma: así es imposible que una traducción se
/// quede atrás al agregar un texto nuevo, y al editar uno se ve de inmediato
/// el otro idioma. No se usa `gen_l10n`/ARB a propósito — no haría falta
/// codegen para 2 idiomas y el proyecto ya declara sus catálogos (temas,
/// mascotas) como datos en Dart.
///
/// Se obtiene con `AppStrings.of(context)`, resuelto por el `locale` de la
/// `MaterialApp`, que a su vez sale del curso de idioma activo (ver
/// `LanguageCourse.uiLocale`). Para consumidores sin `BuildContext` —el texto
/// que se empuja al widget nativo de Android— está [appStringsFor].
@immutable
class AppStrings {
  const AppStrings(this.locale);

  final AppLocale locale;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(AppLocale.es);

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String _t({required String es, required String en}) =>
      LocalizedText(es: es, en: en).resolve(locale);

  // ── Splash ────────────────────────────────────────────────────────────
  /// Etiqueta para lectores de pantalla mientras corre la splash animada.
  String get loading => _t(es: 'Cargando', en: 'Loading');

  // ── Menú lateral ──────────────────────────────────────────────────────
  String get menuTitle => _t(es: 'Menú', en: 'Menu');
  String get home => _t(es: 'Inicio', en: 'Home');
  String get managePacks => _t(es: 'Administrar packs', en: 'Manage packs');
  String get learnedWords => _t(es: 'Palabras aprendidas', en: 'Learned words');
  String get favoriteWords =>
      _t(es: 'Palabras favoritas', en: 'Favorite words');
  String get settings => _t(es: 'Configuración', en: 'Settings');

  // ── Inicio ────────────────────────────────────────────────────────────
  String get allWordsLearned => _t(
    es: '¡Has aprendido todas las palabras disponibles!',
    en: 'You have learned every available word!',
  );
  String get markAsLearned =>
      _t(es: 'Marcar como aprendida', en: 'Mark as learned');
  String get learnedBadge => _t(es: '¡Aprendida!', en: 'Learned!');
  String get previousWord => _t(es: 'Palabra anterior', en: 'Previous word');
  String get anotherWord => _t(es: 'Otra palabra', en: 'Another word');
  String get addToFavorites =>
      _t(es: 'Agregar a favoritos', en: 'Add to favorites');
  String get removeFromFavorites =>
      _t(es: 'Quitar de favoritos', en: 'Remove from favorites');

  String get newContentTitle =>
      _t(es: 'Contenido nuevo disponible', en: 'New content available');
  String newContentBody(int wordCount, String packNames) => _t(
    es:
        'Hay $wordCount palabras nuevas disponibles ($packNames). '
        'Puedes descargarlas desde Administrar packs.',
    en:
        'There are $wordCount new words available ($packNames). '
        'You can download them from Manage packs.',
  );
  String get notNow => _t(es: 'Ahora no', en: 'Not now');
  String get view => _t(es: 'Ver', en: 'View');

  // ── Favoritas ─────────────────────────────────────────────────────────
  String get favoritesEmpty => _t(
    es:
        'Todavía no tienes palabras favoritas.\n'
        'Marca la estrella de una tarjeta para agregarla aquí.',
    en:
        'You have no favorite words yet.\n'
        'Tap the star on a card to add it here.',
  );
  String favoritesCount(int count) => count == 1
      ? _t(es: '1 palabra en favoritos', en: '1 word in favorites')
      : _t(es: '$count palabras en favoritos', en: '$count words in favorites');
  String get previousFavorite =>
      _t(es: 'Favorita anterior', en: 'Previous favorite');
  String get nextFavorite => _t(es: 'Siguiente favorita', en: 'Next favorite');

  // ── Aprendidas ────────────────────────────────────────────────────────
  String learnedWordsWithCount(int count) =>
      _t(es: 'Palabras aprendidas ($count)', en: 'Learned words ($count)');
  String get learnedEmpty => _t(
    es: 'Todavía no has marcado ninguna palabra como aprendida.',
    en: 'You have not marked any word as learned yet.',
  );
  String get unmark => _t(es: 'Desmarcar', en: 'Unmark');

  // ── Packs ─────────────────────────────────────────────────────────────
  String get refresh => _t(es: 'Actualizar', en: 'Refresh');
  String get connectionError => _t(
    es: 'No se pudo conectar. Intenta de nuevo.',
    en: 'Could not connect. Please try again.',
  );
  String get retry => _t(es: 'Reintentar', en: 'Retry');
  String get noPacksAvailable => _t(
    es: 'No hay packs disponibles por ahora.',
    en: 'No packs available right now.',
  );
  String wordCount(int count) => count == 1
      ? _t(es: '1 palabra', en: '1 word')
      : _t(es: '$count palabras', en: '$count words');
  String get updateAvailable =>
      _t(es: 'Actualización disponible', en: 'Update available');
  String get downloaded => _t(es: 'Descargado', en: 'Downloaded');
  String get download => _t(es: 'Descargar', en: 'Download');
  String get delete => _t(es: 'Eliminar', en: 'Delete');
  String get cancel => _t(es: 'Cancelar', en: 'Cancel');
  String deletePackTitle(String packName) =>
      _t(es: 'Eliminar $packName', en: 'Delete $packName');
  String get deletePackBody => _t(
    es:
        'Se borrará el pack descargado. Podrás volver a descargarlo cuando '
        'quieras.',
    en:
        'The downloaded pack will be removed. You can download it again '
        'whenever you want.',
  );
  String downloadFailed(String packName) => _t(
    es: 'No se pudo descargar $packName',
    en: 'Could not download $packName',
  );

  // ── Configuración ─────────────────────────────────────────────────────
  String get languageSetting => _t(es: 'Idioma', en: 'Language');
  String get languageSettingSubtitle => _t(
    es: 'Cambia el vocabulario y el idioma de la app.',
    en: 'Changes both the vocabulary and the app language.',
  );
  String get appTheme => _t(es: 'Tema de la app', en: 'App theme');
  String get petSetting => _t(es: 'Mascota', en: 'Pet');
  String get darkMode => _t(es: 'Modo oscuro', en: 'Dark mode');
  String get darkModeSubtitle => _t(
    es: 'Versión oscura del tema elegido arriba, en la app.',
    en: 'Dark version of the theme chosen above.',
  );
  String get soundEffects => _t(es: 'Efectos de sonido', en: 'Sound effects');
  String get soundEffectsSubtitle => _t(
    es:
        'Sonidos al cambiar de palabra, marcarla como aprendida o agregarla '
        'a favoritos.',
    en:
        'Sounds when changing word, marking it as learned or adding it to '
        'favorites.',
  );
  String get compactMode => _t(es: 'Modo compacto', en: 'Compact mode');
  String get compactModeSubtitle => _t(
    es: 'Tarjetas más pequeñas en la app y en el widget del menú de apps.',
    en: 'Smaller cards in the app and in the home screen widget.',
  );

  // ── Widget nativo de Android ──────────────────────────────────────────
  /// Único texto fijo del widget. Se empuja desde `VocabularyStateService`
  /// porque el provider de Kotlin no sabe qué curso está activo.
  String get widgetAllLearned => _t(es: '¡Todo aprendido!', en: 'All learned!');
}

/// Resuelve los strings sin pasar por el árbol de widgets (no hay
/// `BuildContext` en los servicios).
AppStrings appStringsFor(AppLocale locale) => AppStrings(locale);

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocale.values.any((l) => l.code == locale.languageCode);

  /// `SynchronousFuture` para que los strings estén listos en el mismo frame:
  /// un `Future` real haría que la app dibuje un frame sin `Localizations`
  /// resuelto cada vez que cambia el idioma.
  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(
    AppStrings(AppLocale.fromLanguageCode(locale.languageCode)),
  );

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
