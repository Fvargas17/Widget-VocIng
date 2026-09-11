// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:widget_vocing/data/vocabulary_repository.dart'
    as vocabulary_repository;
import 'package:widget_vocing/main.dart';
import 'package:widget_vocing/services/pack_service.dart' as pack_service;
import 'package:widget_vocing/services/vocabulary_state_service.dart'
    as vocabulary_state_service;

void main() {
  // Los tests no deben depender de red ni de I/O de archivos real (canales
  // de plataforma sin implementación real, y el reloj simulado de
  // flutter_test no puede esperar de forma fiable I/O real): se desactivan
  // el chequeo de packs nuevos (HTTP), la lectura de packs descargados, y la
  // sincronización con el widget nativo (su MethodChannel sin handler
  // registrado en tests no lanza excepción de inmediato, sino que cuelga
  // pumpAndSettle() indefinidamente).
  pack_service.debugDisableNetworkChecks = true;
  vocabulary_repository.debugSkipDownloadedPacks = true;
  vocabulary_state_service.debugSkipWidgetSync = true;
  // HomeScreen consulta las palabras aprendidas vía shared_preferences en
  // initState; sin este mock, el canal de plataforma real nunca resuelve y
  // pumpAndSettle() queda esperando para siempre.
  SharedPreferences.setMockInitialValues({});

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

      await tester.tap(find.byTooltip('Otra palabra'));
      await tester.pumpAndSettle();

      final secondWord =
          (tester.widget(find.byType(VocabularyCard)) as VocabularyCard)
              .item
              .word;

      expect(secondWord, isNot(equals(firstWord)));
    },
  );
}
