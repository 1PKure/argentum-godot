#!/usr/bin/env python3
"""Generate original deterministic, peak-bounded material footfalls (Python stdlib)."""
from pathlib import Path
import hashlib
import json
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/argentum/custom/audio"
RATE = 32000
SECONDS = 0.110
MATERIALS = {
    "forest": (0.20, 0.46, 0.08, 86.0),
    "desert": (0.16, 0.25, 0.18, 74.0),
    "lava": (0.12, 0.27, 0.12, 124.0),
    "duel_room": (0.07, 0.16, 0.11, 156.0),
}


def generate(material, variant):
    softness, body, grit, frequency = MATERIALS[material]
    rng = random.Random(f"arena-footstep:{material}:{variant}:v1")
    low = 0.0
    samples = []
    for index in range(round(RATE * SECONDS)):
        t = index / RATE
        white = rng.uniform(-1.0, 1.0)
        low += softness * (white - low)
        high = white - low
        onset = min(1.0, t / 0.003)
        release = min(1.0, (SECONDS - t) / 0.018)
        thump = math.sin(2 * math.pi * (frequency + variant * 4) * t) * math.exp(-t * 72)
        grain = (body * low + grit * high) * math.exp(-t * 45)
        if material == "desert":
            grain += high * 0.08 * math.exp(-((t - 0.026) / 0.023) ** 2)
        if material == "duel_room":
            grain += math.sin(2 * math.pi * 890 * t) * math.exp(-t * 140) * 0.035
        samples.append((thump * 0.28 + grain) * onset * release)
    peak = max(abs(value) for value in samples)
    samples = [value * (0.50 / peak) for value in samples]
    path = OUT / f"footstep_{material}_{variant + 1}.wav"
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(RATE)
        writer.writeframes(b"".join(struct.pack("<h", round(value * 32767)) for value in samples))
    return path


def main():
    sources = OUT / "sources.json"
    metadata = json.loads(sources.read_text())
    for material in MATERIALS:
        for variant in range(2):
            path = generate(material, variant)
            metadata[path.name] = {
                "source": "Original procedural footfall; no external recording or paid asset.",
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "format": "PCM mono 16-bit 32000 Hz, 110 ms; peak 0.50 (-6 dBFS)",
                "material": material,
                "reproduce": "python tools/prepare_footstep_audio.py",
                "use": "One spatial footfall per completed living-avatar tile; never idle or turn-only."
            }
    sources.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
