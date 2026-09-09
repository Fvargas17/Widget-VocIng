# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`widget_vocing` es una app Flutter (SDK ^3.13.2) para aprender vocabulario y frases en inglés de forma pasiva: muestra tarjetas breves (palabra, descripción, traducción, ejemplo de uso) que se pueden consultar rápidamente. El objetivo a largo plazo es que este mismo contenido aparezca en widgets nativos (Android) y en el Lock Screen (iOS), sin backend ni suscripción — todos los datos se almacenan localmente.

## Comandos habituales

```bash
flutter pub get              # instalar dependencias
flutter run                  # ejecutar la app (elige dispositivo/emulador disponible)
flutter analyze              # lint/análisis estático (usa package:flutter_lints/flutter.yaml)
flutter test                 # correr toda la suite de tests
flutter test test/widget_test.dart   # correr un solo archivo de test
flutter build apk            # build Android
flutter build ios            # build iOS (requiere macOS)
```

## Notas de arquitectura

- `lib/main.dart` define `WidgetVocIngApp` (`MaterialApp`) y `VocabularyScreen` (`StatefulWidget`), que en `initState` carga el vocabulario de forma asíncrona y selecciona **una palabra aleatoria** para mostrarla en `VocabularyCard`. Mientras carga, se muestra un `CircularProgressIndicator`.
- `lib/models/vocabulary_item.dart` define el modelo `VocabularyItem` (`word`, `description`, `translation`, `example`) con `VocabularyItem.fromJson`.
- `lib/data/vocabulary_repository.dart` expone `loadVocabulary()`, que lee `assets/data/vocabulary.json` vía `rootBundle` y lo parsea a `List<VocabularyItem>`.
- `assets/data/vocabulary.json` contiene el contenido de vocabulario (actualmente 5 palabras/frases de ejemplo). Está registrado como asset en `pubspec.yaml`. **Para agregar una palabra nueva, solo hay que editar este JSON — no hace falta tocar código.**
- `analysis_options.yaml` excluye `build/**`, `android/**`, `ios/**`, `web/**` del análisis estático y aplica el set de lints `flutter_lints`.
- `test/widget_test.dart` valida que `WidgetVocIngApp` muestre el indicador de carga y luego una tarjeta de vocabulario tras resolver la carga async del asset (usa `pumpAndSettle`).

## Estado del roadmap

- **Etapa 1 (datos separados de la UI): completa.** El contenido vive en `vocabulary.json`, no en `main.dart`.
- **Etapa 2 (hacer la app útil): en progreso.** Ya implementado: selección de palabra aleatoria al iniciar. Pendiente: botón para cambiar de palabra manualmente, toggle inglés↔español, pronunciación, favoritos, historial de palabras vistas, pantalla de configuración.
- **Etapa 3 (widget de Android): no iniciada.**
- **Etapa 4 (Lock Screen en iPhone): no iniciada.**
