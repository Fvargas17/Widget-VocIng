import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _soundsEnabledPrefsKey = 'sounds_enabled';

/// Efectos de sonido de la app. Los WAV viven en `assets/sounds/` y se
/// generan con `tool/generate_sounds.py` (ver ese script para reajustarlos).
enum AppSound {
  /// Botones "palabra anterior" / "otra palabra".
  navigate('sounds/nav.wav'),

  /// Marcar una palabra como aprendida (botón o doble tap).
  learned('sounds/learned.wav'),

  /// Marcar o desmarcar la estrella de favoritos.
  favorite('sounds/favorite.wav');

  const AppSound(this.assetPath);

  final String assetPath;
}

/// Permite a los tests omitir la reproducción de audio. **No es opcional**:
/// igual que `debugSkipWidgetSync` en `vocabulary_state_service.dart`, el
/// `MethodChannel` de `audioplayers` no tiene handler registrado en el entorno
/// de test, y ahí un mensaje sin handler no lanza excepción de inmediato —
/// queda en buffer sin resolverse nunca bajo el reloj simulado de
/// `flutter_test`, colgando `pumpAndSettle()`.
@visibleForTesting
bool debugDisableSounds = false;

/// Un único reproductor reutilizado para todos los efectos: son cortos y
/// mutuamente excluyentes, así que un sonido nuevo corta al anterior.
final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

Future<bool> getSoundsEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_soundsEnabledPrefsKey) ?? true;
}

Future<void> setSoundsEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_soundsEnabledPrefsKey, enabled);
}

/// Reproduce [sound] si el usuario no apagó los efectos en Configuración.
/// Nunca propaga errores: un fallo de audio no debe romper la interacción.
Future<void> playAppSound(AppSound sound) async {
  if (debugDisableSounds) return;
  try {
    if (!await getSoundsEnabled()) return;
    await _player.stop();
    await _player.play(AssetSource(sound.assetPath));
  } catch (_) {
    // Sin plugin nativo disponible o sin salida de audio: se ignora.
  }
}
