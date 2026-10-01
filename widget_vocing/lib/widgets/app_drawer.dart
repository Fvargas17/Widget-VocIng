import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Identifica qué pantalla del Drawer está activa, para resaltarla.
enum AppScreen { home, packs, learned, favorites, settings }

/// Menú lateral compartido por las dos pantallas de la app. Usa rutas
/// nombradas (declaradas en `MaterialApp`) en vez de referenciar los
/// widgets de pantalla directamente, para evitar un import circular entre
/// este archivo y las pantallas que lo usan.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentScreen});

  final AppScreen currentScreen;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Center(
              child: Text(
                strings.menuTitle,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: Text(strings.home),
            selected: currentScreen == AppScreen.home,
            onTap: () => _navigateTo(context, AppScreen.home, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(strings.managePacks),
            selected: currentScreen == AppScreen.packs,
            onTap: () => _navigateTo(context, AppScreen.packs, '/packs'),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(strings.learnedWords),
            selected: currentScreen == AppScreen.learned,
            onTap: () => _navigateTo(context, AppScreen.learned, '/learned'),
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: Text(strings.favoriteWords),
            selected: currentScreen == AppScreen.favorites,
            onTap: () =>
                _navigateTo(context, AppScreen.favorites, '/favorites'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(strings.settings),
            selected: currentScreen == AppScreen.settings,
            onTap: () => _navigateTo(context, AppScreen.settings, '/settings'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, AppScreen target, String route) {
    Navigator.pop(context);
    if (currentScreen == target) return;
    Navigator.of(context).pushReplacementNamed(route);
  }
}
