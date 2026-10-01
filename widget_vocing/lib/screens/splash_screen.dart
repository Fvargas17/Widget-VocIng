import 'package:flutter/material.dart';

import '../services/card_density_notifier.dart';
import '../services/card_density_service.dart';
import '../services/dark_mode_notifier.dart';
import '../services/dark_mode_service.dart';
import '../services/pet_notifier.dart';
import '../services/pet_service.dart';
import '../services/theme_notifier.dart';
import '../services/theme_service.dart';
import '../splash/lingua_splash.dart';
import 'home_screen.dart';

/// En tests, salta la animación (~4.3 s) y entra directo a [HomeScreen],
/// igual que `debugDisableSounds`/`debugDisablePetMotion` en otros servicios.
@visibleForTesting
bool debugSkipSplash = false;

/// Splash animada (venado + palabras) que se muestra una sola vez, al
/// arranque en frío, entre el splash nativo estático y [HomeScreen]. También
/// carga aquí (en vez de en `main()`, sin esperar) el tema, la densidad, el
/// modo oscuro y la mascota persistidos, para que `HomeScreen` nunca
/// parpadee con los valores por defecto de los notifiers.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<void> _boot = _bootstrap();

  Future<void> _bootstrap() async {
    final presetId = await getSelectedThemePresetId();
    final density = await getCardDensity();
    final darkModeEnabled = await getDarkModeEnabled();
    final pet = await getPet();
    selectedThemePresetIdNotifier.value = presetId;
    cardDensityNotifier.value = density;
    darkModeNotifier.value = darkModeEnabled;
    petNotifier.value = pet;
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      splashHandoffRoute<void>((_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (debugSkipSplash) return const HomeScreen();
    return LinguaSplash(
      loading: _boot,
      onFinished: _goHome,
      // Mismo teal que `flutter_native_splash` (ver pubspec.yaml), para que
      // el relevo entre el splash nativo y esta animación no tenga destello.
      endColor: const Color(0xFF015955),
    );
  }
}
