// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:widget_vocing/data/vocabulary_repository.dart'
    as vocabulary_repository;
import 'package:widget_vocing/main.dart';
import 'package:widget_vocing/services/pack_service.dart' as pack_service;

void main() {
  // Los tests no deben depender de red ni de I/O de archivos real (canales
  // de plataforma sin implementación real, y el reloj simulado de
  // flutter_test no puede esperar de forma fiable I/O real): se desactivan
  // el chequeo de packs nuevos (HTTP) y la lectura de packs descargados.
  pack_service.debugDisableNetworkChecks = true;
  vocabulary_repository.debugSkipDownloadedPacks = true;

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
