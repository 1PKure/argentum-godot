"""Restore Mati's exact supplied melee WAV, without processing its audio or header."""
import hashlib
import json
import pathlib
import wave


def prepare():
    root = pathlib.Path(__file__).resolve().parents[1]
    audio = root / 'assets/argentum/custom/audio'
    source = audio / 'originals/melee_firefly.wav.source'
    with wave.open(str(source), 'rb') as stream:
        channels, width, rate, frames, *_ = stream.getparams()
        if (channels, width, rate) != (2, 2, 48000):
            raise ValueError('Expected the supplied stereo PCM16 48 kHz take.')
    original = source.read_bytes()
    destination = audio / 'melee_hit.wav'
    destination.write_bytes(original)
    manifest = audio / 'sources.json'
    data = json.loads(manifest.read_text())
    data['melee_hit.wav'] = {
        'source': 'User attachment: Firefly_audio_Short_medieval_melee_hit_on_a_character,_strong_co_variation4.wav',
        'source_path': 'originals/melee_firefly.wav.source',
        'source_sha256': hashlib.sha256(original).hexdigest(),
        'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        'format': f'PCM stereo 16-bit 48000 Hz, {round(frames/rate*1000)} ms',
        'processing': 'None. Exact original file bytes, including full timing, level, tail and metadata.',
        'reproduce': 'python tools/prepare_melee_audio.py',
        'use': 'Only confirmed melee impact; original source at unity gain.'
    }
    manifest.write_text(json.dumps(data,indent=2)+'\n')


if __name__ == '__main__':
    prepare()
