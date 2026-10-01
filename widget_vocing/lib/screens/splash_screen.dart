import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/card_density_notifier.dart';
import '../services/card_density_service.dart';
import '../services/dark_mode_notifier.dart';
import '../services/dark_mode_service.dart';
import '../services/language_course_notifier.dart';
import '../services/language_course_service.dart';
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
/// modo oscuro, la mascota y el curso de idioma persistidos, para que
/// `HomeScreen` nunca parpadee con los valores por defecto de los notifiers
/// (en el caso del curso, eso significaría un destello de la app en español
/// antes de pasar al inglés).
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
    final course = await getLanguageCourse();
    selectedThemePresetIdNotifier.value = presetId;
    cardDensityNotifier.value = density;
    darkModeNotifier.value = darkModeEnabled;
    petNotifier.value = pet;
    languageCourseNotifier.value = course;
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(splashHandoffRoute<void>((_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (debugSkipSplash) return const HomeScreen();
    return LinguaSplash(
      loading: _boot,
      onFinished: _goHome,
      // En el arranque en frío esto sale en el idioma por defecto y cambia en
      // cuanto `_bootstrap()` resuelve el curso guardado: es solo la etiqueta
      // para lectores de pantalla, no texto visible.
      semanticsLabel: AppStrings.of(context).loading,
      // Mismo teal que `flutter_native_splash` (ver pubspec.yaml), para que
      // el relevo entre el splash nativo y esta animación no tenga destello.
      endColor: const Color(0xFF015955),
    );
  }
}
