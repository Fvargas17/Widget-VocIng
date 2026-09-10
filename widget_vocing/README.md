# Widget VocIng

App Flutter para aprender vocabulario y frases en inglés de forma pasiva: muestra tarjetas
breves (palabra, pronunciación en fonética intuitiva, descripción, traducción, ejemplo de uso)
que se pueden consultar rápidamente. Sin backend, sin suscripción, sin cuentas — todo el
contenido se almacena localmente.

## Cómo funciona

- Al abrir la app se elige una palabra aleatoria del vocabulario disponible.
- El botón flotante "Otra palabra" muestra otra palabra al azar, sin repetir la actual.
- El vocabulario base viaja embebido en la app (`assets/data/vocabulary.json`), así que
  funciona sin conexión desde el primer arranque.
- Si hay conexión, la app revisa en segundo plano si hay **packs de vocabulario nuevos**
  publicados (paquetes de palabras adicionales) y pregunta si se quieren descargar. Ver
  `CLAUDE.md` → "Packs de vocabulario descargables" para el detalle técnico de cómo se
  publican y consumen.

## Comandos habituales

```bash
flutter pub get              # instalar dependencias
flutter run                  # ejecutar la app (elige dispositivo/emulador disponible)
flutter analyze              # lint/análisis estático
flutter test                 # correr toda la suite de tests
flutter build apk            # build Android
flutter build ios            # build iOS (requiere macOS)
```

## Roadmap

1. ~~Separar datos de la UI~~ (completo)
2. ~~Hacer la app útil~~ (completo): palabra aleatoria, botón "Otra palabra", pronunciación en texto
3. ~~Packs de vocabulario descargables~~ (completo): crecer el contenido sin republicar la app
4. Widget nativo de Android (pendiente)
5. Lock Screen en iPhone (pendiente)

Para más detalle de arquitectura, ver [`CLAUDE.md`](./CLAUDE.md).
