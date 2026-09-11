import 'vocabulary_state_service.dart';

/// Convención de acción usada por los botones del widget nativo de Android
/// (ver `VocabularyAppWidgetProvider.kt`): cada botón dispara un
/// `HomeWidgetBackgroundIntent` con una de estas URIs.
const actionNext = 'next';
const actionPrevious = 'previous';
const actionLearned = 'learned';

/// Entry point invocado por `home_widget` en un isolate headless cuando el
/// usuario toca un botón del widget, sin que la app esté abierta. Delega
/// toda la lógica en [VocabularyStateService] (la misma que usa
/// `HomeScreen`), que ya se encarga de persistir el nuevo estado y de
/// refrescar el widget nativo.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;
  const stateService = VocabularyStateService();

  switch (uri.host) {
    case actionNext:
      await stateService.goToNextWord();
      break;
    case actionPrevious:
      await stateService.goToPreviousWord();
      break;
    case actionLearned:
      await stateService.markCurrentAsLearned();
      break;
  }
}
