"""Prepare Mati's supplied Firefly melee take for repeated combat impacts."""
import array
import hashlib
import json
import math
import pathlib
import sys
import wave


def prepare():
    root = pathlib.Path(__file__).resolve().parents[1]
    audio = root / 'assets/argentum/custom/audio'
    source = audio / 'originals/melee_firefly.wav.source'
    with wave.open(str(source), 'rb') as stream:
        channels, width, rate, frames, *_ = stream.getparams()
        if (channels, width, rate) != (2, 2, 48000):
            raise ValueError('Expected the supplied stereo PCM16 48 kHz take.')
        samples = array.array('h', stream.readframes(frames))
    if sys.byteorder != 'little': samples.byteswap()
    # Remove 37 ms of leading quiet and the low-level tail after 550 ms.
    # Preserve the impact's original timing/timbre; add no synthesized transient.
    start = round(rate * 0.037)
    end = round(rate * 0.550)
    values = array.array('h')
    gain = 10 ** (-3.0 / 20)
    for frame in range(start, end):
        t = (frame - start) / rate
        remaining = (end - frame) / rate
        fade = min(1.0, t / 0.003, remaining / 0.040)
        for channel in range(channels):
            values.append(round(samples[frame * channels + channel] * gain * fade))
    if sys.byteorder != 'little': values.byteswap()
    destination = audio / 'melee_hit.wav'
    with wave.open(str(destination), 'wb') as output:
        output.setparams((channels,width,rate,0,'NONE','not compressed'))
        output.writeframes(values.tobytes())
    manifest = audio / 'sources.json'
    data = json.loads(manifest.read_text())
    data['melee_hit.wav'] = {
        'source': 'User attachment: Firefly_audio_Short_medieval_melee_hit_on_a_character,_strong_co_variation4.wav',
        'source_path': 'originals/melee_firefly.wav.source',
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        'format': 'PCM stereo 16-bit 48000 Hz, 513 ms',
        'processing': 'Trim 37 ms leading quiet and tail after 550 ms; gain -3 dB; 3 ms attack/40 ms release fades.',
        'reproduce': 'python tools/prepare_melee_audio.py',
        'use': 'Only confirmed melee impact; preserves the supplied medieval contact sound.'
    }
    manifest.write_text(json.dumps(data,indent=2)+'\n')


if __name__ == '__main__':
    prepare()
