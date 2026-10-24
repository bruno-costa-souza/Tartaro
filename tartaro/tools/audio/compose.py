"""Composes Tártaro's soundtrack and sound effects offline.

Run from the project root (needs numpy and soundfile: pip install numpy soundfile):
    python3 tools/audio/compose.py            # music + effects
    python3 tools/audio/compose.py music      # only the music
    python3 tools/audio/compose.py sfx        # only the effects

Music goes to audio/music/<track>.ogg as seamless loops (the mixer wraps note
tails and reverb around the loop point). Effects go to audio/sfx/<name>.wav,
looping ambiences to audio/sfx/<name>.ogg.
"""

import math
import os
import sys

import numpy as np
import soundfile as sf

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from synth import (SR, Mix, aulos, band, bass, bell, brass, choir, cymbal, doum, env, fade, flute, hz, lyre, m,  # noqa: E402
                   noise, pad, shaker, snare, strings, swell, taiko, tek, times, anvil)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
SFX_DIR = os.path.join(ROOT, "audio", "sfx")

CHORDS = {
    "D": (50, (0, 4, 7)), "Dm": (50, (0, 3, 7)), "Eb": (51, (0, 4, 7)), "Gm": (55, (0, 3, 7)),
    "Cm": (48, (0, 3, 7)), "C": (48, (0, 4, 7)), "Em": (52, (0, 3, 7)), "Am": (57, (0, 3, 7)),
    "B": (59, (0, 4, 7)), "G": (55, (0, 4, 7)), "F": (53, (0, 4, 7)), "Bb": (58, (0, 4, 7)),
    "A": (57, (0, 4, 7)),
}


class Song:
    def __init__(self, bpm, bars):
        self.spb = 60.0 / bpm
        self.bars = bars
        self.mix = Mix(bars * 4 * self.spb)

    def t(self, bar, beat=0.0):
        return (bar * 4 + beat) * self.spb

    def play(self, sig, bar, beat, gain, pan=0.0, rev=0.2):
        self.mix.add(sig, self.t(bar, beat), gain, pan, rev)

    def melody(self, inst, notes, bar0, gain, pan=0.0, rev=0.35, shift=0, **kw):
        """notes: list of (name or None, beats); consecutive bars from bar0."""
        beat = 0.0
        for name, beats in notes:
            if name:
                f = hz(m(name) + shift)
                self.play(inst(f, beats * self.spb * 0.98, **kw), bar0, beat, gain, pan, rev)
            beat += beats

    def write(self, name, rt60=2.4, damp=5200, level=0.9):
        out = self.mix.render(rt60, damp, master=level)
        os.makedirs(MUSIC_DIR, exist_ok=True)
        path = os.path.join(MUSIC_DIR, name + ".ogg")
        sf.write(path, out.astype(np.float32), SR, format="OGG", subtype="VORBIS")
        print("music", name, "%.1fs" % (len(out) / SR), path)


def tones(chord, octave_shift=0):
    root, ivs = CHORDS[chord]
    return [root + i + octave_shift for i in ivs]


def arp16(S, chord_seq, bars, inst_gain, pan=-0.3, pattern=(0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 1),
          octave=12, rev=0.3, decay=1.0, bright=1.0, step=0.25, accent=4):
    for bar in bars:
        root, ivs = CHORDS[chord_seq[bar % len(chord_seq)]]
        pool = [root + octave + ivs[0], root + octave + ivs[1], root + octave + ivs[2], root + octave + 12]
        for i, idx in enumerate(pattern):
            if i * step >= 4.0:
                break
            vel = 1.0 if i % accent == 0 else 0.72
            S.play(lyre(hz(pool[idx]), step * S.spb, bright=bright, decay=decay), bar, i * step, inst_gain * vel, pan, rev)


def pads(S, inst, chord_seq, bars, gain, octave=0, rev=0.45, spread=0.5, **kw):
    for bar in bars:
        ts = tones(chord_seq[bar % len(chord_seq)], octave)
        for k, n in enumerate(ts):
            S.play(inst(hz(n), 4 * S.spb, **kw), bar, 0.0, gain, (k - 1) * spread, rev)


def drums_maqsum(S, bars, gain=1.0, fills=False):
    for bar in bars:
        for beat in (0.0, 2.0):
            S.play(doum(), bar, beat, 0.5 * gain, -0.1, 0.15)
        for beat in (0.5, 1.5, 3.0):
            S.play(tek(), bar, beat, 0.32 * gain, 0.2, 0.12)
        if fills and bar % 2 == 1:
            for beat in (3.5, 3.75):
                S.play(tek(tone=1.15), bar, beat, 0.26 * gain, 0.25, 0.12)


def shakers(S, bars, gain=1.0, step=0.25):
    pattern = (0.55, 0.25, 0.4, 0.25)
    for bar in bars:
        i = 0
        b = 0.0
        while b < 4.0 - 1e-6:
            S.play(shaker(), bar, b, 0.16 * gain * pattern[i % 4], 0.35, 0.08)
            b += step
            i += 1


# ---------------------------------------------------------------- tracks

def tartaro():
    """Tártaro: driving D Phrygian dominant, taiko + darbuka, aulos lead."""
    S = Song(118, 24)
    seq = ["D", "D", "Eb", "D", "Gm", "Cm", "Eb", "D"]
    S.play(pad(hz(m("D2")), S.mix.n / SR, attack=3.0, release=3.0), 0, 0, 0.16, 0.0, 0.1)
    for bar in range(24):
        chord = seq[bar % 8]
        root = CHORDS[chord][0] - 24
        riff = [38, 38, 50, 38, 39, 38, 36, 38] if chord == "D" else [root, root, root + 12, root, root, root + 12, root + 7, root]
        for i, note in enumerate(riff):
            vel = 1.0 if i in (0, 4) else 0.75
            S.play(bass(hz(note), 0.5 * S.spb * 0.9, drive=2.4, bright=1.0), bar, i * 0.5, 0.3 * vel, 0.0, 0.04)
        S.play(taiko(), bar, 0.0, 0.85, 0.0, 0.25)
        S.play(taiko(52), bar, 2.0, 0.6, 0.0, 0.25)
        if bar >= 16 or bar % 4 == 3:
            S.play(taiko(64), bar, 3.5, 0.5, 0.1, 0.25)
    drums_maqsum(S, range(24), 1.0, fills=True)
    shakers(S, range(4, 24))
    for bar in (0, 8, 16):
        S.play(cymbal(), bar, 0.0, 0.5, 0.2, 0.35)
    for bar in (8, 16):
        sw = swell(1.5 * S.spb)
        S.mix.add(sw, S.t(bar, 0.0) - len(sw) / SR, 0.5, -0.2, 0.3)
    pads(S, strings, seq, range(0, 8), 0.12, octave=-12, bright=0.4)
    for bar in range(0, 8):
        root, ivs = CHORDS[seq[bar % 8]]
        for i, beat in enumerate((0, 1, 2, 3)):
            S.play(lyre(hz(root + 12 + ivs[(i * 2) % 3]), S.spb), bar, beat, 0.2, -0.3, 0.3)
    arp16(S, seq, range(8, 24), 0.17, pan=-0.35)
    lead = [("A4", 1), ("Bb4", 0.5), ("A4", 0.5), ("G4", 1), ("F#4", 1),
            ("G4", 0.5), ("F#4", 0.5), ("Eb4", 1), ("D4", 2),
            ("Eb4", 1), ("G4", 1), ("Bb4", 1.5), ("A4", 0.5),
            ("A4", 3), (None, 1),
            ("D5", 1), ("C5", 0.5), ("Bb4", 0.5), ("G4", 1), ("Bb4", 1),
            ("C5", 1.5), ("Bb4", 0.5), ("G4", 1), ("Eb4", 1),
            ("G4", 0.5), ("Bb4", 0.5), ("Eb5", 1), ("D5", 0.5), ("C5", 0.5), ("Bb4", 1),
            ("A4", 2), ("F#4", 1), ("D4", 1)]
    S.melody(aulos, lead, 8, 0.36, pan=0.12, rev=0.32)
    S.melody(aulos, lead, 16, 0.3, pan=0.12, rev=0.36, shift=12)
    S.melody(flute, lead, 16, 0.22, pan=-0.15, rev=0.4)
    pads(S, choir, seq, range(16, 24), 0.13, octave=0, vowel="a")
    S.write("tartaro", rt60=2.2)


def asfodelo():
    """Asfódelo: hollow E Dorian meadow, harp + flute, soft frame drums."""
    S = Song(100, 24)
    seq = ["Em", "C", "D", "Em", "Am", "Em", "B", "Em"]
    S.play(pad(hz(m("E2")), S.mix.n / SR, attack=3.0, release=3.0), 0, 0, 0.14, 0.0, 0.1)
    wind = band(noise(S.mix.n), 300, 1400) * (0.6 + 0.4 * np.sin(2 * math.pi * times(S.mix.n) * 2 / (S.mix.n / SR)))
    S.mix.add(wind, 0.0, 0.05, 0.0, 0.3)
    for bar in range(24):
        root = CHORDS[seq[bar % 8]][0] - 24
        for beat, note, d in ((0.0, root, 1.5), (1.5, root, 0.5), (2.0, root + 7, 1.0), (3.0, root + 12, 1.0)):
            S.play(bass(hz(note), d * S.spb * 0.95, drive=1.6, bright=0.6), bar, beat, 0.26, 0.0, 0.05)
        S.play(doum(), bar, 0.0, 0.42, -0.1, 0.25)
        S.play(doum(), bar, 2.5, 0.3, -0.1, 0.25)
        for beat in (1.0, 3.0):
            S.play(tek(tone=0.9), bar, beat, 0.2, 0.25, 0.2)
        if bar % 4 == 0:
            S.play(taiko(50), bar, 0.0, 0.45, 0.0, 0.35)
            S.play(bell(hz(CHORDS[seq[bar % 8]][0] + 24)), bar, 0.0, 0.14, 0.4, 0.6)
    shakers(S, range(8, 24), 0.7, step=0.5)
    arp = (0, 1, 2, 3, 2, 1, 2, 3)
    arp16(S, seq, range(24), 0.2, pan=-0.35, pattern=arp, step=0.5, decay=0.6, bright=0.8, accent=8, rev=0.45)
    pads(S, strings, seq, range(0, 24), 0.08, octave=-12, bright=0.3, attack=0.8)
    lead = [("B4", 1.5), ("A4", 0.5), ("G4", 1), ("F#4", 1),
            ("G4", 1), ("E4", 2), (None, 1),
            ("F#4", 1), ("A4", 1), ("D5", 1.5), ("C#5", 0.5),
            ("B4", 3), (None, 1),
            ("C5", 1), ("B4", 0.5), ("A4", 0.5), ("E5", 2),
            ("D5", 1), ("B4", 1), ("G4", 1.5), ("A4", 0.5),
            ("F#4", 1), ("B4", 1), ("D#5", 1), ("C#5", 0.5), ("B4", 0.5),
            ("E5", 2), ("B4", 1), ("E4", 1)]
    S.melody(flute, lead, 8, 0.4, pan=0.15, rev=0.45)
    S.melody(lambda f, d: lyre(f, d, bright=1.2, decay=0.8), lead, 16, 0.3, pan=0.1, rev=0.45, shift=12)
    S.melody(flute, lead, 16, 0.22, pan=-0.1, rev=0.5)
    pads(S, choir, seq, range(16, 24), 0.12, octave=0, vowel="o")
    S.write("asfodelo", rt60=3.0, damp=4500)


def elisio():
    """Elísio: bright heroic G Mixolydian, brass lead, harp and drums."""
    S = Song(126, 24)
    seq = ["G", "D", "Em", "C", "G", "F", "C", "D"]
    for bar in range(24):
        root = CHORDS[seq[bar % 8]][0] - 24
        for beat in range(4):
            S.play(bass(hz(root), 0.45 * S.spb, drive=2.2, bright=0.9), bar, beat, 0.3, 0.0, 0.04)
            S.play(bass(hz(root + (12 if beat % 2 else 7)), 0.22 * S.spb, drive=2.2, bright=0.9), bar, beat + 0.5, 0.22, 0.0, 0.04)
            S.play(bass(hz(root + 12), 0.22 * S.spb, drive=2.2, bright=0.9), bar, beat + 0.75, 0.2, 0.0, 0.04)
        S.play(taiko(62), bar, 0.0, 0.75, 0.0, 0.25)
        S.play(taiko(56), bar, 2.0, 0.6, 0.0, 0.25)
        if bar >= 8:
            S.play(snare(), bar, 1.0, 0.32, 0.1, 0.25)
            S.play(snare(), bar, 3.0, 0.36, 0.1, 0.25)
        if bar % 4 == 3:
            for k in range(4):
                S.play(snare(tone=210), bar, 3.0 + k * 0.25, 0.14 + 0.05 * k, 0.1, 0.2)
    shakers(S, range(24), 0.9)
    for bar in (0, 8, 16):
        S.play(cymbal(), bar, 0.0, 0.55, 0.25, 0.35)
    arp16(S, seq, range(24), 0.16, pan=-0.35, bright=1.3, rev=0.32)
    pads(S, strings, seq, range(24), 0.09, octave=-12, bright=0.7)
    lead = [("D5", 1.5), ("B4", 0.5), ("G4", 1), ("B4", 1),
            ("A4", 1.5), ("F#4", 0.5), ("D4", 1), ("A4", 1),
            ("B4", 1), ("G4", 0.5), ("B4", 0.5), ("E5", 1.5), ("D5", 0.5),
            ("C5", 2), ("G4", 1), ("E4", 1),
            ("G4", 0.5), ("A4", 0.5), ("B4", 1), ("D5", 1), ("G5", 1),
            ("F5", 1.5), ("E5", 0.5), ("C5", 1), ("A4", 1),
            ("G4", 1), ("C5", 1), ("E5", 1), ("D5", 0.5), ("C5", 0.5),
            ("D5", 3), (None, 1)]
    S.melody(brass, lead, 8, 0.34, pan=0.1, rev=0.3)
    S.melody(brass, lead, 16, 0.3, pan=0.1, rev=0.32)
    S.melody(brass, lead, 16, 0.2, pan=-0.15, rev=0.32, shift=-12)
    pads(S, choir, seq, range(16, 24), 0.12, octave=0, vowel="a")
    for bar in range(0, 8):
        ts = tones(seq[bar % 8])
        S.play(brass(hz(ts[0]), 0.9 * S.spb, bright=0.6), bar, 0.0, 0.2, -0.2, 0.3)
        S.play(brass(hz(ts[2]), 0.9 * S.spb, bright=0.6), bar, 0.0, 0.16, 0.2, 0.3)
    S.write("elisio", rt60=2.6, damp=6500)


def boss():
    """Boss: 140 BPM, heavy taiko, distorted ostinato, choir stabs, aulos scream."""
    S = Song(140, 16)
    seq = ["D", "Eb", "Cm", "D", "D", "Eb", "Gm", "D"]
    S.play(pad(hz(m("D2")), S.mix.n / SR, attack=2.0, release=2.0), 0, 0, 0.16, 0.0, 0.1)
    for bar in range(16):
        chord = seq[bar % 8]
        root = CHORDS[chord][0] - 24
        for i in range(16):
            note = root + (12 if i % 4 == 2 else 0) + (1 if (chord == "D" and i in (6, 14)) else 0)
            S.play(bass(hz(note), 0.25 * S.spb * 0.85, drive=3.0, bright=1.0), bar, i * 0.25, 0.3 * (1.0 if i % 4 == 0 else 0.75), 0.0, 0.03)
        for i in range(8):
            S.play(taiko(58 if i % 2 == 0 else 66), bar, i * 0.5, 0.75 if i % 2 == 0 else 0.42, 0.0, 0.2)
        S.play(snare(), bar, 1.0, 0.45, 0.08, 0.2)
        S.play(snare(), bar, 3.0, 0.5, 0.08, 0.2)
        r, ivs = CHORDS[chord]
        S.play(choir(hz(r + 12), 0.9 * S.spb, vowel="a", attack=0.02, release=0.5), bar, 0.0, 0.2, -0.3, 0.4)
        S.play(choir(hz(r + 12 + ivs[1]), 0.9 * S.spb, vowel="a", attack=0.02, release=0.5), bar, 0.0, 0.16, 0.3, 0.4)
        S.play(brass(hz(r), 0.4 * S.spb, attack=0.02, bright=1.2), bar, 2.5, 0.18, 0.15, 0.25)
        fig = [r + 24, r + 25, r + 24, r + 19] if chord == "D" else [r + 24, r + 24 + ivs[1], r + 24 + ivs[2], r + 24 + ivs[1]]
        for i in range(16):
            S.play(lyre(hz(fig[i % 4]), 0.25 * S.spb, bright=1.4, decay=1.6), bar, i * 0.25, 0.13, -0.4, 0.25)
    for bar in (0, 4, 8, 12):
        S.play(cymbal(decay=1.0), bar, 0.0, 0.55, 0.2, 0.3)
    sw = swell(2.0 * S.spb)
    S.mix.add(sw, S.t(8, 0.0) - len(sw) / SR, 0.55, -0.2, 0.3)
    S.mix.add(sw, S.t(0, 0.0) - len(sw) / SR, 0.55, -0.2, 0.3)
    lead = [("D5", 0.5), ("Eb5", 0.5), ("F#5", 1), ("G5", 0.5), ("F#5", 0.5), ("Eb5", 1),
            ("Eb5", 1), ("G5", 1), ("Bb5", 1.5), ("A5", 0.5),
            ("G5", 1), ("Eb5", 1), ("C5", 1.5), ("D5", 0.5),
            ("D5", 3), (None, 1),
            ("A5", 0.5), ("Bb5", 0.5), ("A5", 0.5), ("G5", 0.5), ("F#5", 1), ("Eb5", 1),
            ("G5", 1.5), ("Eb5", 0.5), ("Bb4", 1), ("Eb5", 1),
            ("D5", 1), ("Bb4", 1), ("G4", 1), ("Bb4", 1),
            ("C5", 1), ("Eb5", 1), ("D5", 2)]
    S.melody(aulos, lead, 8, 0.36, pan=0.12, rev=0.3, nasal=0.9)
    S.melody(strings, lead, 8, 0.12, pan=-0.12, rev=0.35, shift=-12, attack=0.05, release=0.3, bright=0.9)
    pads(S, choir, seq, range(8, 16), 0.1, octave=-12, vowel="o", attack=0.3)
    S.write("boss", rt60=1.9, damp=6000, level=0.92)


def menu():
    """Menu: calm D Dorian, slow lyre, pad, sparse flute, distant drum."""
    S = Song(72, 16)
    seq = ["Dm", "C", "Bb", "C", "Dm", "Am", "Bb", "A"]
    S.play(pad(hz(m("D3")), S.mix.n / SR, attack=4.0, release=4.0), 0, 0, 0.12, 0.0, 0.3)
    wind = band(noise(S.mix.n), 250, 1100) * (0.5 + 0.5 * np.sin(2 * math.pi * times(S.mix.n) * 3 / (S.mix.n / SR)))
    S.mix.add(wind, 0.0, 0.05, 0.0, 0.4)
    arp = (0, 2, 1, 3, 2, 1, 3, 2)
    arp16(S, seq, range(16), 0.24, pan=-0.25, pattern=arp, step=0.5, decay=0.5, bright=0.7, accent=8, rev=0.55)
    pads(S, strings, seq, range(16), 0.09, octave=-12, bright=0.25, attack=1.2, release=2.0)
    pads(S, choir, seq, range(8, 16), 0.08, octave=0, vowel="u", attack=1.5, release=2.0)
    for bar in range(16):
        S.play(doum(), bar, 0.0, 0.26, 0.0, 0.4)
        S.play(doum(), bar, 2.5, 0.16, 0.0, 0.4)
        root = CHORDS[seq[bar % 8]][0]
        S.play(bass(hz(root - 12), 3.8 * S.spb, drive=1.3, bright=0.5), bar, 0.0, 0.2, 0.0, 0.1)
        if bar % 4 == 0:
            S.play(bell(hz(root + 24), dur=4.0, decay=0.6), bar, 0.0, 0.12, 0.35, 0.7)
    lead_a = [("A4", 2), ("F4", 1), ("E4", 1),
              ("C5", 1.5), ("B4", 0.5), ("A4", 2),
              ("D5", 1), ("F5", 1.5), ("E5", 0.5), ("D5", 1),
              ("C#5", 3), ("E5", 1)]
    lead_b = [("F5", 1.5), ("E5", 0.5), ("D5", 1), ("A4", 1),
              ("C5", 2), ("E5", 1), ("A4", 1),
              ("Bb4", 1), ("D5", 1), ("F5", 1), ("E5", 0.5), ("D5", 0.5),
              ("C#5", 2), ("E5", 1), ("A4", 1)]
    S.melody(flute, lead_a, 4, 0.34, pan=0.15, rev=0.55)
    S.melody(flute, lead_b, 12, 0.34, pan=0.15, rev=0.55)
    S.write("menu", rt60=3.4, damp=4200, level=0.85)


TRACKS = {"menu": menu, "tartaro": tartaro, "asfodelo": asfodelo, "elisio": elisio, "boss": boss}


# ---------------------------------------------------------------- effects

def write_sfx(name, sig, level=0.9, loop=False):
    os.makedirs(SFX_DIR, exist_ok=True)
    sig = np.asarray(sig, dtype=np.float64)
    peak = np.max(np.abs(sig)) or 1.0
    sig = sig / peak * level
    if loop:
        path = os.path.join(SFX_DIR, name + ".ogg")
        sf.write(path, sig.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    else:
        path = os.path.join(SFX_DIR, name + ".wav")
        sf.write(path, fade(sig).astype(np.float32), SR, subtype="PCM_16")


def sweep_noise(dur, f0, f1, q=0.6, shape=None):
    """Noise through a band whose centre glides f0 -> f1 (block processed)."""
    n = int(dur * SR)
    out = np.zeros(n)
    block = 1024
    src = noise(n + block)
    for i in range(0, n, block // 2):
        c = f0 + (f1 - f0) * (i / max(n - 1, 1))
        seg = src[i:i + block] * np.hanning(block)
        out_seg = band(seg, c * (1 - q * 0.5), c * (1 + q))
        end = min(n, i + block)
        out[i:end] += out_seg[:end - i]
    t = times(n)
    e = np.sin(np.pi * np.minimum(t / dur, 1.0)) if shape is None else shape(t)
    return out * e


def glide(dur, f0, f1, decay=0.0, curve=1.0):
    n = int(dur * SR)
    t = times(n)
    f = f0 + (f1 - f0) * (t / dur) ** curve
    s = np.sin(2 * math.pi * np.cumsum(f) / SR)
    return s * (np.exp(-t * decay) if decay else 1.0)


def thump(f0=140, f1=50, dur=0.18, decay=18):
    n = int(dur * SR)
    t = times(n)
    f = f1 + (f0 - f1) * np.exp(-t * 30)
    return np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * decay)


def pad_to(sig, dur):
    n = int(dur * SR)
    out = np.zeros(max(n, len(sig)))
    out[:len(sig)] = sig
    return out[:n] if n >= len(sig) else out


def layer(dur, *parts):
    """parts: (signal, start_seconds, gain)"""
    n = int(dur * SR)
    out = np.zeros(n)
    for sig, start, gain in parts:
        i = int(start * SR)
        k = min(len(sig), n - i)
        if k > 0:
            out[i:i + k] += sig[:k] * gain
    return out


def tail(sig, rt=0.8, wet=0.3):
    """Short mono reverb tail for effects."""
    n = len(sig) + int(rt * SR)
    t = times(int(rt * SR))
    ir = band(noise(len(t)) * np.exp(-6.9 * t / rt), 200, 6000)
    ir /= np.sqrt(np.sum(ir ** 2)) * 2.0
    dry = np.zeros(n)
    dry[:len(sig)] = sig
    size = 1 << int(math.ceil(math.log2(n + len(ir))))
    wet_sig = np.fft.irfft(np.fft.rfft(dry, size) * np.fft.rfft(ir, size), size)[:n]
    out = dry + wet * wet_sig
    return out * env(n, 0.001, min(0.2, rt * 0.4))


def roar(dur=1.6, f0=95.0, f1=60.0, rough=0.6):
    """Beast roar: buzzy glottal source through a moving 'aw' formant."""
    n = int(dur * SR)
    t = times(n)
    f = f0 + (f1 - f0) * (t / dur) + 8 * np.sin(2 * math.pi * 7 * t)
    ph = np.cumsum(f) / SR
    src = 2 * (ph % 1.0) - 1.0
    src = src + rough * noise(n) * 0.6
    voice = band(src, 250, 1100) * 1.2 + band(src, 1200, 2600) * 0.5
    e = np.minimum(t / 0.12, 1.0) * np.exp(-np.maximum(t - dur * 0.5, 0) * 4)
    return np.tanh(voice * e * 2.0)


def make_sfx():
    S = {}
    # weapons
    S["shoot"] = tail(layer(0.3, (sweep_noise(0.16, 900, 3500, 0.8), 0, 0.9), (thump(220, 90, 0.12, 25), 0, 0.5)), 0.4, 0.15)
    S["arrow"] = tail(layer(0.35, (lyre(hz(m("D3")), 0.1, bright=1.5, decay=6), 0, 0.9), (sweep_noise(0.2, 2500, 6000, 0.6), 0.01, 0.4)), 0.3, 0.1)
    S["slash"] = tail(sweep_noise(0.2, 600, 4500, 1.0), 0.3, 0.12)
    zap = noise(int(0.18 * SR)) * (np.random.default_rng(3).random(int(0.18 * SR)) < 0.08)
    S["zap"] = tail(layer(0.4, (band(zap, 800, 9000) * np.exp(-times(len(zap)) * 14), 0, 1.2),
                         (glide(0.15, 2400, 900, 18), 0, 0.3), (thump(90, 40, 0.3, 8), 0, 0.4)), 0.5, 0.2)
    # combat
    S["hit"] = layer(0.2, (thump(170, 55, 0.18, 22), 0, 1.0), (band(noise(int(0.05 * SR)), 1500, 8000) * np.exp(-times(int(0.05 * SR)) * 90), 0, 0.5))
    S["crit"] = tail(layer(0.5, (S["hit"], 0, 1.0), (bell(hz(m("A6")), 0.4, 3.0), 0, 0.5)), 0.4, 0.2)
    soul = glide(0.4, 500, 1400, 6, 0.6) * 0.35
    crunch = band(noise(int(0.12 * SR)), 300, 4000) * np.exp(-times(int(0.12 * SR)) * 35)
    S["kill"] = tail(layer(0.6, (thump(240, 60, 0.25, 12), 0, 0.8), (crunch, 0, 0.7), (soul, 0.04, 1.0)), 0.6, 0.25)
    S["dash"] = sweep_noise(0.24, 400, 2600, 1.0)
    S["hurt"] = tail(layer(0.4, (thump(130, 45, 0.3, 9), 0, 1.0), (band(noise(int(0.2 * SR)), 200, 2000) * np.exp(-times(int(0.2 * SR)) * 14), 0, 0.6),
                          (roar(0.22, 180, 120, 0.3), 0.0, 0.25)), 0.4, 0.15)
    S["step"] = layer(0.1, (thump(110, 60, 0.08, 40), 0, 0.7), (band(noise(int(0.05 * SR)), 300, 2500) * np.exp(-times(int(0.05 * SR)) * 70), 0, 0.35))
    S["explode"] = tail(layer(1.2, (thump(120, 35, 1.0, 4.5), 0, 1.0), (band(noise(int(1.0 * SR)), 60, 3000) * np.exp(-times(int(1.0 * SR)) * 5), 0, 0.9)), 0.9, 0.3)
    S["fuse"] = band(noise(int(0.55 * SR)), 3000, 9000) * (0.5 + 0.5 * (np.random.default_rng(5).random(int(0.55 * SR)) < 0.02)) * np.linspace(0.4, 1.0, int(0.55 * SR))
    S["spawn"] = tail(sweep_noise(0.45, 200, 900, 0.9, shape=lambda t: (t / 0.45) ** 2 * np.exp(-np.maximum(t - 0.4, 0) * 30)), 0.5, 0.3) + 0.0
    S["growl"] = tail(roar(0.55, 110, 80, 0.8), 0.3, 0.15)
    S["charge"] = layer(0.45, (sweep_noise(0.42, 300, 1500, 1.0), 0, 1.0), (thump(80, 40, 0.4, 5), 0, 0.5))
    S["enemy_shot"] = tail(layer(0.35, (lyre(hz(m("A2")), 0.1, bright=1.2, decay=5), 0, 0.8), (sweep_noise(0.2, 1500, 3500, 0.6), 0.02, 0.35)), 0.4, 0.15)
    # bosses
    S["boss_intro"] = tail(layer(2.6, (roar(1.8, 85, 55, 0.7), 0.2, 1.0), (taiko(48, 1.6), 0, 0.9), (taiko(44, 1.6), 0.7, 0.8),
                                (choir(hz(m("D3")), 1.5, "a", 0.05, 0.8), 0.6, 0.35), (choir(hz(m("Eb3")), 1.5, "a", 0.05, 0.8), 0.6, 0.25)), 1.2, 0.35)
    S["boss_phase"] = tail(layer(1.6, (roar(1.2, 120, 70, 0.9), 0, 1.0), (thump(70, 30, 1.0, 3), 0, 0.7), (cymbal(1.2, 3.0), 0, 0.4)), 0.8, 0.3)
    S["boss_shot"] = tail(layer(0.4, (sweep_noise(0.2, 600, 2200, 0.8), 0, 0.9), (thump(160, 60, 0.2, 14), 0, 0.7)), 0.5, 0.2)
    S["boss_ring"] = tail(layer(0.7, (sweep_noise(0.5, 300, 3000, 1.2), 0, 0.9), (bell(hz(m("D5")), 0.6, 2.5), 0, 0.3), (thump(100, 45, 0.4, 7), 0, 0.6)), 0.6, 0.3)
    S["wall_slam"] = tail(layer(0.8, (taiko(45, 0.8), 0, 1.0), (band(noise(int(0.4 * SR)), 100, 5000) * np.exp(-times(int(0.4 * SR)) * 9), 0, 0.8)), 0.6, 0.3)
    whine = glide(0.85, 300, 1300, 0, 1.4) * (0.6 + 0.4 * np.sin(2 * math.pi * 22 * times(int(0.85 * SR)))) * np.linspace(0.2, 1.0, int(0.85 * SR))
    S["beam_charge"] = tail(whine * 0.6, 0.3, 0.2)
    buzz_n = int(0.45 * SR)
    saw = 2 * ((np.cumsum(np.full(buzz_n, 160.0)) / SR) % 1.0) - 1.0
    S["beam_fire"] = tail(layer(0.6, (band(saw, 200, 5000) * np.exp(-times(buzz_n) * 4), 0, 0.8), (S["zap"], 0, 0.6)), 0.4, 0.25)
    S["teleport"] = tail(layer(0.6, (sweep_noise(0.5, 3000, 600, 0.8), 0, 0.6), (glide(0.4, 1800, 400, 6), 0, 0.3)), 0.6, 0.35)
    S["summon"] = tail(layer(1.0, (roar(0.6, 140, 90, 0.5), 0, 0.6), (sweep_noise(0.7, 150, 1200, 0.9), 0.1, 0.6)), 0.8, 0.35)
    S["meteor"] = tail(glide(1.0, 1800, 300, 0.5, 0.8) * 0.5 + sweep_noise(1.0, 2500, 500, 0.5) * 0.4, 0.4, 0.2)
    # rewards / progression
    S["xp"] = glide(0.09, 1400, 2100, 30) * 0.6
    S["coin"] = tail(bell(hz(m("E7")), 0.4, 2.5) * 0.8 + bell(hz(m("B7")), 0.4, 3.0) * 0.4, 0.3, 0.15)
    S["heal"] = tail(layer(0.9, *[(bell(hz(m(n)), 0.6, 2.2), i * 0.07, 0.6) for i, n in enumerate(("A5", "C#6", "E6", "A6"))]), 0.6, 0.3)
    S["levelup"] = tail(layer(1.0, *[(lyre(hz(m(n)), 0.5, bright=1.3), i * 0.08, 0.7) for i, n in enumerate(("D5", "F#5", "A5", "D6"))],
                              (bell(hz(m("D6")), 0.8, 1.2), 0.32, 0.4)), 0.8, 0.3)
    S["buy"] = tail(layer(0.6, (S["coin"], 0, 0.8), (bell(hz(m("A6")), 0.5, 1.6), 0.08, 0.5)), 0.4, 0.2)
    S["wave"] = tail(layer(1.8, *[(lyre(hz(m(n)), 1.2, bright=1.1, decay=0.5), i * 0.06, 0.6) for i, n in enumerate(("D4", "A4", "D5", "F#5", "A5"))],
                           (bell(hz(m("D6")), 1.4, 0.8), 0.3, 0.35), (choir(hz(m("D4")), 1.0, "a", 0.2, 0.8), 0.1, 0.3)), 1.2, 0.35)
    S["doors"] = tail(layer(1.4, (band(noise(int(1.0 * SR)), 80, 900) * np.sin(np.pi * np.linspace(0, 1, int(1.0 * SR))), 0, 0.8),
                            (thump(90, 40, 0.5, 5), 0.85, 0.7), (bell(hz(m("A5")), 1.0, 1.0), 0.9, 0.35)), 1.0, 0.35)
    S["boss_death"] = tail(layer(3.2, (thump(90, 30, 1.5, 2.5), 0, 1.0), (cymbal(2.5, 1.2), 0, 0.5),
                                 (brass(hz(m("D4")), 1.6, bright=1.2), 0.5, 0.45), (brass(hz(m("A4")), 1.6, bright=1.2), 0.5, 0.4),
                                 (brass(hz(m("F#4")), 1.6, bright=1.2), 0.5, 0.35), (brass(hz(m("D5")), 1.6, bright=1.2), 0.5, 0.35),
                                 (choir(hz(m("D4")), 2.0, "a", 0.3, 1.0), 0.5, 0.35)), 1.5, 0.35)
    S["death"] = tail(layer(3.0, (thump(80, 30, 1.2, 3), 0, 1.0),
                            (choir(hz(m("D4")), 2.2, "o", 0.2, 1.0), 0.15, 0.4), (choir(hz(m("F4")), 1.2, "o", 0.2, 1.0), 0.15, 0.3),
                            (choir(hz(m("Eb4")), 1.2, "o", 0.2, 1.0), 1.1, 0.3), (bell(hz(m("D3")), 2.5, 0.5), 0.2, 0.4)), 1.6, 0.4)
    S["victory"] = S["boss_death"]
    # boons / UI
    S["boon_appear"] = tail(layer(1.6, *[(bell(hz(m(n)), 1.0, 1.6), i * 0.08, 0.5) for i, n in enumerate(("D6", "E6", "F#6", "A6", "B6", "D7"))],
                                  (sweep_noise(1.4, 1500, 5000, 0.8), 0, 0.15)), 1.0, 0.4)
    S["card_in"] = sweep_noise(0.2, 2500, 900, 0.8) * 0.6
    S["boon_pick"] = tail(layer(1.6, (thump(110, 45, 0.6, 6), 0, 0.8), *[(bell(hz(m(n)), 1.2, 1.4), 0.02, 0.4) for n in ("D6", "F#6", "A6", "D7")],
                                (choir(hz(m("D5")), 0.8, "a", 0.05, 0.8), 0.0, 0.3)), 1.0, 0.4)
    S["tick"] = layer(0.03, (band(noise(int(0.03 * SR)), 2000, 8000) * np.exp(-times(int(0.03 * SR)) * 180), 0, 0.6), (glide(0.03, 2600, 2600, 120), 0, 0.3))
    S["tap"] = layer(0.06, (band(noise(int(0.04 * SR)), 1200, 6000) * np.exp(-times(int(0.04 * SR)) * 120), 0, 0.5), (glide(0.05, 900, 700, 60), 0, 0.5))
    S["open"] = sweep_noise(0.22, 700, 2600, 0.8) * 0.6
    S["select"] = tail(layer(0.3, (bell(hz(m("A6")), 0.25, 3.0), 0, 0.6), (bell(hz(m("E7")), 0.25, 3.5), 0.05, 0.4)), 0.3, 0.2)
    S["start"] = tail(layer(1.5, (taiko(52, 1.2), 0, 0.8), *[(lyre(hz(m(n)), 0.8, bright=1.2), 0.05 + i * 0.05, 0.5) for i, n in enumerate(("D4", "A4", "D5", "F#5"))],
                            (cymbal(1.2, 2.0), 0, 0.25)), 1.0, 0.3)

    levels = {"step": 0.5, "tick": 0.5, "tap": 0.7, "xp": 0.6, "fuse": 0.6, "card_in": 0.6, "spawn": 0.7}
    for name, sig in S.items():
        write_sfx(name, sig, levels.get(name, 0.9))

    # seamless 2 s hum for the boon orb (partials on 0.5 Hz multiples)
    n = 2 * SR
    t = times(n)
    hum = (np.sin(2 * math.pi * 220 * t) * 0.5 + np.sin(2 * math.pi * 330 * t) * 0.3 + np.sin(2 * math.pi * 440.5 * t) * 0.15) * (0.75 + 0.25 * np.sin(2 * math.pi * 1.0 * t))
    write_sfx("orb_hum", hum, 0.5, loop=True)
    print("sfx", len(S) + 1)


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "music"):
        for name, fn in TRACKS.items():
            fn()
    elif what in TRACKS:
        TRACKS[what]()
    if what in ("all", "sfx"):
        make_sfx()


if __name__ == "__main__":
    main()
