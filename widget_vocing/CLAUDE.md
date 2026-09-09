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

- `lib/main.dart` define `WidgetVocIngApp` (`MaterialApp`) y `VocabularyScreen` (`StatefulWidget`), que en `initState` carga **toda la lista** de vocabulario de forma asíncrona y selecciona una palabra aleatoria inicial para mostrarla en `VocabularyCard`. Mientras carga, se muestra un `CircularProgressIndicator`. Un `FloatingActionButton` ("Otra palabra") permite pedir otra palabra aleatoria sin reiniciar la app, garantizando que nunca se repita la que está visible en ese momento.
- `lib/models/vocabulary_item.dart` define el modelo `VocabularyItem` (`word`, `pronunciation`, `description`, `translation`, `example`) con `VocabularyItem.fromJson`. `pronunciation` es una fonética intuitiva en español (no símbolos IPA), pensada para que se lea fácil (ej. `óver-uélmd`), y se muestra en `VocabularyCard` justo debajo de la palabra.
- `lib/data/vocabulary_repository.dart` expone `loadVocabulary()`, que lee `assets/data/vocabulary.json` vía `rootBundle` y lo parsea a `List<VocabularyItem>`.
- `assets/data/vocabulary.json` contiene el contenido de vocabulario (actualmente 5 palabras/frases de ejemplo). Está registrado como asset en `pubspec.yaml`. **Para agregar una palabra nueva, solo hay que editar este JSON — no hace falta tocar código.**
- `analysis_options.yaml` excluye `build/**`, `android/**`, `ios/**`, `web/**` del análisis estático y aplica el set de lints `flutter_lints`.
- `test/widget_test.dart` valida, en un único `testWidgets`, que `WidgetVocIngApp` muestre el indicador de carga, luego una tarjeta de vocabulario tras resolver la carga async del asset, y que al tocar el `FloatingActionButton` la palabra mostrada cambie. **Importante:** mantener todas estas aserciones en un solo test — se comprobó que separar la carga inicial y el tap en dos `testWidgets` distintos del mismo archivo provoca que el `pumpAndSettle()` del segundo test cuelgue (timeout), por una interacción entre la carga real de assets vía `rootBundle` y el reloj simulado de `flutter_test` al reutilizarse entre tests.

## Estado del roadmap

- **Etapa 1 (datos separados de la UI): completa.** El contenido vive en `vocabulary.json`, no en `main.dart`.
- **Etapa 2 (hacer la app útil): completa.** Selección de palabra aleatoria al iniciar, botón para cambiar de palabra manualmente (sin repetir la actual), pronunciación en texto (fonética intuitiva) en la tarjeta.
- **Etapa 3 (widget de Android): no iniciada.**
- **Etapa 4 (Lock Screen en iPhone): no iniciada.**

## Posibles features a futuro

Sin etapa numerada asignada todavía — no se van a implementar hasta que el proyecto las retome explícitamente: toggle inglés↔español, favoritos, historial de palabras vistas, pantalla de configuración.
