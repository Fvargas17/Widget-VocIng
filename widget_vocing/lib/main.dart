import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learned_words_screen.dart';
import 'screens/pack_management_screen.dart';
import 'screens/settings_screen.dart';
import 'services/card_density_notifier.dart';
import 'services/card_density_service.dart';
import 'services/dark_mode_notifier.dart';
import 'services/dark_mode_service.dart';
import 'services/home_widget_callback.dart';
import 'services/theme_notifier.dart';
import 'services/theme_service.dart';
import 'theme/app_theme_preset.dart';

export 'screens/home_screen.dart' show HomeScreen, VocabularyCard;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(backgroundCallback);
  _loadPersistedThemePreset();
  _loadPersistedCardDensity();
  _loadPersistedDarkMode();
  runApp(const WidgetVocIngApp());
}

Future<void> _loadPersistedThemePreset() async {
  final storedId = await getSelectedThemePresetId();
  selectedThemePresetIdNotifier.value = storedId;
}

Future<void> _loadPersistedCardDensity() async {
  final storedDensity = await getCardDensity();
  cardDensityNotifier.value = storedDensity;
}

Future<void> _loadPersistedDarkMode() async {
  final storedEnabled = await getDarkModeEnabled();
  darkModeNotifier.value = storedEnabled;
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
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Widget VocIng',
              theme: darkModeEnabled ? preset.darkThemeData : preset.themeData,
              initialRoute: '/',
              routes: {
                '/': (_) => const HomeScreen(),
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
  }
}
