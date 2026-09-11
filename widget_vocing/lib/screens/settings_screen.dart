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
          : RadioGroup<String>(
              groupValue: selectedPresetId,
              onChanged: (value) {
                if (value != null) _selectPreset(value);
              },
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Tema de la app',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final preset in appThemePresets)
                    RadioListTile<String>(
                      value: preset.id,
                      title: Text(preset.displayName),
                    ),
                ],
              ),
            ),
    );
  }
}
