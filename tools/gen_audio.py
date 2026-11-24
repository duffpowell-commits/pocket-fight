"""Placeholder sounds, synthesized (original, no licences to track). Replace any file in
assets/audio/ with a real one of the same name and nothing else changes.
Run: python3 tools/gen_audio.py"""
import math, struct, wave, random

RATE = 22050
random.seed(7)


def write(name, samples):
    with wave.open(f"assets/audio/{name}.wav", "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def tone(freqs, dur, vol=0.5, decay=8.0):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        f = freqs[min(len(freqs) - 1, int(t / dur * len(freqs)))]
        out.append(vol * math.sin(2 * math.pi * f * t) * math.exp(-decay * t / dur))
    return out


write("click", tone([900], 0.05, 0.35, 5))
write("good", tone([660, 990], 0.14, 0.45, 4))
write("bad", tone([220, 150], 0.25, 0.5, 3))
write("level", tone([523, 659, 784, 1046], 0.5, 0.45, 2))
write("gameover", tone([392, 330, 262, 196], 0.9, 0.5, 2))

# 8-second music loop: soft pad chords
chords = [[220, 277, 330], [196, 247, 294], [175, 220, 262], [196, 247, 294]]
music = []
for c in chords:
    n = int(RATE * 2)
    for i in range(n):
        t = i / RATE
        env = min(1, t * 4) * min(1, (2 - t) * 4)
        music.append(0.12 * env * sum(math.sin(2 * math.pi * f * t) for f in c))
write("music_loop", music)


def noise(dur, vol, decay, lowpass):
    """Filtered noise burst: lowpass 0..1 (higher = duller)."""
    out, prev = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        prev = prev * lowpass + random.uniform(-1, 1) * (1 - lowpass)
        out.append(vol * prev * math.exp(-decay * t / dur) * 3)
    return out


def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]


# Footsteps per surface (game feel standard: each surface sounds different).
write("step_stone", mix(noise(0.09, 0.45, 9, 0.35), tone([140], 0.06, 0.25, 9)))
write("step_wood", mix(tone([210, 180], 0.11, 0.45, 7), noise(0.06, 0.2, 9, 0.6)))
write("step_grass", noise(0.16, 0.35, 5, 0.15))
write("step_water", mix(noise(0.22, 0.4, 4, 0.55), tone([500, 700, 400], 0.18, 0.12, 5)))
# Hits: a light smack and a heavy thud.
write("hit", mix(noise(0.08, 0.6, 8, 0.25), tone([180, 120], 0.1, 0.4, 6)))
write("hit_heavy", mix(noise(0.18, 0.7, 6, 0.5), tone([110, 70], 0.3, 0.6, 4)))
write("whoosh", noise(0.2, 0.3, 3, 0.8))

# Combat layer: same 8 s and chords as music_loop plus a pulse, so the two crossfade in sync.
combat = []
for c in chords:
    n = int(RATE * 2)
    for i in range(n):
        t = i / RATE
        env = min(1, t * 4) * min(1, (2 - t) * 4)
        beat = math.exp(-18 * ((t * 4) % 1))
        combat.append(0.1 * env * sum(math.sin(2 * math.pi * f * t) for f in c)
                      + 0.35 * beat * math.sin(2 * math.pi * 55 * t)
                      + 0.06 * beat * random.uniform(-1, 1))
write("music_combat", combat)
print("ok")
