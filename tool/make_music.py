"""Synthesises a calm, seamlessly looping background track (assets/music/calm.wav)."""
import math, os, random, struct, wave

RATE = 22050
BPM = 84
BEAT = 60 / BPM
BARS = 8
LEN = int(RATE * BEAT * 4 * BARS)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
os.makedirs(OUT, exist_ok=True)

def midi(n):
    return 440 * 2 ** ((n - 69) / 12)

buf = [0.0] * LEN

def add_note(start, dur, freq, vol, attack, release, partials=((1, 1.0),)):
    s0 = int(start * RATE)
    n = int((dur + release) * RATE)
    for i in range(n):
        t = i / RATE
        if t < attack:
            env = t / attack
        elif t < dur:
            env = 1.0
        else:
            env = max(0.0, 1 - (t - dur) / release)
        v = sum(a * math.sin(2 * math.pi * freq * k * t) for k, a in partials)
        buf[(s0 + i) % LEN] += vol * env * v  # wrap -> seamless loop

# Chords (Cmaj7 - Am7 - Fmaj7 - G6), two bars each.
chords = [[48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 59]]
pad = ((1, 1.0), (2, 0.25), (3, 0.08))
for ci, ch in enumerate(chords):
    start = ci * 2 * 4 * BEAT
    for note in ch:
        add_note(start, 2 * 4 * BEAT - 0.4, midi(note), 0.05, 1.2, 1.6, pad)

# Soft pentatonic plucks.
rng = random.Random(7)
scale = [72, 74, 76, 79, 81, 84]
pluck = ((1, 1.0), (2, 0.35), (4, 0.1))
t = 0.0
while t < BARS * 4 * BEAT - 0.01:
    if rng.random() < 0.62:
        add_note(t, 0.05, midi(rng.choice(scale)), 0.06, 0.005, 0.9, pluck)
    t += BEAT / 2

peak = max(abs(x) for x in buf)
with wave.open(os.path.join(OUT, "calm.wav"), "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.8 * 32000)) for x in buf))
print("ok", LEN / RATE, "s")
