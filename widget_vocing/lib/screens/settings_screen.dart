import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/language_course.dart';
import '../services/card_density_notifier.dart';
import '../services/card_density_service.dart';
import '../services/dark_mode_notifier.dart';
import '../services/dark_mode_service.dart';
import '../services/language_course_notifier.dart';
import '../services/language_course_service.dart';
import '../services/pet_notifier.dart';
import '../services/pet_service.dart';
import '../services/sound_service.dart';
import '../services/theme_notifier.dart';
import '../services/theme_service.dart';
import '../services/vocabulary_state_service.dart';
import '../pets/pet_catalog.dart';
import '../theme/app_theme_preset.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedPresetId;
  bool _soundsEnabled = true;
  CardDensity? _cardDensity;
  bool? _darkModeEnabled;
  Pet? _selectedPet;
  LanguageCourse? _selectedCourse;

  @override
  void initState() {
    super.initState();
    getLanguageCourse().then((course) {
      if (!mounted) return;
      setState(() => _selectedCourse = course);
    });
    getSelectedThemePresetId().then((id) {
      if (!mounted) return;
      setState(() => _selectedPresetId = id);
    });
    getSoundsEnabled().then((enabled) {
      if (!mounted) return;
      setState(() => _soundsEnabled = enabled);
    });
    getCardDensity().then((density) {
      if (!mounted) return;
      setState(() => _cardDensity = density);
    });
    getDarkModeEnabled().then((enabled) {
      if (!mounted) return;
      setState(() => _darkModeEnabled = enabled);
    });
    getPet().then((pet) {
      if (!mounted) return;
      setState(() => _selectedPet = pet);
    });
  }

  /// Cambiar de curso toca dos cosas a la vez: el idioma de toda la UI (vía
  /// `languageCourseNotifier`, que reconstruye la `MaterialApp` con otro
  /// `locale`) y el vocabulario, porque los ids guardados como "palabra
  /// actual" e historial son del curso anterior.
  Future<void> _selectCourse(LanguageCourse course) async {
    setState(() => _selectedCourse = course);
    await setLanguageCourse(course);
    languageCourseNotifier.value = course;
    await const VocabularyStateService().resetCourseState();
  }

  Future<void> _selectPreset(String presetId) async {
    setState(() => _selectedPresetId = presetId);
    await setSelectedThemePresetId(presetId);
    selectedThemePresetIdNotifier.value = presetId;
    await const VocabularyStateService().syncWidgetAppearance();
  }

  Future<void> _toggleDarkMode(bool enabled) async {
    setState(() => _darkModeEnabled = enabled);
    await setDarkModeEnabled(enabled);
    darkModeNotifier.value = enabled;
    await const VocabularyStateService().syncWidgetAppearance();
  }

  Future<void> _toggleSounds(bool enabled) async {
    setState(() => _soundsEnabled = enabled);
    await setSoundsEnabled(enabled);
    // Al encenderlos, un sonido de muestra confirma el cambio.
    if (enabled) playAppSound(AppSound.favorite);
  }

  Future<void> _selectPet(Pet pet) async {
    setState(() => _selectedPet = pet);
    await setPet(pet);
    petNotifier.value = pet;
  }

  Future<void> _toggleCardDensity(bool compact) async {
    final density = compact ? CardDensity.compact : CardDensity.large;
    setState(() => _cardDensity = density);
    await setCardDensity(density);
    cardDensityNotifier.value = density;
    // El widget nativo no escucha este notifier (vive en otro proceso): hay
    // que empujarle el cambio explícitamente, ya que alternar la densidad no
    // pasa por ningún mutador de VocabularyStateService.
    await const VocabularyStateService().syncWidgetAppearance();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final locale = strings.locale;
    final selectedPresetId = _selectedPresetId;
    final cardDensity = _cardDensity;
    final darkModeEnabled = _darkModeEnabled;
    final selectedPet = _selectedPet;
    final selectedCourse = _selectedCourse;
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      drawer: const AppDrawer(currentScreen: AppScreen.settings),
      body:
          selectedPresetId == null ||
              cardDensity == null ||
              darkModeEnabled == null ||
              selectedPet == null ||
              selectedCourse == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Primero el idioma: es el ajuste que más cambia la app
                // (vocabulario + textos), así que encabeza la lista.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.languageSetting,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          strings.languageSettingSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        // Un dropdown y no un switch aunque hoy haya dos
                        // cursos: el catálogo está pensado para crecer sin
                        // rediseñar el ajuste.
                        DropdownButton<LanguageCourse>(
                          value: selectedCourse,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final course in LanguageCourse.values)
                              DropdownMenuItem(
                                value: course,
                                child: Text(course.name.resolve(locale)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) _selectCourse(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.appTheme,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        DropdownButton<String>(
                          value: selectedPresetId,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final preset in appThemePresets)
                              DropdownMenuItem(
                                value: preset.id,
                                child: Text(preset.displayName.resolve(locale)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) _selectPreset(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.petSetting,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        DropdownButton<Pet>(
                          value: selectedPet,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final pet in Pet.values)
                              DropdownMenuItem(
                                value: pet,
                                child: Text(
                                  '${petCatalog[pet]!.emoji}  '
                                  '${petCatalog[pet]!.displayName.resolve(locale)}',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) _selectPet(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    value: darkModeEnabled,
                    onChanged: _toggleDarkMode,
                    title: Text(strings.darkMode),
                    subtitle: Text(strings.darkModeSubtitle),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    value: _soundsEnabled,
                    onChanged: _toggleSounds,
                    title: Text(strings.soundEffects),
                    subtitle: Text(strings.soundEffectsSubtitle),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    value: cardDensity == CardDensity.compact,
                    onChanged: _toggleCardDensity,
                    title: Text(strings.compactMode),
                    subtitle: Text(strings.compactModeSubtitle),
                  ),
                ),
              ],
            ),
    );
  }
}
