import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';

import 'l10n/app_locale.dart';
import 'l10n/app_strings.dart';
import 'models/language_course.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learned_words_screen.dart';
import 'screens/pack_management_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/dark_mode_notifier.dart';
import 'services/home_widget_callback.dart';
import 'services/language_course_notifier.dart';
import 'services/theme_notifier.dart';
import 'theme/app_theme_preset.dart';

export 'screens/home_screen.dart' show HomeScreen, VocabularyCard;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(backgroundCallback);
  runApp(const WidgetVocIngApp());
}

class WidgetVocIngApp extends StatelessWidget {
  const WidgetVocIngApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedThemePresetIdNotifier,
      builder: (context, presetId, _) {
        final preset = resolveThemePreset(presetId);
        return ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, darkModeEnabled, _) {
            // El idioma de la UI no es un ajuste propio: sale del idioma base
            // del curso elegido en Configuración (ver `LanguageCourse`). Al
            // cambiar de curso se reconstruye toda la app con otro `locale`,
            // así que ninguna pantalla necesita escuchar este notifier.
            return ValueListenableBuilder<LanguageCourse>(
              valueListenable: languageCourseNotifier,
              builder: (context, course, _) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'Widget VocIng',
                  theme: darkModeEnabled
                      ? preset.darkThemeData
                      : preset.themeData,
                  locale: course.uiLocale.flutterLocale,
                  supportedLocales: [
                    for (final locale in AppLocale.values) locale.flutterLocale,
                  ],
                  localizationsDelegates: const [
                    AppStrings.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  initialRoute: '/',
                  routes: {
                    '/': (_) => const SplashScreen(),
                    '/home': (_) => const HomeScreen(),
                    '/packs': (_) => const PackManagementScreen(),
                    '/learned': (_) => const LearnedWordsScreen(),
                    '/favorites': (_) => const FavoritesScreen(),
                    '/settings': (_) => const SettingsScreen(),
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
