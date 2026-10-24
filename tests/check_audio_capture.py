#!/usr/bin/env python3
"""Inspect actual Godot-recorded PCM and its imported 32-bit source conversions."""
from pathlib import Path
import argparse
import math
import struct
import wave


def samples(path):
    with wave.open(str(path)) as reader:
        width, channels, rate = reader.getsampwidth(), reader.getnchannels(), reader.getframerate()
        data = reader.readframes(reader.getnframes())
    values = struct.unpack(f"<{len(data)//width}{'h' if width == 2 else 'i'}",data)
    scale = 2 ** (width*8-1)
    return [value/scale for value in values[::channels]], rate


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", type=Path, default=Path("/tmp/argentum-audio-capture"))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    for name in ["17","18"]:
        with wave.open(str(repo/"assets/argentum/source/audio"/(name+".wav"))) as source:
            data = source.readframes(source.getnframes())
        original = struct.unpack(f"<{len(data)//4}i",data)
        data = (args.capture/("import-"+name+".pcm")).read_bytes()
        imported = struct.unpack(f"<{len(data)//2}h",data)
        assert len(original)==len(imported)
        error = max(abs(actual-(expected>>16)) for actual,expected in zip(imported,original))
        assert error<=1, (name,error)
        print(f"PCM32 source {name}: {len(imported)} frames, max import error {error} LSB")
    original, rate = samples(repo/"assets/argentum/source/audio/17.wav")
    recorded, capture_rate = samples(args.capture/"source17-playback.wav")
    expected = []
    for index in range(int(len(original)*capture_rate/rate)):
        fraction = index*rate/capture_rate
        low = int(fraction)
        value = original[low]*(1-(fraction-low))+original[min(low+1,len(original)-1)]*(fraction-low)
        expected.append(value*10**(-3/20))
    # Find device-buffer delay. Correlation checks content, not just non-silence.
    span = min(len(expected),len(recorded))-1536
    best = (-2.0,0)
    for delay in range(1536):
        dot = aa = bb = 0.0
        for index in range(0,span,37):
            a,b = recorded[delay+index],expected[index]
            dot += a*b; aa += a*a; bb += b*b
        correlation = dot/math.sqrt(max(1e-30,aa*bb))
        if correlation>best[0]: best = (correlation,delay)
    assert best[0]>.995,best
    assert abs(max(abs(x) for x in recorded)-max(abs(x) for x in expected))<0.003
    print(f"Source17 live playback correlation {best[0]:.6f}, delay {best[1]} frames")
    mixed,_ = samples(args.capture/"stress-mix.wav")
    peak = max(abs(x) for x in mixed)
    rms = math.sqrt(sum(x*x for x in mixed)/len(mixed))
    assert peak<10**(-1/20)+0.001 and rms>0.01
    assert not any(abs(x)>.999 for x in mixed)
    print(f"60-voice stress recording: peak {20*math.log10(peak):.2f} dBFS, RMS {20*math.log10(rms):.2f} dBFS, no clipped samples")


if __name__=="__main__": main()
