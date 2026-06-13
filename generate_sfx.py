#!/usr/bin/env python3
"""Generate 12 placeholder SFX WAV files for Memory Dungeon.

Uses pure Python — no numpy or scipy required.  Produces short, recognizable
sounds that are good enough for prototyping and can be swapped later.

Output directory: assets/audio/sfx/
"""

import math
import os
import struct
import wave

# ── helpers ────────────────────────────────────────────────────────────────

RATE = 44100       # sample rate
DURATION_SEC = {
    "flip":      0.06,   # ↑ click
    "match":     0.18,   # ↑ pleasant 2-note chime
    "mismatch":  0.12,   # ↓ dead thump
    "poison":    0.25,   # ↑ hissing siren (descending)
    "heal":      0.28,   # ↑ warm ascending bell / arpeggio
    "gem":       0.15,   # ↑ high shimmer bell
    "scroll":    0.22,   # ↑ paper rustle + spark
    "treasure":  0.16,   # ↑ metallic jingle cluster
    "shuffle":   0.14,   # ↑ whoosh sweep
    "victory":   0.35,   # ↑ short fanfare (4 notes)
    "gameover":  0.35,   # ↓ dramatic drop + rumble
    "whoosh":    0.12,   # ↑ UI transition whoosh
}

def _fade(t: float, duration_sec: float) -> float:
    """Simple fade-in/fade-out to avoid clicks."""
    fade_ms = 8.0
    if t < fade_ms / 1000:
        return t / (fade_ms / 1000)
    if t > duration_sec - fade_ms / 1000:
        return (duration_sec - t) / (fade_ms / 1000)
    return 1.0


def _envelope(duration_sec: float):
    """Return a list of envelope values."""
    fade_ms = 8.0 / 1000
    steps = int(RATE * duration_sec)
    env = []
    for i in range(steps):
        t = i / RATE
        if t < fade_ms:
            env.append(t / fade_ms)
        elif t > duration_sec - fade_ms:
            env.append((duration_sec - t) / fade_ms)
        else:
            env.append(1.0)
    return env


def _write_wav(filepath: str, samples: list, rate: int = RATE):
    """Write a 16-bit mono WAV file."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)          # 16-bit
        wf.setframerate(rate)
        packed = struct.pack(
            f"{len(samples)}h",
            *[int(max(-32767, min(v * 32767, 32767))) for v in samples]
        )
        wf.writeframes(packed)


# ── SFX generators ────────────────────────────────────────────────────────

def gen_flip():
    """Quick upward click — like a light switch."""
    dur = DURATION_SEC["flip"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        # short burst of white noise with a quick decay, plus a tiny sine pop
        noise = (math.random_gen() if hasattr(math, 'random_gen') else __import__('random').uniform(-1, 1)) * 0.3
        sine = math.sin(2 * math.pi * 600 * t) * 0.5
        s = (noise + sine) * env[i] if i < len(env) else 0
        samples.append(max(-1, min(1, s)))
    return samples


def gen_match():
    """Pleasant ascending chime — two sine notes."""
    dur = DURATION_SEC["match"]
    env = _envelope(dur)
    samples = []
    notes = [(700, 0.1), (950, 0.12)]          # freq, start offset
    for i in range(int(RATE * dur)):
        t = i / RATE
        val = 0.3 * math.sin(2 * math.pi * notes[0][0] * (t - notes[0][1])) if t >= notes[0][1] else 0
        val += 0.3 * math.sin(2 * math.pi * notes[1][0] * (t - notes[1][1])) if t >= notes[1][1] else 0
        samples.append(max(-1, min(1, val * env[i])))
    return samples


def gen_mismatch():
    """Low dead thump — falling frequency, short."""
    dur = DURATION_SEC["mismatch"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        # frequency drops from 150 to 40 Hz (pitch sweep down)
        freq = 150 - (110 / dur) * t
        s = math.sin(2 * math.pi * freq * t) * 0.6
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_poison():
    """Hissing siren — descending frequency with noise."""
    dur = DURATION_SEC["poison"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        freq = 800 - (600 / dur) * t          # descends 800→200 Hz
        s = math.sin(2 * math.pi * freq * t) * 0.4
        # add some noise for the "sizzle" character
        s += __import__('random').uniform(-0.3, 0.3) * math.sin(2 * math.pi * 3000 * t)
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_heal():
    """Warm ascending bell — gentle arpeggio."""
    dur = DURATION_SEC["heal"]
    env = _envelope(dur)
    samples = []
    notes = [(500, 0.0), (630, 0.08), (790, 0.15)]
    for i in range(int(RATE * dur)):
        t = i / RATE
        val = 0.25 * math.sin(2 * math.pi * notes[0][0] * (t - notes[0][1])) if t >= notes[0][1] else 0
        val += 0.25 * math.sin(2 * math.pi * notes[1][0] * (t - notes[1][1])) if t >= notes[1][1] else 0
        val += 0.25 * math.sin(2 * math.pi * notes[2][0] * (t - notes[2][1])) if t >= notes[2][1] else 0
        samples.append(max(-1, min(1, val * env[i])))
    return samples


def gen_gem():
    """High shimmer — long decay high sine."""
    dur = DURATION_SEC["gem"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        # fast vibrato for "crystal" character
        f_mod = 2400 + math.sin(2 * math.pi * 18 * t) * 200
        s = math.sin(2 * math.pi * f_mod * t) * 0.4
        # add harmonic
        s += math.sin(2 * math.pi * f_mod * 2 * t) * 0.15
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_scroll():
    """Paper rustle + spark — noise burst then clear tone."""
    dur = DURATION_SEC["scroll"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        # noise burst (first 60ms)
        noise = __import__('random').uniform(-1, 1) * (0.4 if t < 0.06 else 0)
        # spark tone (after 15ms)
        spark = math.sin(2 * math.pi * 1200 * (t - 0.015)) if t >= 0.015 else 0
        s = noise + spark * 0.3
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_treasure():
    """Metallic jingle cluster — multiple high frequencies."""
    dur = DURATION_SEC["treasure"]
    env = _envelope(dur)
    samples = []
    freqs = [1800, 2100, 1600, 2400]         # jingle cluster
    for i in range(int(RATE * dur)):
        t = i / RATE
        s = 0.12 * sum(math.sin(2 * math.pi * f * t) for f in freqs)
        # metallic ring — harmonics
        s += 0.06 * sum(math.sin(2 * math.pi * f * 3 * t) for f in freqs[:2])
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_shuffle():
    """Whoosh sweep — frequency sweeps up then down."""
    dur = DURATION_SEC["shuffle"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        freq = 200 + (1000 * math.sin(math.pi * t / dur))    # arcs up then down
        s = math.sin(2 * math.pi * freq * t) * 0.3
        # add noise band for "whoosh" texture
        s += __import__('random').uniform(-0.5, 0.5) * math.sin(2 * math.pi * freq * t) * 0.3
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_victory():
    """Short triumphant fanfare — 4 ascending notes."""
    dur = DURATION_SEC["victory"]
    env = _envelope(dur)
    samples = []
    notes = [(523, 0.0), (659, 0.08), (784, 0.16), (1046, 0.24)]
    for i in range(int(RATE * dur)):
        t = i / RATE
        s = 0.3 * math.sin(2 * math.pi * notes[0][0] * (t - notes[0][1])) if t >= notes[0][1] else 0
        s += 0.3 * math.sin(2 * math.pi * notes[1][0] * (t - notes[1][1])) if t >= notes[1][1] else 0
        s += 0.3 * math.sin(2 * math.pi * notes[2][0] * (t - notes[2][1])) if t >= notes[2][1] else 0
        s += 0.3 * math.sin(2 * math.pi * notes[3][0] * (t - notes[3][1])) if t >= notes[3][1] else 0
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_gameover():
    """Dramatic drop — frequency sweeps down, rumble at end."""
    dur = DURATION_SEC["gameover"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        # freq drops from 600 to 30 Hz (despair sweep)
        freq = max(30, 600 - (570 / dur) * t)
        s = math.sin(2 * math.pi * freq * t) * 0.4
        # rumble (low sub-bass) at the end
        if t > dur * 0.5:
            s += math.sin(2 * math.pi * 40 * t) * (t / dur)
        samples.append(max(-1, min(1, s * env[i])))
    return samples


def gen_whoosh():
    """UI transition whoosh — noise burst with envelope."""
    dur = DURATION_SEC["whoosh"]
    env = _envelope(dur)
    samples = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        # band-pass noise: mix two noise bands
        n1 = __import__('random').uniform(-1, 1) * math.sin(2 * math.pi * 400 * t)
        n2 = __import__('random').uniform(-1, 1) * math.sin(2 * math.pi * 800 * t)
        s = (n1 + n2) * 0.3
        samples.append(max(-1, min(1, s * env[i])))
    return samples


# ── main ───────────────────────────────────────────────────────────────────

SFX_MAP = {
    "flip":      gen_flip,
    "match":     gen_match,
    "mismatch":  gen_mismatch,
    "poison":    gen_poison,
    "heal":      gen_heal,
    "gem":       gen_gem,
    "scroll":    gen_scroll,
    "treasure":  gen_treasure,
    "shuffle":   gen_shuffle,
    "victory":   gen_victory,
    "gameover":  gen_gameover,
    "whoosh":    gen_whoosh,
}

if __name__ == "__main__":
    import random          # for random.uniform in generators
    
    out_dir = os.path.join(os.getcwd(), "assets", "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)

    for name, gen_fn in SFX_MAP.items():
        filepath = os.path.join(out_dir, f"{name}.wav")
        samples = gen_fn()
        _write_wav(filepath, samples)
        print(f"✓ {name}.wav  ({len(samples)/RATE:.2f}s)")

    print(f"\nAll {len(SFX_MAP)} SFX files written to {out_dir}/")
