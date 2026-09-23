"""Genera los efectos de sonido de la app en `assets/sounds/`.

Los tres WAV (mono, 44.1 kHz, 16 bits) se sintetizan aquí en vez de traerse de
un banco de sonidos externo: así quedan versionados en el repo, sin licencias
de terceros que rastrear, y se pueden reajustar cambiando los parámetros de
abajo y volviendo a correr el script.

    python tool/generate_sounds.py

Salida:
    assets/sounds/nav.wav        -> botones adelante / atrás
    assets/sounds/learned.wav    -> marcar palabra como aprendida
    assets/sounds/favorite.wav   -> marcar / desmarcar favorito (estrella)
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"

# Rampa de entrada/salida aplicada a todo tono: sin ella, el corte abrupto de
# la onda produce un "click" audible al inicio y al final.
FADE_SECONDS = 0.005


def tone(frequency, duration, amplitude=1.0, decay=6.0, start=0.0, partials=(1.0,)):
    """Un tono con decaimiento exponencial, como una lista de (índice, muestra).

    `partials` son multiplicadores de la frecuencia base (armónicos): más
    parciales altos = timbre más brillante.
    """
    samples = []
    start_index = int(start * SAMPLE_RATE)
    total = int(duration * SAMPLE_RATE)
    fade = max(1, int(FADE_SECONDS * SAMPLE_RATE))

    for i in range(total):
        t = i / SAMPLE_RATE
        envelope = amplitude * math.exp(-decay * t)
        envelope *= min(1.0, i / fade, (total - i) / fade)

        value = 0.0
        for n, partial in enumerate(partials):
            # Cada parcial sucesivo entra más bajo, para que no sature.
            value += math.sin(2 * math.pi * frequency * partial * t) / (n + 1)
        samples.append((start_index + i, value * envelope))

    return samples


def mix(*layers):
    """Suma varias capas de tonos en un solo buffer y normaliza a 16 bits."""
    length = max(index for layer in layers for index, _ in layer) + 1
    buffer = [0.0] * length

    for layer in layers:
        for index, value in layer:
            buffer[index] += value

    peak = max(abs(value) for value in buffer) or 1.0
    # 0.85 deja algo de headroom para que no suene comprimido en el altavoz.
    scale = 0.85 * 32767 / peak
    return b"".join(struct.pack("<h", int(value * scale)) for value in buffer)


def write_wav(name, frames):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUTPUT_DIR / name
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)
    print(f"{path.relative_to(OUTPUT_DIR.parent.parent)}  ({len(frames) // 2} muestras)")


def build_nav():
    """Blip corto y neutro: se dispara muy seguido, así que debe ser discreto."""
    return mix(tone(660, 0.09, amplitude=0.9, decay=28, partials=(1.0, 2.0)))


def build_learned():
    """Arpegio ascendente C5-E5-G5: cierre de 'logro'."""
    return mix(
        tone(523.25, 0.30, amplitude=0.8, decay=9, start=0.00, partials=(1.0, 2.0)),
        tone(659.25, 0.30, amplitude=0.8, decay=9, start=0.09, partials=(1.0, 2.0)),
        tone(783.99, 0.36, amplitude=0.9, decay=7, start=0.18, partials=(1.0, 2.0, 3.0)),
    )


def build_favorite():
    """Shimmer agudo tipo campanita, para la estrella de favoritos."""
    return mix(
        tone(1568.0, 0.34, amplitude=0.7, decay=11, start=0.00, partials=(1.0, 2.0)),
        tone(2093.0, 0.32, amplitude=0.6, decay=13, start=0.05, partials=(1.0, 2.0)),
        tone(2637.0, 0.30, amplitude=0.5, decay=15, start=0.10, partials=(1.0, 2.0, 3.0)),
    )


if __name__ == "__main__":
    write_wav("nav.wav", build_nav())
    write_wav("learned.wav", build_learned())
    write_wav("favorite.wav", build_favorite())
