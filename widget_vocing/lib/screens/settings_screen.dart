import 'package:flutter/material.dart';

import '../services/theme_notifier.dart';
import '../services/theme_service.dart';
import '../theme/app_theme_preset.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    getSelectedThemePresetId().then((id) {
      if (!mounted) return;
      setState(() => _selectedPresetId = id);
    });
  }

  Future<void> _selectPreset(String presetId) async {
    setState(() => _selectedPresetId = presetId);
    await setSelectedThemePresetId(presetId);
    selectedThemePresetIdNotifier.value = presetId;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPresetId = _selectedPresetId;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      drawer: const AppDrawer(currentScreen: AppScreen.settings),
      body: selectedPresetId == null
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
              ],
            ),
    );
  }
}
