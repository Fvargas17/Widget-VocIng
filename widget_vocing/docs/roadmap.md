# Roadmap

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
| 3.10 — Mascota de compañía (paseo + gravedad real vía acelerómetro, elegible en `SettingsScreen`) | completa |
| 4 — Cursos de idioma (toggle ES→EN / EN→FR: vocabulario + UI localizada) | completa |
| 5.5 — Lock Screen en iPhone | no iniciada |

**Posibles features a futuro** (sin etapa asignada, no implementar hasta que el proyecto las retome). Backlog visual completo (2026-09-24), agrupado por categoría. Para ideas específicas de la mascota (sprites, física más realista, etc.), ver `docs/pet_companion_roadmap.md`:

*Personalización del widget y la app:*
- Selector de tipografía (2-3 fuentes, ej. una editorial para las palabras y una neutra para el resto).
- Tercer curso de idioma (ej. Español → Francés): la arquitectura ya lo soporta con una entrada en `LanguageCourse` + su contenido JSON.
- Recordar la palabra actual por curso: hoy cambiar de idioma reinicia la palabra y el historial (una sola clave `vocab_state_current_id`, sin sufijo por curso).
- Desacoplar el idioma de la UI del curso, si alguna vez se quiere estudiar francés con la interfaz en español (hoy la UI sale de `LanguageCourse.uiLocale`).

*(Implementados en la etapa 3.7: tamaños de widget/tarjeta configurables y fondos/skins temáticos para `VocabularyCard` — ver `card_density_service.dart`/`card_density_notifier.dart` y `AppThemePreset.cardGradient`. Implementado en la etapa 3.9: sincronización de colores del widget nativo — ver `resolveActiveThemeRoles()` y `VocabularyAppWidgetProvider.tintBackground()`. Implementado en la etapa 4: el toggle de idioma — ver `LanguageCourse` y `lib/l10n/`.)*

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
