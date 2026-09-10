import 'package:flutter/material.dart';

/// Identifica qué pantalla del Drawer está activa, para resaltarla.
enum AppScreen { home, packs }

/// Menú lateral compartido por las dos pantallas de la app. Usa rutas
/// nombradas (declaradas en `MaterialApp`) en vez de referenciar los
/// widgets de pantalla directamente, para evitar un import circular entre
/// este archivo y las pantallas que lo usan.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentScreen});

  final AppScreen currentScreen;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Center(
              child: Text('Menú', style: TextStyle(fontSize: 24)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: currentScreen == AppScreen.home,
            onTap: () => _navigateTo(context, AppScreen.home, '/'),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Administrar packs'),
            selected: currentScreen == AppScreen.packs,
            onTap: () => _navigateTo(context, AppScreen.packs, '/packs'),
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
