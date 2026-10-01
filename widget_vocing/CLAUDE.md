# CLAUDE.md

Guía para Claude Code (claude.ai/code) al trabajar en este repositorio.

## Project overview

`widget_vocing` es una app Flutter (SDK ^3.13.2) para aprender vocabulario y frases de otro idioma de forma pasiva: tarjetas breves (palabra, pronunciación, descripción, traducción, ejemplo) que se consultan rápido. Sin backend ni suscripción — todo se guarda localmente. El vocabulario base viaja embebido y crece con **packs descargables** (JSON estáticos servidos desde este mismo repo).

Maneja **cursos de idioma** (hoy Español → Inglés e Inglés → Francés): el curso elegido define tanto qué vocabulario se ve como el idioma de la interfaz. Ver "Cursos de idioma" más abajo.

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

No hay paquete de manejo de estado (Provider/Riverpod/Bloc): todo es `StatefulWidget` + `setState`, más un `ValueNotifier` global por preferencia que afecte a varias pantallas (tema, modo oscuro, densidad, mascota, curso de idioma). Los servicios son **funciones top-level** sobre `shared_preferences`, sin clases ni caché en memoria.

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
  - Debajo de la card, antes del bloque fijo de "Marcar como aprendida", vive `PetCompanion` (ver sección "Mascota de compañía" más abajo). Solo aparece en `HomeScreen` — decisión deliberada, `FavoritesScreen` no la incluye.
- **`favorites_screen.dart`** — `FavoritesScreen`. Clon visual de `HomeScreen` con tres diferencias deliberadas: recorre las favoritas **en orden de agregado** (índice local, no aleatorio), **no excluye las aprendidas**, y **no usa `VocabularyStateService`** (no altera la palabra de Inicio ni la del widget nativo). Arriba lleva un `DropdownButton` con todas las favoritas + el conteo en texto pequeño. Sí comparte el filtro por curso: las favoritas del otro idioma no aparecen porque sus ids no se resuelven contra el catálogo activo.
- **`learned_words_screen.dart`** — lista las palabras aprendidas con el conteo en el `AppBar` y permite desmarcarlas. También filtrada por curso (el conteo es por curso).
- **`pack_management_screen.dart`** — cruza `fetchRemoteIndex()` con `getDownloadedPackVersions()` para listar los packs **del curso activo** con su estado (no descargado / actualización disponible / descargado), y permite descargar o eliminar cada uno. Guarda `_loadFailed` (bool) en vez del texto del error, para que el mensaje se resuelva en `build` y siga el idioma activo.
- **`settings_screen.dart`** — una `Card` por ajuste: "Idioma" (primero de la lista, `DropdownButton<LanguageCourse>`), "Tema de la app" (`DropdownButton` con label arriba y dropdown abajo a todo el ancho — un `ListTile` con el dropdown como `trailing` partía el título en dos líneas), "Mascota", "Modo oscuro", "Efectos de sonido" (`SwitchListTile`) y "Modo compacto" (`SwitchListTile`, alterna `CardDensity`). Cambiar preset, modo oscuro o densidad llama a `VocabularyStateService().syncWidgetAppearance()` para empujar el cambio al widget nativo de inmediato — los tres ajustes comparten el mismo método porque ninguno pasa por otro mutador de esa clase. Cambiar de idioma llama a `resetCourseState()` en vez de eso, porque además hay que olvidar la palabra actual y el historial del curso anterior.

Las pantallas de lista envuelven cada fila en un `Card` para que se distinga del fondo con los presets actuales.

### Datos y servicios

- `lib/models/vocabulary_item.dart` — `VocabularyItem` (`id`, `word`, `pronunciation`, `description`, `translation`, `example`, `course`) + `fromJson`. `pronunciation` es fonética intuitiva en el idioma base del curso, no IPA (ej. `óver-uélmd` en ES→EN, `ray-ew-SEER` en EN→FR). `course` ausente en el JSON ⇒ `esEn`, para que los packs descargados antes de esta etapa sigan funcionando.
- `lib/data/vocabulary_repository.dart` — `loadVocabulary(course)` fusiona el pack base de ese curso (`assets/data/vocabulary_<course>.json` vía `rootBundle`) con los packs descargados en el directorio de documentos, filtrando por `item.course` y **deduplicando por `id`**. El filtro va por palabra y no por nombre de archivo porque los packs descargados se descubren escaneando el directorio. **Para agregar vocabulario base basta editar el JSON del curso**, sin tocar código.
- `lib/services/vocabulary_state_service.dart` — única fuente de verdad de la palabra actual y su historial (`vocab_state_current_id`, `vocab_state_history_ids`, máx. 10 FIFO). **Ningún método cachea nada**: cada llamada relee `loadVocabulary()` y `getLearnedWordIds()` desde cero, porque el callback del widget nativo corre en un isolate headless nuevo en cada interacción. Cada mutador termina en `_syncWidget()`, que empuja los datos al widget vía `home_widget`, incluyendo los 4 colores del preset/modo oscuro activos (`resolveActiveThemeRoles()`) para que `VocabularyAppWidgetProvider.kt` los sincronice, y el texto de estado vacío ya traducido (`widget_empty_text`). `syncWidgetAppearance()` (alias de `loadState()`) es el punto de entrada que usa `SettingsScreen` cuando cambia preset, modo oscuro o densidad, porque ninguno de esos ajustes pasa por otro mutador de esta clase; `resetCourseState()` es el equivalente para el cambio de idioma (borra palabra actual + historial y recarga). **Todas las lecturas de preferencias van después de `_freshPrefs()`** — ver la trampa correspondiente abajo.
- `lib/services/language_course_service.dart` / `lib/services/language_course_notifier.dart` — persisten y notifican `LanguageCourse` (key `selected_language_course`), mismo patrón que `pet_service.dart`/`pet_notifier.dart`. El enum **no** vive en el service (a diferencia de `Pet` o `CardDensity`): está en `lib/models/language_course.dart` porque `VocabularyItem` lo necesita y la capa de modelos no debe importar servicios.
- `lib/services/learned_words_service.dart` — `learned_word_ids` (`Set`): `getLearnedWordIds`, `markWordAsLearned`, `unmarkWordAsLearned`. Excluye esas palabras del pool aleatorio.
- `lib/services/favorites_service.dart` — `favorite_word_ids` (`List`, **el orden importa**): `getFavoriteWordIds`, `addFavoriteWord`, `removeFavoriteWord`, `toggleFavoriteWord`. Estado paralelo al de aprendidas y al de `VocabularyStateService`.
- `lib/services/sound_service.dart` — `enum AppSound { navigate, learned, favorite }` + `playAppSound()`, sobre `audioplayers` con un único `AudioPlayer` reutilizado. Respeta la preferencia `sounds_enabled` y nunca propaga errores.
- `lib/services/pack_service.dart` — ver "Packs descargables".
- `lib/services/card_density_service.dart` / `lib/services/card_density_notifier.dart` — persisten y notifican `CardDensity` (`compact`/`large`, key `card_density`), mismo patrón que `theme_service.dart`/`theme_notifier.dart`. `HomeScreen` y `FavoritesScreen` escuchan `cardDensityNotifier` con su propio `ValueListenableBuilder` (a diferencia del tema, no reconstruyen toda la `MaterialApp`).
- `lib/services/home_widget_callback.dart` — `backgroundCallback(Uri?)`, entry point (`@pragma('vm:entry-point')`) que `home_widget` invoca con la app cerrada. Deliberadamente delgado: interpreta `uri.host` (`next`/`previous`/`learned`) y delega en `VocabularyStateService`, para que app y widget compartan idéntica lógica.
- `lib/services/pet_service.dart` / `lib/services/pet_notifier.dart` — persisten y notifican `Pet` (`reno`/`pollito`/`gato`, key `selected_pet`), mismo patrón que `card_density_service.dart`/`card_density_notifier.dart`. `SplashScreen._bootstrap()` carga el valor guardado en `petNotifier` al arrancar (igual que tema/densidad/modo oscuro/curso); `SettingsScreen` lo actualiza al elegir mascota.

### Cursos de idioma (`lib/models/language_course.dart`)

`LanguageCourse` es un enum "enhanced" con todo lo que define un curso: su `id` (persistido en prefs y escrito en el campo `course` de cada palabra), su `uiLocale` y su `name` (`LocalizedText`). Hoy: `esEn` (Español → Inglés) y `enFr` (Inglés → Francés). **Agregar un curso = una entrada en el enum + sus archivos de contenido + su asset base en `_vocabularyAssetPaths`.**

Qué idioma va en cada campo de `VocabularyItem` según el curso:

| curso | `word` | `pronunciation` | `description` | `translation` | `example` | UI de la app |
|---|---|---|---|---|---|---|
| `es_en` | inglés | fonética en español | inglés | español | inglés | español |
| `en_fr` | francés | fonética en inglés | francés | inglés | francés | inglés |

Es decir: `description` siempre en el idioma que se aprende, `translation` en el idioma del que se parte.

Dos decisiones de diseño que conviene no deshacer:

- **El idioma de la UI se deriva del curso** (`LanguageCourse.uiLocale`), no es un ajuste aparte. Un solo toggle en Configuración cambia vocabulario e interfaz a la vez; por eso solo hay strings en español e inglés (ningún curso parte del francés). Si algún día hace falta desacoplarlos, el cambio es agregar su propio notifier para el locale y dejar de leerlo del curso.
- **El progreso queda separado por curso sin tocar `learned_words_service.dart` ni `favorites_service.dart`**: los ids llevan prefijo propio (`base_fr_…`, `pack_fr_000N_…`) y `loadVocabulary(course)` filtra, así que las pantallas de aprendidas/favoritas solo resuelven los ids del catálogo activo. No hay claves de prefs por curso.

Al cambiar de curso se pierde la palabra actual y el historial (`resetCourseState()`): hay una sola clave `vocab_state_current_id`, sin sufijo por curso. Fue deliberado para no tener que migrar la clave; sufijarla es la mejora si molesta en uso real.

### Localización (`lib/l10n/`)

- `app_locale.dart` — `enum AppLocale { es, en }` (idiomas de **interfaz**, no de estudio) + `LocalizedText`, un texto con sus dos variantes obligatorias por constructor. `LocalizedText` se usa para los nombres que viven dentro de un catálogo de datos (presets de tema, mascotas, cursos), para que el nombre siga junto a la cosa que nombra.
- `app_strings.dart` — `AppStrings`, todos los textos de pantalla. Cada string declara **sus dos idiomas en la misma línea** (`_t(es: …, en: …)`) en vez de haber un archivo por idioma: así es imposible que una traducción se quede atrás, y el compilador obliga a llenar ambas. No se usa `gen_l10n`/ARB a propósito (no hace falta codegen para 2 idiomas, y el proyecto ya declara sus catálogos como datos en Dart). Incluye su propio `LocalizationsDelegate` (resuelve con `SynchronousFuture`, sin frame de retraso) y `appStringsFor(locale)` para consumidores sin `BuildContext` (el texto que se empuja al widget nativo).
- Las pantallas leen `AppStrings.of(context)`; `MaterialApp` recibe `locale` desde `languageCourseNotifier` y suma `GlobalMaterialLocalizations.delegate` y compañía (`flutter_localizations`) para los textos propios de Material.
- Cambiar de curso reconstruye la `MaterialApp` completa, así que **ninguna pantalla necesita escuchar `languageCourseNotifier`**.

### Sonidos

Los tres WAV de `assets/sounds/` se **sintetizan** con `tool/generate_sounds.py` (stdlib de Python) en vez de traerse de un banco externo: quedan versionados, sin licencias que rastrear, y se reajustan cambiando los parámetros del script. `nav.wav` (blip corto), `learned.wav` (arpegio ascendente), `favorite.wav` (shimmer agudo).

### Mascota de compañía (`lib/pets/`, `lib/widgets/pet_companion.dart`)

Feature sin utilidad funcional, a propósito: un distintivo de marca inspirado en las mascotas de extensiones de IDE (y, más lejos, en herramientas de streaming tipo Stream Avatars/Triiibe/Kappamon, pero sin chat ni multiusuario — aquí es una sola mascota por persona). Vive en una caja con solo bordes debajo de la card de `HomeScreen`.

- `lib/pets/pet_catalog.dart` — `PetVisual` (hoy solo `displayName`, un `LocalizedText`, + `emoji`) y el mapa `petCatalog: Map<Pet, PetVisual>`. Es la única capa que sabe que hoy la mascota es un emoji; el día que haya pixel art con animaciones, el cambio se limita a esta capa y al render dentro de `PetCompanion`, sin tocar el catálogo de mascotas (`Pet` enum) ni cómo se persiste/elige.
- `lib/widgets/pet_companion.dart` — `PetCompanion({pet, density, celebrationSignal})`, `StatefulWidget` con dos `AnimationController` independientes:
  - **Paseo**: `repeat(reverse: true)` sobre un `Tween` mapeado al ancho disponible.
  - **Gravedad real**: suscripción a `accelerometerEventStream()` (`sensors_plus`) sobre el eje `x`, suavizada (low-pass). La gravedad pesa más que el paseo a propósito: `paceInfluence = 1 - |tiltBias|` apaga el paseo cuando la inclinación es fuerte, para que la mascota no "escale" contra la inclinación al llegar a una esquina.
  - **Celebración**: un tercer control, finito (no `repeat`), disparado en `didUpdateWidget` cuando cambia `celebrationSignal` — un contador que `HomeScreen` incrementa dentro de `_markCurrentAsLearned`.
  - `density: CardDensity` solo se usa para calcular el margen lateral (12/24, igual que `_CardSizes.margin` de `VocabularyCard`), así la caja de la mascota se ve del mismo ancho que la card de arriba.
  - `@visibleForTesting bool debugDisablePetMotion` — **obligatorio en tests**, mismo motivo que `debugDisableSounds`: un `AnimationController.repeat()` nunca "asienta", así que `pumpAndSettle()` colgaría indefinidamente si `HomeScreen` incluye la mascota por defecto.
- Ideas de mejora ya exploradas pero no implementadas (sprites con ciclos de animación, física con velocidad/inercia real, etc.): ver `docs/pet_companion_roadmap.md`.

### Sistema de temas (`lib/theme/`)

- `app_theme_roles.dart` — `AppThemeRoles`, el set fijo de 7 colores semánticos que rellena cada preset (`primary`, `accent`, `background`, `card`, `text`, `textSecondary`, `softAccent`). Mantener esta lista corta y estable es lo que permite sumar presets sin tocar nada más.
- `app_theme_builder.dart` — `buildThemeFromRoles()`, **única** función que traduce esos 7 colores a un `ThemeData` Material 3 completo (bordes muy redondeados: 24 en Cards, 20 en FAB/diálogos). No hay lógica de theming duplicada. Recibe `brightness` (`Brightness.light` por defecto): con `Brightness.dark` arma el `ColorScheme` con `ColorScheme.dark(...)` en vez de `.light(...)` y usa `ThemeData.dark().textTheme` como base — el resto de la función es idéntico, así que la variante oscura de un preset no duplica lógica, solo le pasa otros 7 colores.
- `app_theme_preset.dart` — `AppThemePreset` + el catálogo `appThemePresets` (5 presets: "Bosque Luminoso" por defecto + 4 variantes claras), construido con el helper interno `_buildPreset()` para no repetir la derivación en cada entrada. `resolveThemePreset(id)` cae al primero si el id guardado ya no existe. `displayName` es un `LocalizedText`, así que un preset nuevo pide su nombre en los dos idiomas de interfaz. Cada preset guarda `roles`/`darkRoles` (los `AppThemeRoles` crudos, uno por `Brightness`) además de los campos derivados: `themeData`/`darkThemeData` (vía `buildThemeFromRoles`) y `cardGradient`/`darkCardGradient` (`LinearGradient` de `card` a `softAccent`, generado con `_cardSkin()`) que consume `VocabularyCard`. Agregar un preset = sumar una entrada con sus roles claros y oscuros. `resolveActiveCardGradient(presetId, darkModeEnabled)` es el helper que `HomeScreen`/`FavoritesScreen` usan para elegir entre ambos gradientes sin repetir el `if`; `resolveActiveThemeRoles(presetId, darkModeEnabled)` es su equivalente para los colores planos, que usa `VocabularyStateService._syncWidget()` porque el widget nativo no puede leer `Theme.of(context)`.
- `lib/services/theme_notifier.dart` — `selectedThemePresetIdNotifier`, pieza de estado reactivo global para el preset elegido. Vive aparte de `main.dart` para evitar un import circular con `settings_screen.dart`.
- `lib/services/theme_service.dart` — persiste el id en `selected_theme_preset_id`.
- `lib/services/dark_mode_notifier.dart` / `lib/services/dark_mode_service.dart` — `darkModeNotifier` (`ValueNotifier<bool>`) + persistencia en `dark_mode_enabled`, mismo patrón que el preset de tema. Es **independiente** del preset: cualquiera de los 5 presets tiene su propia variante oscura, así que "Modo oscuro" en `SettingsScreen` es un solo `SwitchListTile` que no interfiere con el `DropdownButton` de "Tema de la app". `WidgetVocIngApp` en `main.dart` anida tres `ValueListenableBuilder` (preset → modo oscuro → curso de idioma) y de ellos saca `theme` y `locale`.

Sin colores hardcodeados: todo sale de `Theme.of(context).colorScheme`. El modo oscuro no toca el widget nativo de Android (sigue con los colores hardcodeados de "Bosque Luminoso" en claro, ver sección de abajo).

## Packs de vocabulario descargables (sin backend)

- `content/packs/index.json` — manifiesto (`id`, `course`, `name`, `version`, `wordCount`, `file`). `name` va en el idioma base del curso del pack (los packs `en_fr` tienen nombre en inglés) y por eso no se traduce; `course` ausente ⇒ `es_en`.
- `content/packs/pack_000N.json` (ES→EN) y `content/packs/pack_fr_000N.json` (EN→FR) — array de palabras, mismo formato que el pack base, con `course` en cada palabra e `id` único (`pack_000N_000M` / `pack_fr_000N_000M`). Los prefijos distintos son lo que mantiene separado el progreso entre cursos.
- La app lee el índice desde **la rama `main`** (`_indexUrl` en `pack_service.dart`): el contenido no está publicado hasta que exista ahí (push directo o merge de PR).
- API: `fetchRemoteIndex()` (todo el índice, sin filtrar), `getDownloadedPackVersions()`, `checkForNewPacks({course})` (todo lo pendiente de ese curso), `checkForNewUndismissedPacks({course})` (excluye lo ya descartado en el diálogo, la usa `HomeScreen`), `dismissPacks()`, `downloadPack()`, `deletePack()`. `PackManagementScreen` filtra el índice por curso por su cuenta, porque necesita ver también los packs ya descargados.
- Usa `HttpClient.connectionTimeout`, **no** `Future.timeout()` — este último no cancela el socket subyacente y deja conexiones colgadas sin red.
- **Publicar contenido nuevo no actualiza apps ya instaladas** si cambió la *lógica* de packs: eso requiere reinstalar. Si solo cambió el JSON, basta publicar en `main` y reabrir la app.
- El chequeo corre una sola vez en `initState`: hay que cerrar la app por completo para que vuelva a correr.
- Plantilla para crear packs nuevos: `Plantilla_Nuevo_Pack_Vocabulario_widget_vocing.md`, en la carpeta de skills de Claude del usuario.

## Widget de Android (menú de apps, no lock screen)

Widget nativo tradicional con el paquete `home_widget`: muestra palabra + pronunciación + ejemplo (sin traducción) y tres botones (siguiente, anterior, aprendida). Comparte el estado persistido de `VocabularyStateService`, así que siempre coincide con `HomeScreen` en ambos sentidos.

- `VocabularyAppWidgetProvider.kt` extiende `HomeWidgetProvider`; rellena un `RemoteViews` con lo que guardó `_syncWidget()` y conecta los botones a `HomeWidgetBackgroundIntent` con URIs `vocabwidget://previous|next|learned`. Tap en el cuerpo abre la app. `onUpdate` elige entre `R.layout.vocabulary_widget_layout` y `R.layout.vocabulary_widget_layout_compact` según `widgetData.getBoolean("widget_compact_mode", false)` — ambos layouts comparten los mismos ids, así que el resto de la lógica no cambia según cuál se infle. También lee 4 colores (`widget_color_card/button/text/text_secondary`, con los de "Bosque Luminoso" como fallback si nunca se abrió la app) y los aplica con el helper privado `RemoteViews.tintBackground()`: en API 31+ usa `setColorStateList(..., "setBackgroundTintList", ...)` para teñir el `shape` de `widget_card_background.xml`/`widget_button_background.xml` sin perder las esquinas redondeadas; en versiones anteriores cae a `setInt(..., "setBackgroundColor", ...)`, que sincroniza el color pero pierde el radio de esquina (no hay forma de aplicar `ColorStateList` a un `RemoteViews` antes de API 31). El texto usa `setTextColor()` directo, sin ese problema de versión. **Estos colores viajan como string `#AARRGGBB`, nunca como `int`**: `Color.toARGB32()` da valores que superan el rango de un `Int32` con signo (canal alfa `0xFF`), así que el codec estándar de Flutter los serializa como `Long` del lado de Kotlin en vez de `Int`, y `HomeWidgetPlugin` los guarda con el tipo que reciba — leerlos siempre con `getInt()` revienta con `ClassCastException` dentro de `onUpdate()` (que corre en el proceso de la app, no del launcher, así que tumba la app entera, no solo el widget). `parseWidgetColor()` en `VocabularyAppWidgetProvider.kt` decodifica el string con `Color.parseColor()` y además atrapa `ClassCastException` al leer, por si una instalación previa dejó la clave guardada con el tipo viejo. El único texto fijo del widget (el estado "todo aprendido") también llega desde Dart, en `widget_empty_text`, porque su idioma depende del curso activo; el Kotlin solo guarda el default en español para el caso de agregar el widget sin haber abierto nunca la app.
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
- **Un solo `testWidgets`** en `test/widget_test.dart`. Mantener todas las aserciones del flujo principal en el mismo test: separar la carga inicial y el tap en dos tests del mismo archivo hace que el `pumpAndSettle()` del segundo cuelgue, por la interacción entre `rootBundle` y el reloj simulado al reutilizarse entre tests. Los tests que **no** montan widgets (`content_test.dart`, `language_course_test.dart`) sí pueden tener varios `test()` — `content_test.dart` lee los JSON con `dart:io` en vez de `rootBundle` justamente para no tocar canales de plataforma ni el reloj simulado, y así puede validar también `content/packs/`, que no viaja como asset.
- **`dependency_overrides: path_provider_foundation: 2.4.1`.** Sin esto, `flutter test`/`flutter build` fallan en esta máquina: el Flutter SDK vive en una ruta con espacio (`C:\SDK Flutter\flutter`), lo que rompe la compilación de "native assets" de `objective_c` (dependencia transitiva de versiones más nuevas de ese paquete).
- **`analysis_options.yaml`** excluye `build/**`, `android/**`, `ios/**`, `web/**`.
- **El isolate headless del widget no es nuevo en cada toque.** `HomeWidgetBackgroundService.kt` (dentro del paquete `home_widget`, no de este repo) guarda el `FlutterEngine` del callback en un `companion object` y lo reutiliza mientras el proceso siga vivo — solo se crea una vez, la primera vez que se toca un botón del widget. Como `SharedPreferences.getInstance()` (API legacy del paquete `shared_preferences`) cachea todas las claves en memoria la primera vez que se llama **por isolate**, ese isolate reutilizado nunca ve cambios que la app en primer plano escriba después (p. ej. cambiar el preset de tema en Configuración mientras el widget ya estaba "caliente"). Por eso `VocabularyStateService._freshPrefs()` siempre llama `reload()` antes de leer cualquier clave — quitarlo revive el bug (el widget se queda pegado al snapshot de la primera interacción).
- **En `VocabularyStateService`, leer preferencias siempre *después* de `_freshPrefs()`.** Corolario de la trampa anterior: `reload()` refresca el mapa cacheado completo de ese isolate, así que `getLanguageCourse()`, `getCardDensity()`, `getSelectedThemePresetId()` y `getDarkModeEnabled()` ven valores frescos solo si se llaman después. Invertir el orden (p. ej. resolver el curso antes de pedir las prefs) hace que el widget se quede mostrando palabras del curso anterior.
- **Agregar un plugin nativo nuevo (ej. `sensors_plus`) requiere reinstalar la app, no solo hot reload/restart.** El canal de plataforma del plugin se registra al arrancar el proceso nativo; si se sigue probando sobre una sesión de `flutter run` que ya estaba corriendo desde antes de agregar la dependencia, el sensor simplemente no responde y parece "no funcionar" cuando en realidad nunca se registró. Hay que parar la sesión y correr `flutter run` desde cero (o desinstalar y reinstalar el APK).
- **Colores hacia el widget nativo van como string `#AARRGGBB`, nunca como `int`.** `Color.toARGB32()` da valores que superan el rango de un `Int32` con signo (canal alfa `0xFF`), así que el codec estándar de Flutter los serializa como `Long` del lado de Kotlin en vez de `Int`; `HomeWidgetPlugin` los guarda con el tipo que reciba, y leerlos siempre con `getInt()` revienta con `ClassCastException` **dentro de `onUpdate()`, que corre en el proceso de la app** (no del launcher) — así que no solo falla el widget, tumba la app entera. Ver `_colorToHex()` en `vocabulary_state_service.dart` y `parseWidgetColor()` en `VocabularyAppWidgetProvider.kt`.

## Roadmap

Estado de etapas y backlog de features futuras: ver `docs/roadmap.md`.
