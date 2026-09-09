// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:widget_vocing/main.dart';

void main() {
  testWidgets(
    'Carga el vocabulario y el botón de "otra palabra" cambia la tarjeta sin repetir',
    (WidgetTester tester) async {
      await tester.pumpWidget(const WidgetVocIngApp());

      // Mientras se carga el asset, se muestra un indicador de progreso.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Espera a que se resuelva la carga asíncrona del vocabulario.
      await tester.pumpAndSettle();

      expect(find.text('Widget VocIng'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final firstWord =
          (tester.widget(find.byType(VocabularyCard)) as VocabularyCard)
              .item
              .word;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final secondWord =
          (tester.widget(find.byType(VocabularyCard)) as VocabularyCard)
              .item
              .word;

      expect(secondWord, isNot(equals(firstWord)));
    },
  );
}
