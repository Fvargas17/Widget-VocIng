import 'package:flutter/material.dart';

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
      home: Scaffold(
        appBar: AppBar(title: const Text('Widget VocIng')),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('OVERWHELMED', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('Feeling unable to cope because there is too much to deal with.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 12),

                  const Text('Sentirse abrumado porque hay demasiadas cosas que manejar.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                  const SizedBox(height: 20),

                  const Text('“I felt overwhelmed with work this week.”', textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16),),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
