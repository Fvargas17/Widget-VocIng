import 'package:flutter/material.dart';

import '../services/card_density_notifier.dart';
import '../services/card_density_service.dart';
import '../services/sound_service.dart';
import '../services/theme_notifier.dart';
import '../services/theme_service.dart';
import '../services/vocabulary_state_service.dart';
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

  @override
  void initState() {
    super.initState();
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
  }

  Future<void> _selectPreset(String presetId) async {
    setState(() => _selectedPresetId = presetId);
    await setSelectedThemePresetId(presetId);
    selectedThemePresetIdNotifier.value = presetId;
  }

  Future<void> _toggleSounds(bool enabled) async {
    setState(() => _soundsEnabled = enabled);
    await setSoundsEnabled(enabled);
    // Al encenderlos, un sonido de muestra confirma el cambio.
    if (enabled) playAppSound(AppSound.favorite);
  }

  Future<void> _toggleCardDensity(bool compact) async {
    final density = compact ? CardDensity.compact : CardDensity.large;
    setState(() => _cardDensity = density);
    await setCardDensity(density);
    cardDensityNotifier.value = density;
    // El widget nativo no escucha este notifier (vive en otro proceso): hay
    // que empujarle el cambio explícitamente, ya que alternar la densidad no
    // pasa por ningún mutador de VocabularyStateService.
    await const VocabularyStateService().syncWidgetCardDensity();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPresetId = _selectedPresetId;
    final cardDensity = _cardDensity;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      drawer: const AppDrawer(currentScreen: AppScreen.settings),
      body: selectedPresetId == null || cardDensity == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tema de la app',
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
                                child: Text(preset.displayName),
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
                  child: SwitchListTile(
                    value: _soundsEnabled,
                    onChanged: _toggleSounds,
                    title: const Text('Efectos de sonido'),
                    subtitle: const Text(
                      'Sonidos al cambiar de palabra, marcarla como aprendida '
                      'o agregarla a favoritos.',
                    ),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    value: cardDensity == CardDensity.compact,
                    onChanged: _toggleCardDensity,
                    title: const Text('Modo compacto'),
                    subtitle: const Text(
                      'Tarjetas más pequeñas en la app y en el widget del '
                      'menú de apps.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
