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
  - `VocabularyCard` también recibe `density: CardDensity` (paddings/tipografía escalados vía `_CardSizes`, sin ocultar campos) y `cardGradient: Gradient?` (degradado del preset activo; si es `null`, usa el color plano de `CardThemeData`). Quien la instancia (`HomeScreen`, `FavoritesScreen`) resuelve ambos valores y los pasa por parámetro — la card en sí no lee ningún notifier.
- **`favorites_screen.dart`** — `FavoritesScreen`. Clon visual de `HomeScreen` con tres diferencias deliberadas: recorre las favoritas **en orden de agregado** (índice local, no aleatorio), **no excluye las aprendidas**, y **no usa `VocabularyStateService`** (no altera la palabra de Inicio ni la del widget nativo). Arriba lleva un `DropdownButton` con todas las favoritas + el conteo en texto pequeño.
- **`learned_words_screen.dart`** — lista las palabras aprendidas con el conteo en el `AppBar` y permite desmarcarlas.
- **`pack_management_screen.dart`** — cruza `fetchRemoteIndex()` con `getDownloadedPackVersions()` para listar todos los packs con su estado (no descargado / actualización disponible / descargado), y permite descargar o eliminar cada uno.
- **`settings_screen.dart`** — una `Card` por ajuste: "Tema de la app" (`DropdownButton` con label arriba y dropdown abajo a todo el ancho — un `ListTile` con el dropdown como `trailing` partía el título en dos líneas), "Efectos de sonido" (`SwitchListTile`) y "Modo compacto" (`SwitchListTile`, alterna `CardDensity`). Cambiar preset, modo oscuro o densidad llama a `VocabularyStateService().syncWidgetAppearance()` para empujar el cambio al widget nativo de inmediato — los tres ajustes comparten el mismo método porque ninguno pasa por otro mutador de esa clase.

Las pantallas de lista envuelven cada fila en un `Card` para que se distinga del fondo con los presets actuales.

### Datos y servicios

- `lib/models/vocabulary_item.dart` — `VocabularyItem` (`id`, `word`, `pronunciation`, `description`, `translation`, `example`) + `fromJson`. `pronunciation` es fonética intuitiva en español, no IPA (ej. `óver-uélmd`).
- `lib/data/vocabulary_repository.dart` — `loadVocabulary()` fusiona el pack base (`assets/data/vocabulary.json` vía `rootBundle`) con los packs descargados en el directorio de documentos, **deduplicando por `id`**. **Para agregar vocabulario base basta editar ese JSON**, sin tocar código.
- `lib/services/vocabulary_state_service.dart` — única fuente de verdad de la palabra actual y su historial (`vocab_state_current_id`, `vocab_state_history_ids`, máx. 10 FIFO). **Ningún método cachea nada**: cada llamada relee `loadVocabulary()` y `getLearnedWordIds()` desde cero, porque el callback del widget nativo corre en un isolate headless nuevo en cada interacción. Cada mutador termina en `_syncWidget()`, que empuja los datos al widget vía `home_widget`, incluyendo los 4 colores del preset/modo oscuro activos (`resolveActiveThemeRoles()`) para que `VocabularyAppWidgetProvider.kt` los sincronice. `syncWidgetAppearance()` (alias de `loadState()`) es el punto de entrada que usa `SettingsScreen` cuando cambia preset, modo oscuro o densidad, porque ninguno de esos ajustes pasa por otro mutador de esta clase.
- `lib/services/learned_words_service.dart` — `learned_word_ids` (`Set`): `getLearnedWordIds`, `markWordAsLearned`, `unmarkWordAsLearned`. Excluye esas palabras del pool aleatorio.
- `lib/services/favorites_service.dart` — `favorite_word_ids` (`List`, **el orden importa**): `getFavoriteWordIds`, `addFavoriteWord`, `removeFavoriteWord`, `toggleFavoriteWord`. Estado paralelo al de aprendidas y al de `VocabularyStateService`.
- `lib/services/sound_service.dart` — `enum AppSound { navigate, learned, favorite }` + `playAppSound()`, sobre `audioplayers` con un único `AudioPlayer` reutilizado. Respeta la preferencia `sounds_enabled` y nunca propaga errores.
- `lib/services/pack_service.dart` — ver "Packs descargables".
- `lib/services/card_density_service.dart` / `lib/services/card_density_notifier.dart` — persisten y notifican `CardDensity` (`compact`/`large`, key `card_density`), mismo patrón que `theme_service.dart`/`theme_notifier.dart`. `HomeScreen` y `FavoritesScreen` escuchan `cardDensityNotifier` con su propio `ValueListenableBuilder` (a diferencia del tema, no reconstruyen toda la `MaterialApp`).
- `lib/services/home_widget_callback.dart` — `backgroundCallback(Uri?)`, entry point (`@pragma('vm:entry-point')`) que `home_widget` invoca con la app cerrada. Deliberadamente delgado: interpreta `uri.host` (`next`/`previous`/`learned`) y delega en `VocabularyStateService`, para que app y widget compartan idéntica lógica.

### Sonidos

Los tres WAV de `assets/sounds/` se **sintetizan** con `tool/generate_sounds.py` (stdlib de Python) en vez de traerse de un banco externo: quedan versionados, sin licencias que rastrear, y se reajustan cambiando los parámetros del script. `nav.wav` (blip corto), `learned.wav` (arpegio ascendente), `favorite.wav` (shimmer agudo).

### Sistema de temas (`lib/theme/`)

- `app_theme_roles.dart` — `AppThemeRoles`, el set fijo de 7 colores semánticos que rellena cada preset (`primary`, `accent`, `background`, `card`, `text`, `textSecondary`, `softAccent`). Mantener esta lista corta y estable es lo que permite sumar presets sin tocar nada más.
- `app_theme_builder.dart` — `buildThemeFromRoles()`, **única** función que traduce esos 7 colores a un `ThemeData` Material 3 completo (bordes muy redondeados: 24 en Cards, 20 en FAB/diálogos). No hay lógica de theming duplicada. Recibe `brightness` (`Brightness.light` por defecto): con `Brightness.dark` arma el `ColorScheme` con `ColorScheme.dark(...)` en vez de `.light(...)` y usa `ThemeData.dark().textTheme` como base — el resto de la función es idéntico, así que la variante oscura de un preset no duplica lógica, solo le pasa otros 7 colores.
- `app_theme_preset.dart` — `AppThemePreset` + el catálogo `appThemePresets` (5 presets: "Serene Wellness" por defecto + 4 variantes claras), construido con el helper interno `_buildPreset()` para no repetir la derivación en cada entrada. `resolveThemePreset(id)` cae al primero si el id guardado ya no existe. Cada preset guarda `roles`/`darkRoles` (los `AppThemeRoles` crudos, uno por `Brightness`) además de los campos derivados: `themeData`/`darkThemeData` (vía `buildThemeFromRoles`) y `cardGradient`/`darkCardGradient` (`LinearGradient` de `card` a `softAccent`, generado con `_cardSkin()`) que consume `VocabularyCard`. Agregar un preset = sumar una entrada con sus roles claros y oscuros. `resolveActiveCardGradient(presetId, darkModeEnabled)` es el helper que `HomeScreen`/`FavoritesScreen` usan para elegir entre ambos gradientes sin repetir el `if`; `resolveActiveThemeRoles(presetId, darkModeEnabled)` es su equivalente para los colores planos, que usa `VocabularyStateService._syncWidget()` porque el widget nativo no puede leer `Theme.of(context)`.
- `lib/services/theme_notifier.dart` — `selectedThemePresetIdNotifier`, pieza de estado reactivo global para el preset elegido. Vive aparte de `main.dart` para evitar un import circular con `settings_screen.dart`.
- `lib/services/theme_service.dart` — persiste el id en `selected_theme_preset_id`.
- `lib/services/dark_mode_notifier.dart` / `lib/services/dark_mode_service.dart` — `darkModeNotifier` (`ValueNotifier<bool>`) + persistencia en `dark_mode_enabled`, mismo patrón que el preset de tema. Es **independiente** del preset: cualquiera de los 5 presets tiene su propia variante oscura, así que "Modo oscuro" en `SettingsScreen` es un solo `SwitchListTile` que no interfiere con el `DropdownButton` de "Tema de la app". `WidgetVocIngApp` en `main.dart` anida un segundo `ValueListenableBuilder<bool>` sobre `darkModeNotifier` (dentro del que ya escuchaba `selectedThemePresetIdNotifier`) y elige `preset.darkThemeData` o `preset.themeData`.

Sin colores hardcodeados: todo sale de `Theme.of(context).colorScheme`. El modo oscuro no toca el widget nativo de Android (sigue con los colores hardcodeados de "Serene Wellness" en claro, ver sección de abajo).

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

- `VocabularyAppWidgetProvider.kt` extiende `HomeWidgetProvider`; rellena un `RemoteViews` con lo que guardó `_syncWidget()` y conecta los botones a `HomeWidgetBackgroundIntent` con URIs `vocabwidget://previous|next|learned`. Tap en el cuerpo abre la app. `onUpdate` elige entre `R.layout.vocabulary_widget_layout` y `R.layout.vocabulary_widget_layout_compact` según `widgetData.getBoolean("widget_compact_mode", false)` — ambos layouts comparten los mismos ids, así que el resto de la lógica no cambia según cuál se infle. También lee 4 colores (`widget_color_card/button/text/text_secondary`, con los de "Serene Wellness" como fallback si nunca se abrió la app) y los aplica con el helper privado `RemoteViews.tintBackground()`: en API 31+ usa `setColorStateList(..., "setBackgroundTintList", ...)` para teñir el `shape` de `widget_card_background.xml`/`widget_button_background.xml` sin perder las esquinas redondeadas; en versiones anteriores cae a `setInt(..., "setBackgroundColor", ...)`, que sincroniza el color pero pierde el radio de esquina (no hay forma de aplicar `ColorStateList` a un `RemoteViews` antes de API 31). El texto usa `setTextColor()` directo, sin ese problema de versión. **Estos colores viajan como string `#AARRGGBB`, nunca como `int`**: `Color.toARGB32()` da valores que superan el rango de un `Int32` con signo (canal alfa `0xFF`), así que el codec estándar de Flutter los serializa como `Long` del lado de Kotlin en vez de `Int`, y `HomeWidgetPlugin` los guarda con el tipo que reciba — leerlos siempre con `getInt()` revienta con `ClassCastException` dentro de `onUpdate()` (que corre en el proceso de la app, no del launcher, así que tumba la app entera, no solo el widget). `parseWidgetColor()` en `VocabularyAppWidgetProvider.kt` decodifica el string con `Color.parseColor()` y además atrapa `ClassCastException` al leer, por si una instalación previa dejó la clave guardada con el tipo viejo.
- `res/layout/vocabulary_widget_layout.xml` (y su par `vocabulary_widget_layout_compact.xml`, mismos ids con tamaños/paddings menores) — `LinearLayout` + `TextView`/`Button` planos (`RemoteViews` no soporta `ConstraintLayout` ni Material, y tampoco `ScrollView` de forma confiable — no está en la lista de layouts que `RemoteViews` garantiza soportar, así que no se usa). Los colores del XML son solo placeholders: `onUpdate` los sobreescribe siempre con el preset activo. Palabra/pronunciación/ejemplo viven en un `LinearLayout` interno con `layout_height="0dp"` + `layout_weight="1"`, así absorbe toda la altura sobrante del widget y la fila de botones (siempre `wrap_content`, sin weight) nunca se desplaza sin importar cuánto texto haya; cada `TextView` tiene `maxLines`/`ellipsize="end"` para recortar en vez de desbordar.
- `res/xml/vocabulary_widget_info.xml` — `updatePeriodMillis="0"` es intencional: el widget se refresca de forma reactiva tras cada mutación, no por polling.
- `AndroidManifest.xml` declara **a mano** el `<receiver>` del provider, un `<intent-filter>` extra en `MainActivity` para `es.antonborri.home_widget.action.LAUNCH`, y el `HomeWidgetBackgroundReceiver` + `HomeWidgetBackgroundService` del plugin. **El manifest del paquete `home_widget` no los declara**, no se auto-fusionan por manifest merger.
- Para probarlo: instalar, **abrir la app al menos una vez** (puebla el estado inicial), y mantener presionado el home screen → Widgets → "Palabra de vocabulario".

## Ícono de la app y splash screen

- `assets/branding/venado_source.png` — arte original (venado bioluminiscente en un bosque nocturno) tal como lo compartió el usuario, en 1024×1536. Se conserva sin recortar por si se necesita regenerar el crop.
- `assets/branding/icon_square.png` — recorte cuadrado (1024×1024) de esa imagen, centrado en cornamenta/cabeza/pecho del venado. Es el único archivo que consumen tanto `flutter_launcher_icons` como `flutter_native_splash` (configurados al final de `pubspec.yaml`).
- Color de fondo `#015955` (muestreado de la niebla teal de la propia imagen) para el ícono adaptativo de Android y el splash — así ambos comparten identidad visual con el arte.
- Regenerar tras cambiar la imagen: `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`. Ambos comandos **escriben directamente** sobre `android/`, `ios/` y `web/` (mipmap/launch_background/styles.xml, AppIcon.appiconset, favicons) — no hay que tocar esos archivos a mano.

## Trampas conocidas (no deshacer)

- **Flags `debug*` en tests.** `test/widget_test.dart` activa `pack_service.debugDisableNetworkChecks`, `vocabulary_repository.debugSkipDownloadedPacks`, `vocabulary_state_service.debugSkipWidgetSync` y `sound_service.debugDisableSounds`, y llama a `SharedPreferences.setMockInitialValues({})`. **Son obligatorios, no opcionales**: en el entorno de test un `MethodChannel` sin handler no lanza excepción (el `try/catch` la atraparía sin problema) — el mensaje queda en buffer sin resolverse nunca bajo el reloj simulado de `flutter_test`, y `pumpAndSettle()` cuelga.
- **Un solo `testWidgets`.** Mantener todas las aserciones del flujo principal en el mismo test: separar la carga inicial y el tap en dos tests del mismo archivo hace que el `pumpAndSettle()` del segundo cuelgue, por la interacción entre `rootBundle` y el reloj simulado al reutilizarse entre tests.
- **`dependency_overrides: path_provider_foundation: 2.4.1`.** Sin esto, `flutter test`/`flutter build` fallan en esta máquina: el Flutter SDK vive en una ruta con espacio (`C:\SDK Flutter\flutter`), lo que rompe la compilación de "native assets" de `objective_c` (dependencia transitiva de versiones más nuevas de ese paquete).
- **`analysis_options.yaml`** excluye `build/**`, `android/**`, `ios/**`, `web/**`.
- **El isolate headless del widget no es nuevo en cada toque.** `HomeWidgetBackgroundService.kt` (dentro del paquete `home_widget`, no de este repo) guarda el `FlutterEngine` del callback en un `companion object` y lo reutiliza mientras el proceso siga vivo — solo se crea una vez, la primera vez que se toca un botón del widget. Como `SharedPreferences.getInstance()` (API legacy del paquete `shared_preferences`) cachea todas las claves en memoria la primera vez que se llama **por isolate**, ese isolate reutilizado nunca ve cambios que la app en primer plano escriba después (p. ej. cambiar el preset de tema en Configuración mientras el widget ya estaba "caliente"). Por eso `VocabularyStateService._freshPrefs()` siempre llama `reload()` antes de leer cualquier clave — quitarlo revive el bug (el widget se queda pegado al snapshot de la primera interacción).
- **Colores hacia el widget nativo van como string `#AARRGGBB`, nunca como `int`.** `Color.toARGB32()` da valores que superan el rango de un `Int32` con signo (canal alfa `0xFF`), así que el codec estándar de Flutter los serializa como `Long` del lado de Kotlin en vez de `Int`; `HomeWidgetPlugin` los guarda con el tipo que reciba, y leerlos siempre con `getInt()` revienta con `ClassCastException` **dentro de `onUpdate()`, que corre en el proceso de la app** (no del launcher) — así que no solo falla el widget, tumba la app entera. Ver `_colorToHex()` en `vocabulary_state_service.dart` y `parseWidgetColor()` en `VocabularyAppWidgetProvider.kt`.

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
| 3.7 — Modo compacto (app + widget nativo) + skins de tarjeta por preset | completa |
| 3.8 — Modo oscuro (variante por preset) + ícono de app y splash screen | completa |
| 3.9 — Sincronizar colores del widget nativo con el preset/modo oscuro activos | completa |
| 4 — Lock Screen en iPhone | no iniciada |

**Posibles features a futuro** (sin etapa asignada, no implementar hasta que el proyecto las retome). Backlog visual completo (2026-09-24), agrupado por categoría:

*Personalización del widget y la app:*
- Selector de tipografía (2-3 fuentes, ej. una editorial para las palabras y una neutra para el resto).
- Toggle inglés↔español.

*(Implementados en la etapa 3.7: tamaños de widget/tarjeta configurables y fondos/skins temáticos para `VocabularyCard` — ver `card_density_service.dart`/`card_density_notifier.dart` y `AppThemePreset.cardGradient`. Implementado en la etapa 3.9: sincronización de colores del widget nativo — ver `resolveActiveThemeRoles()` y `VocabularyAppWidgetProvider.tintBackground()`.)*

*Microinteracciones y feedback:*
- Feedback háptico (vibración), complementando los sonidos de `sound_service.dart`.
- Animación de "voltear" la tarjeta (flip 3D) al cambiar de palabra o revelar traducción/ejemplo, en vez de solo el fade+scale del `AnimatedSwitcher` actual.
- Micro-confeti o partículas al marcar una palabra como aprendida (celebración breve, no gamificación de puntos).
- Swipe gestures para navegar entre palabras (hoy solo hay botones y doble tap).
- Transiciones compartidas (Hero) entre pantallas, ej. de `HomeScreen` a `learned_words_screen.dart`.
- Estados vacíos ilustrados en favoritos/aprendidas cuando no hay contenido.

*Visualización de progreso y datos:*
- Gráfica de palabras aprendidas por día/semana.
- Mapa de calor de actividad diaria (estilo calendario de contribuciones).
- Barra o anillo de progreso por pack en `pack_management_screen.dart` (aprendidas vs. total).
- Resumen visual al cerrar una sesión de estudio ("hoy aprendiste N palabras nuevas").

*Descartado por ahora (revisar si cambia de opinión):* gamificación con rachas/XP/medallas.
