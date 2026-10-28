"""Synthesises the game's short sound effects into assets/sfx/*.wav."""
import math, struct, wave, os, random

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")

def tone(freqs, dur, vol=0.5, attack=0.004, decay=6.0, shape="sine", glide=0.0):
    n = int(RATE * dur)
    out = []
    phase = [0.0] * len(freqs)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = 0.0
        for k, f in enumerate(freqs):
            f = f * (1 + glide * t)
            phase[k] += 2 * math.pi * f / RATE
            if shape == "sine":
                s += math.sin(phase[k])
            else:  # soft triangle
                s += 2 / math.pi * math.asin(math.sin(phase[k]))
        out.append(vol * env * s / len(freqs))
    return out

def seq(parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(RATE * gap)
    return out

def write(name, samples):
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))

write("pick", tone([880, 1320], 0.08, vol=0.35, decay=40))
write("place", tone([520, 780], 0.16, vol=0.55, decay=22, shape="tri", glide=-0.6))
write("fail", tone([220, 233], 0.18, vol=0.4, decay=18, shape="tri", glide=-0.8))
write("button", tone([1046], 0.06, vol=0.3, decay=50))
write("hint", seq([tone([659], 0.09, 0.4, decay=20), tone([988], 0.18, 0.4, decay=14)]))
notes = [523, 659, 784, 1046]
win = seq([tone([f, f * 2], 0.14, 0.4, decay=10, shape="tri") for f in notes]) + tone([1046, 1318, 1568], 0.6, 0.45, decay=4)
write("win", win)
write("star", seq([tone([1175, 1760], 0.07, 0.35, decay=25), tone([1568, 2349], 0.25, 0.35, decay=12)]))
write("coin", seq([tone([1318], 0.06, 0.35, decay=30, shape="tri"), tone([1976], 0.22, 0.35, decay=14, shape="tri")]))
write("undo", tone([660, 990], 0.1, vol=0.3, decay=30, glide=-0.5))
print("ok")
