"""Generate the original short melee-contact sound, using the standard library."""
import math
import pathlib
import random
import struct
import wave


def generate(destination):
    rate = 44100
    rng = random.Random(4082)
    low = previous = 0.0
    values = []
    for sample in range(int(rate * 0.27)):
        t = sample / rate
        noise = rng.uniform(-1, 1)
        low += 0.065 * (noise - low)
        envelope = (1-math.exp(-t*1800))*math.exp(-t*24)
        body = math.sin(2*math.pi*(135*t-95*t*t))*0.23 + math.sin(2*math.pi*282*t)*0.10 + low*1.8
        scrape = (noise-previous)*math.exp(-t*75)*0.035
        previous = noise
        value = (body+scrape)*envelope*min(1,(0.27-t)/0.025)
        values.append(max(-32767,min(32767,round(value*26000))))
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination),'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'))
        output.writeframes(struct.pack('<%dh'%len(values),*values))


if __name__ == '__main__':
    generate(pathlib.Path(__file__).resolve().parents[1]/'assets/argentum/custom/audio/melee_hit.wav')
