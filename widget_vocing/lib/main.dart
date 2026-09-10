import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/pack_management_screen.dart';

export 'screens/home_screen.dart' show HomeScreen, VocabularyCard;

void main() {
  runApp(const WidgetVocIngApp());
}

class WidgetVocIngApp extends StatelessWidget {
  const WidgetVocIngApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Widget VocIng',
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/packs': (_) => const PackManagementScreen(),
      },
    );
  }
}
