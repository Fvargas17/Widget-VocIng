# Roadmap futuro — Mascota de compañía

> Este documento es de **contexto, no de ejecución**. No implica que estas mejoras se vayan a construir pronto ni en este orden; existe para que una futura sesión (humana o de IA) entienda rápido en qué estado quedó la feature de la mascota y qué ideas ya se consideraron, sin tener que re-derivarlas desde cero. Última actualización: ver commit que introduce este archivo.

## Estado actual (para ubicarse)

La mascota (`Pet.reno` / `pollito` / `gato`) vive en `lib/widgets/pet_companion.dart`, dentro de una caja con solo bordes debajo de la tarjeta de `HomeScreen`. Hoy:

- Se dibuja como un emoji (`lib/pets/pet_catalog.dart`), no como arte propio.
- Camina de lado a lado con un `AnimationController.repeat(reverse: true)`.
- Se inclina con el acelerómetro real (`sensors_plus`), con la gravedad pesando más que el paseo: cuando la inclinación es fuerte, el paseo se atenúa (`paceInfluence` en `pet_companion.dart`) para que no "escale" contra la inclinación.
- Celebra (salto de escala) cada vez que se marca una palabra como aprendida, vía el contador `_learnedPulse` de `HomeScreen`.
- Se elige en `SettingsScreen` y se persiste con `pet_service.dart` (mismo patrón que `card_density_service.dart`).
- Solo existe en `HomeScreen`; `FavoritesScreen` no la incluye (decisión explícita, no un olvido).

Las constantes de física relevantes hoy (todas en `_PetCompanionState` de `pet_companion.dart`, por si hay que re-calibrar):
- `_paceDuration`: 2955ms por ciclo completo de ida y vuelta.
- Divisor `event.x / 4.0` para normalizar el acelerómetro (más sensible que usar la gravedad completa, ~9.8).
- Suavizado (`low-pass`) con factor `0.2` por lectura.
- Combinación: `dx = paceOffset * 0.75 * paceInfluence + tiltBias`, con `paceInfluence = 1 - |tiltBias|`.

## Ideas para más adelante

### Arte y animación
- Reemplazar el emoji por sprites de pixel art con ciclos de animación (caminar, celebrar, "comer"), uno por mascota. El punto de reemplazo ya está aislado a propósito: `PetVisual` en `pet_catalog.dart` (hoy solo `emoji`) y el `Text` dentro de `PetCompanion.build()`. Lo natural sería que `PetVisual` pase a describir un sprite sheet (frames + fps) y que `PetCompanion` use un `AnimatedBuilder`/`CustomPainter` que dibuje el frame correspondiente al ciclo de paseo en vez de un solo emoji estático.
- La animación de "comer" hoy es un salto de escala genérico, no literal. Si hay sprites, tendría más sentido un frame/animación específica de "comiendo" en vez de reusar el mismo salto para celebrar.

### Física y sensación de movimiento
- Hoy la posición es puramente declarativa (se calcula cada frame a partir del paseo + la inclinación, sin velocidad/aceleración real). Una versión más creíble simularía velocidad e inercia (la mascota acelera al empezar a "caer" hacia un lado y frena al chocar contra el borde), en vez de saltar directo a la posición calculada.
- Rebote/choque contra los bordes de la caja podría tener una reacción visual (un pequeño "achatamiento" al llegar a la esquina), reforzando la idea de gravedad real.
- Los valores de sensibilidad (`/4.0`, pesos `0.75`/`paceInfluence`) se ajustaron a ojo en un dispositivo. Vale la pena revisarlos en más de un teléfono antes de darlos por definitivos.

### Interacción
- Toque/arrastre sobre la mascota (hoy no reacciona a nada, es solo decorativa).
- Un ajuste de accesibilidad tipo "reducir movimiento" que use `debugDisablePetMotion` (hoy es solo para tests) también en producción para quien prefiera una mascota estática.

### Alcance dentro de la app
- Evaluar si tiene sentido que la mascota también aparezca en `FavoritesScreen` (hoy deliberadamente no está ahí).
- El widget nativo de Android (`VocabularyAppWidgetProvider.kt`) no incluye la mascota. Llevarla ahí es un salto grande: `RemoteViews` no soporta animaciones custom ni acelerómetro; como mucho podría mostrarse una pose estática.

### Explícitamente fuera de alcance (por ahora)
- Cualquier forma de gamificación (rachas, XP, medallas) — ya descartada en el backlog general del proyecto (ver `CLAUDE.md`, sección de roadmap). La mascota es una metáfora de "alimentar tu vocabulario", no un sistema de puntos.
- Múltiples mascotas simultáneas o mascotas de otros usuarios interactuando entre sí (la referencia de inspiración fueron herramientas de streaming tipo Stream Avatars/Triiibe/Kappamon, pero aquí es una sola mascota por persona, sin chat ni multiusuario).

## Testing pendiente

Hoy solo existe `test/widget_test.dart`, que desactiva el movimiento de la mascota (`pet_companion.debugDisablePetMotion = true`) para no colgar `pumpAndSettle()`, pero no prueba nada específico de `PetCompanion` (ni el layout, ni que `celebrationSignal` dispare la animación). Si la feature crece, valdría la pena un test dedicado a `PetCompanion` en aislamiento.
