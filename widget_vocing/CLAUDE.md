# CLAUDE.md

Guía para Claude Code (claude.ai/code) al trabajar en este repositorio.

## Project overview

`widget_vocing` es una app Flutter (SDK ^3.13.2) para aprender vocabulario y frases en inglés de forma pasiva: tarjetas breves (palabra, pronunciación, descripción, traducción, ejemplo) que se consultan rápido. Sin backend ni suscripción — todo se guarda localmente. El vocabulario base viaja embebido y crece con **packs descargables** (JSON estáticos servidos desde este mismo repo).

## Comandos habituales

```bash
flutter pub get                      # instalar dependencias
flutter run                          # ejecutar la app
flutter analyze                      # lint (flutter_lints)
flutter test                         # suite completa
flutter build apk                    # build Android
python tool/generate_sounds.py       # regenerar los WAV de assets/sounds/
```

## Arquitectura

No hay paquete de manejo de estado (Provider/Riverpod/Bloc): todo es `StatefulWidget` + `setState`, más un único `ValueNotifier` global para el tema. Los servicios son **funciones top-level** sobre `shared_preferences`, sin clases ni caché en memoria.

### Navegación

`lib/main.dart` define `WidgetVocIngApp` con **rutas nombradas**: `/` → `HomeScreen`, `/packs`, `/learned`, `/favorites`, `/settings`. Re-exporta `HomeScreen` y `VocabularyCard` para que `test/widget_test.dart` los importe desde `package:widget_vocing/main.dart`.

`lib/widgets/app_drawer.dart` (`AppDrawer`) es el menú lateral compartido; recibe `currentScreen: AppScreen.…` para resaltar el destino activo y navega con `pushReplacementNamed` — usa rutas nombradas en vez de referenciar los widgets de pantalla para evitar un import circular.

### Pantallas (`lib/screens/`)

- **`home_screen.dart`** — `HomeScreen` + `LearnedFeedbackBadge` + `VocabularyCard`.
  - Delega todo el estado de "palabra actual" en `VocabularyStateService`; solo guarda un `VocabularyStateSnapshot` y el `Set` de favoritos.
  - `body` (dentro de `SafeArea`) = `Column` de dos regiones: un `Expanded > SingleChildScrollView > Align.topCenter` con la card (scrollea solo ella), envuelto en `GestureDetector(onDoubleTap: _markCurrentAsLearned)`; y, **fuera** de ese scroll, un bloque fijo con `LearnedFeedbackBadge` + `FilledButton.icon` "Marcar como aprendida". Su `EdgeInsets.fromLTRB(24, 12, 24, 88)` reserva abajo el espacio donde el `Scaffold` superpone los FAB.
  - Dos `FloatingActionButton` en un `Row` con `floatingActionButtonLocation: centerFloat` (anterior / otra palabra).
  - La card va dentro de un `AnimatedSwitcher` (250 ms, fade + scale 0.94→1) con `key: ValueKey(item.id)`, así cada cambio de palabra se anima.
  - Tras la carga inicial, `_checkForNewPacks()` avisa en un `AlertDialog` si hay packs nuevos ("Ver" → `/packs`) y llama a `dismissPacks()` para no repetir el aviso.
  - `VocabularyCard` recibe `isFavorite` + `onToggleFavorite`; con `onToggleFavorite == null` no dibuja la estrella. La estrella (`Icons.star` / `Icons.star_border`) ocupa **su propia fila** (`Align.centerRight` como primer hijo del `Column`), no un `Stack` superpuesto: así no tapa palabras largas y queda dentro del área que recibe toques.
- **`favorites_screen.dart`** — `FavoritesScreen`. Clon visual de `HomeScreen` con tres diferencias deliberadas: recorre las favoritas **en orden de agregado** (índice local, no aleatorio), **no excluye las aprendidas**, y **no usa `VocabularyStateService`** (no altera la palabra de Inicio ni la del widget nativo). Arriba lleva un `DropdownButton` con todas las favoritas + el conteo en texto pequeño.
- **`learned_words_screen.dart`** — lista las palabras aprendidas con el conteo en el `AppBar` y permite desmarcarlas.
- **`pack_management_screen.dart`** — cruza `fetchRemoteIndex()` con `getDownloadedPackVersions()` para listar todos los packs con su estado (no descargado / actualización disponible / descargado), y permite descargar o eliminar cada uno.
- **`settings_screen.dart`** — una `Card` por ajuste: "Tema de la app" (`DropdownButton` con label arriba y dropdown abajo a todo el ancho — un `ListTile` con el dropdown como `trailing` partía el título en dos líneas) y "Efectos de sonido" (`SwitchListTile`).

Las pantallas de lista envuelven cada fila en un `Card` para que se distinga del fondo con los presets actuales.

### Datos y servicios

- `lib/models/vocabulary_item.dart` — `VocabularyItem` (`id`, `word`, `pronunciation`, `description`, `translation`, `example`) + `fromJson`. `pronunciation` es fonética intuitiva en español, no IPA (ej. `óver-uélmd`).
- `lib/data/vocabulary_repository.dart` — `loadVocabulary()` fusiona el pack base (`assets/data/vocabulary.json` vía `rootBundle`) con los packs descargados en el directorio de documentos, **deduplicando por `id`**. **Para agregar vocabulario base basta editar ese JSON**, sin tocar código.
- `lib/services/vocabulary_state_service.dart` — única fuente de verdad de la palabra actual y su historial (`vocab_state_current_id`, `vocab_state_history_ids`, máx. 10 FIFO). **Ningún método cachea nada**: cada llamada relee `loadVocabulary()` y `getLearnedWordIds()` desde cero, porque el callback del widget nativo corre en un isolate headless nuevo en cada interacción. Cada mutador termina en `_syncWidget()`, que empuja los datos al widget vía `home_widget`.
- `lib/services/learned_words_service.dart` — `learned_word_ids` (`Set`): `getLearnedWordIds`, `markWordAsLearned`, `unmarkWordAsLearned`. Excluye esas palabras del pool aleatorio.
- `lib/services/favorites_service.dart` — `favorite_word_ids` (`List`, **el orden importa**): `getFavoriteWordIds`, `addFavoriteWord`, `removeFavoriteWord`, `toggleFavoriteWord`. Estado paralelo al de aprendidas y al de `VocabularyStateService`.
- `lib/services/sound_service.dart` — `enum AppSound { navigate, learned, favorite }` + `playAppSound()`, sobre `audioplayers` con un único `AudioPlayer` reutilizado. Respeta la preferencia `sounds_enabled` y nunca propaga errores.
- `lib/services/pack_service.dart` — ver "Packs descargables".
- `lib/services/home_widget_callback.dart` — `backgroundCallback(Uri?)`, entry point (`@pragma('vm:entry-point')`) que `home_widget` invoca con la app cerrada. Deliberadamente delgado: interpreta `uri.host` (`next`/`previous`/`learned`) y delega en `VocabularyStateService`, para que app y widget compartan idéntica lógica.

### Sonidos

Los tres WAV de `assets/sounds/` se **sintetizan** con `tool/generate_sounds.py` (stdlib de Python) en vez de traerse de un banco externo: quedan versionados, sin licencias que rastrear, y se reajustan cambiando los parámetros del script. `nav.wav` (blip corto), `learned.wav` (arpegio ascendente), `favorite.wav` (shimmer agudo).

### Sistema de temas (`lib/theme/`)

- `app_theme_roles.dart` — `AppThemeRoles`, el set fijo de 7 colores semánticos que rellena cada preset (`primary`, `accent`, `background`, `card`, `text`, `textSecondary`, `softAccent`). Mantener esta lista corta y estable es lo que permite sumar presets sin tocar nada más.
- `app_theme_builder.dart` — `buildThemeFromRoles()`, **única** función que traduce esos 7 colores a un `ThemeData` Material 3 completo (bordes muy redondeados: 24 en Cards, 20 en FAB/diálogos). No hay lógica de theming duplicada.
- `app_theme_preset.dart` — `AppThemePreset` + el catálogo `appThemePresets` (5 presets: "Serene Wellness" por defecto + 4 variantes claras). `resolveThemePreset(id)` cae al primero si el id guardado ya no existe. Agregar un preset = sumar una entrada.
- `lib/services/theme_notifier.dart` — `selectedThemePresetIdNotifier`, la única pieza de estado reactivo global. Vive aparte de `main.dart` para evitar un import circular con `settings_screen.dart`.
- `lib/services/theme_service.dart` — persiste el id en `selected_theme_preset_id`.

Sin colores hardcodeados: todo sale de `Theme.of(context).colorScheme`.

## Packs de vocabulario descargables (sin backend)

- `content/packs/index.json` — manifiesto (`id`, `name`, `version`, `wordCount`, `file`).
- `content/packs/pack_000N.json` — array de palabras, mismo formato que el pack base, con `id` único por palabra (`pack_000N_000M`).
- La app lee el índice desde **la rama `main`** (`_indexUrl` en `pack_service.dart`): el contenido no está publicado hasta que exista ahí (push directo o merge de PR).
- API: `fetchRemoteIndex()`, `getDownloadedPackVersions()`, `checkForNewPacks()` (todo lo pendiente, la usa `PackManagementScreen`), `checkForNewUndismissedPacks()` (excluye lo ya descartado en el diálogo, la usa `HomeScreen`), `dismissPacks()`, `downloadPack()`, `deletePack()`.
- Usa `HttpClient.connectionTimeout`, **no** `Future.timeout()` — este último no cancela el socket subyacente y deja conexiones colgadas sin red.
- **Publicar contenido nuevo no actualiza apps ya instaladas** si cambió la *lógica* de packs: eso requiere reinstalar. Si solo cambió el JSON, basta publicar en `main` y reabrir la app.
- El chequeo corre una sola vez en `initState`: hay que cerrar la app por completo para que vuelva a correr.
- Plantilla para crear packs nuevos: `Plantilla_Nuevo_Pack_Vocabulario_widget_vocing.md`, en la carpeta de skills de Claude del usuario.

## Widget de Android (menú de apps, no lock screen)

Widget nativo tradicional con el paquete `home_widget`: muestra palabra + pronunciación + ejemplo (sin traducción) y tres botones (siguiente, anterior, aprendida). Comparte el estado persistido de `VocabularyStateService`, así que siempre coincide con `HomeScreen` en ambos sentidos.

- `VocabularyAppWidgetProvider.kt` extiende `HomeWidgetProvider`; rellena un `RemoteViews` con lo que guardó `_syncWidget()` y conecta los botones a `HomeWidgetBackgroundIntent` con URIs `vocabwidget://previous|next|learned`. Tap en el cuerpo abre la app.
- `res/layout/vocabulary_widget_layout.xml` — `LinearLayout` + `TextView`/`Button` planos (`RemoteViews` no soporta `ConstraintLayout` ni Material). Los colores están **hardcodeados** a juego con el preset "Serene Wellness" y **no siguen** el preset que elija el usuario; sincronizarlos requeriría propagar los 7 roles a Kotlin (posible mejora futura).
- `res/xml/vocabulary_widget_info.xml` — `updatePeriodMillis="0"` es intencional: el widget se refresca de forma reactiva tras cada mutación, no por polling.
- `AndroidManifest.xml` declara **a mano** el `<receiver>` del provider, un `<intent-filter>` extra en `MainActivity` para `es.antonborri.home_widget.action.LAUNCH`, y el `HomeWidgetBackgroundReceiver` + `HomeWidgetBackgroundService` del plugin. **El manifest del paquete `home_widget` no los declara**, no se auto-fusionan por manifest merger.
- Para probarlo: instalar, **abrir la app al menos una vez** (puebla el estado inicial), y mantener presionado el home screen → Widgets → "Palabra de vocabulario".

## Trampas conocidas (no deshacer)

- **Flags `debug*` en tests.** `test/widget_test.dart` activa `pack_service.debugDisableNetworkChecks`, `vocabulary_repository.debugSkipDownloadedPacks`, `vocabulary_state_service.debugSkipWidgetSync` y `sound_service.debugDisableSounds`, y llama a `SharedPreferences.setMockInitialValues({})`. **Son obligatorios, no opcionales**: en el entorno de test un `MethodChannel` sin handler no lanza excepción (el `try/catch` la atraparía sin problema) — el mensaje queda en buffer sin resolverse nunca bajo el reloj simulado de `flutter_test`, y `pumpAndSettle()` cuelga.
- **Un solo `testWidgets`.** Mantener todas las aserciones del flujo principal en el mismo test: separar la carga inicial y el tap en dos tests del mismo archivo hace que el `pumpAndSettle()` del segundo cuelgue, por la interacción entre `rootBundle` y el reloj simulado al reutilizarse entre tests.
- **`dependency_overrides: path_provider_foundation: 2.4.1`.** Sin esto, `flutter test`/`flutter build` fallan en esta máquina: el Flutter SDK vive en una ruta con espacio (`C:\SDK Flutter\flutter`), lo que rompe la compilación de "native assets" de `objective_c` (dependencia transitiva de versiones más nuevas de ese paquete).
- **`analysis_options.yaml`** excluye `build/**`, `android/**`, `ios/**`, `web/**`.

## Estado del roadmap

| Etapa | Estado |
|---|---|
| 1 — Datos separados de la UI | completa |
| 2 — App útil (palabra aleatoria, cambiar palabra, pronunciación) | completa |
| 2.5 — Packs descargables + Drawer + `PackManagementScreen` | completa |
| 2.6 — Palabras aprendidas + navegación con historial | completa |
| 3 — Widget de Android | completa |
| 3.5 — Sistema de temas (5 presets, `SettingsScreen`) | completa |
| 3.6 — Favoritos + efectos de sonido | completa |
| 4 — Lock Screen en iPhone | no iniciada |

**Posibles features a futuro** (sin etapa asignada, no implementar hasta que el proyecto las retome): toggle inglés↔español, modo oscuro u otros presets, sincronizar los colores del widget nativo con el preset activo.
