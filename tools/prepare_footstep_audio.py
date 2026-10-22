#!/usr/bin/env python3
"""Rebuild material footfalls from vendored Kenney CC0 foley using only stdlib.

The .ogg.source files are the original distribution. Matching .wav.source files
are their mono 48 kHz PCM decode (FFmpeg), retained so rebuilding needs no codec.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/argentum/custom/audio"
SOURCE = OUT / "originals/kenney_impact"
RATE = 48000
MATERIALS = {
    "forest": ("grass", 0, 7000.0),
    "desert": ("snow", 0, 2600.0),
    "lava": ("concrete", 0, 1800.0),
    "duel_room": ("concrete", 1, 9000.0),
}


def generate(material, variant):
    foley, offset, cutoff = MATERIALS[material]
    name = f"footstep_{foley}_{variant + offset:03d}"
    source = SOURCE / (name + ".wav.source")
    with wave.open(str(source), "rb") as reader:
        assert reader.getnchannels() == 1 and reader.getsampwidth() == 2
        assert reader.getframerate() == RATE
        raw = reader.readframes(reader.getnframes())
    samples = [value / 32768 for value in struct.unpack(f"<{len(raw)//2}h", raw)]
    pitch = {"forest":1.0,"desert":0.94,"lava":0.78,"duel_room":1.10}[material]
    if pitch != 1.0:
        original = samples
        samples = []
        for index in range(int((len(original)-1)/pitch)):
            position = index*pitch
            lo = int(position)
            samples.append(original[lo]*(1-(position-lo))+original[lo+1]*(position-lo))
    # Keep heel/contact/sole detail; remove only quiet padding below -50 dB.
    active = [index for index, value in enumerate(samples) if abs(value) > 0.0032]
    start = max(0, active[0] - round(RATE * 0.008))
    end = min(len(samples), active[-1] + round(RATE * 0.045))
    samples = samples[start:end]
    # Gentle low-pass removes brittle gravel/codec hiss, without a synthetic tone.
    alpha = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    low = 0.0
    filtered = []
    for sample in samples:
        low += alpha * (sample - low)
        filtered.append(low)
    # Match these quiet foley recordings without clipping; cap lift at 30 dB for the very quiet CC0 recordings.
    peak = max(abs(value) for value in filtered)
    rms = math.sqrt(sum(value * value for value in filtered) / len(filtered))
    gain = min(32.0, 0.30/peak, 0.065/rms)
    for index in range(len(filtered)):
        fade = min(1.0, index/(RATE*.006), (len(filtered)-1-index)/(RATE*.030))
        filtered[index] *= max(0.0, fade) * gain
    if material == "duel_room":
        dry = filtered[:]
        delay = round(RATE*0.045)
        filtered.extend([0.0]*(delay*2))
        for offset, amount in [(delay,0.14),(delay*2,0.06)]:
            for index,value in enumerate(dry): filtered[index+offset] += value*amount
        level = max(abs(v) for v in filtered)
        if level>0.30: filtered=[v*0.30/level for v in filtered]
    path = OUT / f"footstep_{material}_{variant + 1}.wav"
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(RATE)
        writer.writeframes(b"".join(struct.pack("<h", round(value * 32767)) for value in filtered))
    return path, name, len(filtered)/RATE


def main():
    sources = OUT / "sources.json"
    metadata = json.loads(sources.read_text())
    for material in MATERIALS:
        for variant in range(4):
            path, original, seconds = generate(material, variant)
            raw = SOURCE / (original + ".ogg.source")
            metadata[path.name] = {
                "source": f"Kenney Impact Sounds 1.0 / {original}.ogg",
                "url": "https://kenney.nl/assets/impact-sounds",
                "license": "CC0 1.0; originals/kenney_impact/License.txt",
                "original_path": str(raw.relative_to(OUT)),
                "original_sha256": hashlib.sha256(raw.read_bytes()).hexdigest(),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "format": f"PCM mono 16-bit 48000 Hz, {round(seconds*1000)} ms",
                "processing": "Material low-pass and resampling (grass natural, sand soft, lava lower, stone brighter with short 45/90ms reflections); level matching peak <=0.30 and lift <=30dB; 6/30ms fades. No synthesized tone.",
                "material": material,
                "reproduce": "python tools/prepare_footstep_audio.py",
                "use": "Spatial contacts, four non-repeating variants, minimum 225 ms between contacts; silent while idle, turning, ghost or paused."
            }
    sources.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
