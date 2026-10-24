"""Small offline synthesizer used by compose.py: instruments, percussion,
a circular (loop-safe) mixer with reverb send, and helpers.

All instruments return mono float64 numpy arrays at SR.
"""

import math

import numpy as np

SR = 44100
_rng = np.random.default_rng(11)
_cache = {}

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def m(name):
    """'D4', 'Eb3', 'F#5' -> MIDI number."""
    n = NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        n += 1 if name[i] == "#" else -1
        i += 1
    return n + 12 * (int(name[i:]) + 1)


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def times(n):
    return np.arange(n) / SR


def env(n, attack=0.005, release=0.05, hold=None):
    """Linear attack, flat, cosine release over the last `release` seconds."""
    e = np.ones(n)
    a = max(1, int(attack * SR))
    e[:a] = np.linspace(0.0, 1.0, a) if a < n else np.linspace(0.0, 1.0, n)[:a]
    r = min(n, max(1, int(release * SR)))
    e[n - r:] *= 0.5 + 0.5 * np.cos(np.linspace(0, math.pi, r))
    return e


def noise(n):
    return _rng.uniform(-1.0, 1.0, n)


def band(x, lo=0.0, hi=None, slope=1.5):
    """Smooth FFT band-pass (lo/hi in Hz)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    if hi:
        g *= 1.0 / (1.0 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * g, len(x))


def cached(fn):
    def wrap(*args, **kw):
        key = (fn.__name__, args, tuple(sorted(kw.items())))
        if key not in _cache:
            _cache[key] = fn(*args, **kw)
        return _cache[key]
    wrap.__name__ = fn.__name__
    return wrap


# ---------------------------------------------------------------- instruments

@cached
def lyre(f, dur, bright=1.0, decay=1.0):
    """Plucked lyre / harp: harmonic partials with pluck-position colour,
    higher partials dying faster."""
    ring = max(dur, 0.25) + 1.4 / decay
    n = int(ring * SR)
    t = times(n)
    out = np.zeros(n)
    for k in range(1, 18):
        fk = f * k * (1.0 + 0.00035 * k * k)
        if fk > 9000:
            break
        amp = (1.0 / k ** 1.2) * (math.sin(math.pi * k * 0.21) ** 2 + 0.08)
        dec = decay * (1.2 + 0.8 * k ** 1.3 * math.sqrt(f / 220.0) / bright)
        out += amp * np.exp(-t * dec) * np.sin(2 * math.pi * fk * t + _rng.uniform(0, 6.283))
    click = band(noise(n) * np.exp(-t * 400), 1500, 7000) * 0.15
    out = out + click
    return out * env(n, 0.002, 0.08) / 1.4


@cached
def bass(f, dur, drive=1.8, bright=0.5):
    n = int((dur + 0.08) * SR)
    t = times(n)
    s = np.sin(2 * math.pi * f * t) + 0.45 * np.sin(4 * math.pi * f * t + 0.3) + 0.2 * bright * np.sin(6 * math.pi * f * t)
    pluck = 1.0 + 0.6 * np.exp(-t * 18)
    s = np.tanh(drive * s * pluck) / math.tanh(drive * 1.6)
    return s * env(n, 0.004, 0.07) * (0.8 + 0.2 * np.exp(-t * 3))


def _ensemble(f, n, voices, spread, vib, partial_gain, max_hz=7000):
    t = times(n)
    out = np.zeros(n)
    for v in range(voices):
        det = (v - (voices - 1) / 2.0) * spread
        rate = 4.6 + 0.37 * v
        wobble = 1.0 + det + vib * np.sin(2 * math.pi * rate * t + v * 1.7)
        phase = 2 * math.pi * f * np.cumsum(wobble) / SR + _rng.uniform(0, 6.283)
        for k in range(1, 40):
            fk = f * k
            if fk > max_hz:
                break
            g = partial_gain(k, fk)
            if g < 1e-4:
                continue
            out += g * np.sin(k * phase)
    return out / voices


@cached
def strings(f, dur, attack=0.35, release=0.9, bright=0.6, voices=5):
    n = int((dur + release) * SR)
    out = _ensemble(f, n, voices, 0.0035, 0.0025, lambda k, fk: (1.0 / k) * math.exp(-fk / (900 + 3000 * bright)))
    e = np.minimum(times(n) / attack, 1.0)
    e *= env(n, 0.001, release)
    return out * e * 0.9


FORMANTS = {
    "a": [(800, 80, 1.0), (1150, 90, 0.5), (2900, 120, 0.25), (3900, 130, 0.2), (4950, 140, 0.1)],
    "o": [(450, 70, 1.0), (800, 80, 0.6), (2830, 100, 0.1), (3800, 120, 0.08), (4950, 120, 0.05)],
    "u": [(325, 50, 1.0), (700, 60, 0.25), (2530, 170, 0.08), (3500, 180, 0.05), (4950, 200, 0.03)],
}


@cached
def choir(f, dur, vowel="a", attack=0.5, release=1.2, voices=6):
    n = int((dur + release) * SR)
    fm = FORMANTS[vowel]

    def gain(k, fk):
        g = 0.0
        for F, bw, a in fm:
            g += a / (1.0 + ((fk - F) / (bw * 2.2)) ** 2)
        return g / k ** 0.3

    out = _ensemble(f, n, voices, 0.005, 0.004, gain, max_hz=5500)
    breath = band(noise(n), 600, 3000) * 0.05
    e = np.minimum(times(n) / attack, 1.0) ** 1.5 * env(n, 0.001, release)
    return (out + breath) * e * 0.7


@cached
def aulos(f, dur, nasal=0.7, attack=0.04, release=0.12, vibrato=0.006):
    """Double-reed lead (Greek aulos): odd-heavy partials, breath, delayed vibrato."""
    n = int((dur + release) * SR)
    t = times(n)
    vib = 1.0 + vibrato * np.sin(2 * math.pi * 5.4 * t) * np.minimum(t / 0.35, 1.0)
    phase = 2 * math.pi * f * np.cumsum(vib) / SR
    out = np.zeros(n)
    for k in range(1, 14):
        if f * k > 8000:
            break
        g = (1.0 if k % 2 else nasal * 0.6) / k ** 0.95
        out += g * np.sin(k * phase)
    out = np.tanh(out * 1.3) * 0.8
    breath = band(noise(n), f * 1.5, f * 6) * 0.08
    e = np.minimum(t / attack, 1.0) * env(n, 0.001, release)
    return band(out + breath, 0, 6500) * e * 0.55


@cached
def flute(f, dur, attack=0.06, release=0.15):
    n = int((dur + release) * SR)
    t = times(n)
    vib = 1.0 + 0.005 * np.sin(2 * math.pi * 5.0 * t) * np.minimum(t / 0.3, 1.0)
    phase = 2 * math.pi * f * np.cumsum(vib) / SR
    out = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = band(noise(n), f * 0.8, f * 4) * 0.12 * (0.6 + 0.4 * np.exp(-t * 6))
    e = np.minimum(t / attack, 1.0) * env(n, 0.001, release)
    return (out + breath) * e * 0.55


@cached
def brass(f, dur, attack=0.06, release=0.18, bright=1.0):
    """Horn section: brightness opens with the attack."""
    n = int((dur + release) * SR)
    t = times(n)
    opening = 1.0 - np.exp(-t / (attack * 1.8))
    vib = 1.0 + 0.003 * np.sin(2 * math.pi * 5.2 * t) * np.minimum(t / 0.4, 1.0)
    out = np.zeros(n)
    for v, det in enumerate((-0.004, 0.0, 0.0045)):
        phase = 2 * math.pi * f * (1 + det) * np.cumsum(vib) / SR + v
        for k in range(1, 30):
            if f * k > 7000:
                break
            cutoff = 1.5 + 9.0 * bright * opening
            out += (1.0 / k) * np.exp(-k / cutoff) * np.sin(k * phase)
    e = np.minimum(t / attack, 1.0) * env(n, 0.001, release)
    return np.tanh(out * 0.9) * e * 0.5


BELL = [(0.56, 1.0, 0.9), (0.92, 0.7, 1.2), (1.19, 0.6, 1.6), (1.71, 0.5, 2.2), (2.0, 0.6, 2.0),
        (2.74, 0.35, 3.0), (3.0, 0.3, 3.4), (3.76, 0.2, 4.2), (4.07, 0.18, 4.6)]


@cached
def bell(f, dur=2.5, decay=1.0):
    n = int(dur * SR)
    t = times(n)
    out = np.zeros(n)
    for r, a, d in BELL:
        if f * r < 12000:
            out += a * np.exp(-t * d * decay) * np.sin(2 * math.pi * f * r * t + _rng.uniform(0, 6.283))
    return out * env(n, 0.001, 0.2) * 0.4


@cached
def pad(f, dur, attack=1.2, release=2.0):
    """Soft sine/triangle bed."""
    n = int((dur + release) * SR)
    t = times(n)
    out = np.zeros(n)
    for det in (-0.003, 0.0, 0.003):
        p = 2 * math.pi * f * (1 + det) * t
        out += np.sin(p) + 0.25 * np.sin(2 * p) + 0.08 * np.sin(3 * p)
    e = np.minimum(t / attack, 1.0) ** 2 * env(n, 0.001, release)
    return out * e * 0.3


# ---------------------------------------------------------------- percussion

@cached
def taiko(pitch=58.0, dur=1.4, vel=1.0):
    n = int(dur * SR)
    t = times(n)
    f = pitch * (1.0 + 1.1 * np.exp(-t * 28))
    body = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 4.5)
    body += 0.35 * np.sin(2 * math.pi * np.cumsum(f * 1.52) / SR) * np.exp(-t * 9)
    skin = band(noise(n), 60, 900) * np.exp(-t * 26) * 0.9
    slap = band(noise(n), 900, 5000) * np.exp(-t * 60) * 0.35
    return np.tanh((body + skin + slap) * 1.6) * 0.75 * vel


@cached
def doum(dur=0.6):
    n = int(dur * SR)
    t = times(n)
    f = 105 * (1 + 0.4 * np.exp(-t * 40))
    s = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    s += band(noise(n), 100, 1200) * np.exp(-t * 45) * 0.4
    return s * 0.7


@cached
def tek(dur=0.15, tone=1.0):
    n = int(dur * SR)
    t = times(n)
    s = band(noise(n), 1800 * tone, 7500) * np.exp(-t * 70)
    s += 0.35 * np.sin(2 * math.pi * 880 * tone * t) * np.exp(-t * 90)
    return s * 0.75


@cached
def shaker(dur=0.09, bright=1.0):
    n = int(dur * SR)
    t = times(n)
    e = np.minimum(t / 0.01, 1.0) * np.exp(-t * 45)
    return band(noise(n), 4500 * bright, 14000) * e * 0.5


@cached
def snare(dur=0.35, tone=190.0):
    n = int(dur * SR)
    t = times(n)
    s = 0.6 * np.sin(2 * math.pi * tone * t) * np.exp(-t * 22)
    s += band(noise(n), 1200, 9000) * np.exp(-t * 15) * 0.8
    return np.tanh(s * 1.4) * 0.6


@cached
def cymbal(dur=3.0, decay=1.4):
    n = int(dur * SR)
    t = times(n)
    s = band(noise(n), 3500, 15000) * np.exp(-t * decay)
    for r in (3170, 4410, 5890, 7320):
        s += 0.05 * np.sin(2 * math.pi * r * t + _rng.uniform(0, 6.283)) * np.exp(-t * decay * 1.3)
    return s * env(n, 0.002, 0.3) * 0.35


@cached
def swell(dur=1.5):
    """Reversed cymbal leading into a downbeat."""
    return cymbal(dur + 0.2, 2.2)[: int(dur * SR)][::-1].copy() * 0.8


@cached
def anvil(f=1150.0, dur=1.2):
    n = int(dur * SR)
    t = times(n)
    s = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 5), (2.31, 0.6, 7), (3.85, 0.4, 9), (5.12, 0.3, 12)):
        s += a * np.sin(2 * math.pi * f * r * t) * np.exp(-t * d)
    s += band(noise(n), 2000, 9000) * np.exp(-t * 80) * 0.6
    return s * 0.3


# ---------------------------------------------------------------- mixing

def pan_gains(p):
    a = (p + 1.0) * math.pi / 4.0
    return math.cos(a), math.sin(a)


class Mix:
    """Stereo loop buffer: everything that runs past the end wraps to the
    start, and the reverb is a circular convolution, so loops are seamless."""

    def __init__(self, seconds):
        self.n = int(round(seconds * SR))
        self.dry = np.zeros((self.n, 2))
        self.send = np.zeros((self.n, 2))

    def add(self, sig, start, gain=1.0, pan=0.0, rev=0.2):
        if sig is None or len(sig) == 0:
            return
        gl, gr = pan_gains(pan)
        i0 = int(round(start * SR)) % self.n
        pos = 0
        while pos < len(sig):
            chunk = min(len(sig) - pos, self.n - i0)
            seg = sig[pos:pos + chunk] * gain
            self.dry[i0:i0 + chunk, 0] += seg * gl
            self.dry[i0:i0 + chunk, 1] += seg * gr
            if rev > 0:
                self.send[i0:i0 + chunk, 0] += seg * gl * rev
                self.send[i0:i0 + chunk, 1] += seg * gr * rev
            pos += chunk
            i0 = 0

    def render(self, rt60=2.4, damp=5000.0, predelay=0.02, master=0.9):
        ir = reverb_ir(rt60, damp, predelay, self.n)
        wet = np.zeros_like(self.send)
        for c in range(2):
            wet[:, c] = np.fft.irfft(np.fft.rfft(self.send[:, c]) * np.fft.rfft(ir[:, c]), self.n)
        out = self.dry + wet
        return master_bus(out, master)


def reverb_ir(rt60, damp, predelay, n_max):
    length = min(int(rt60 * 1.2 * SR), n_max)
    t = times(length)
    ir = np.zeros((length, 2))
    decay = np.exp(-6.9 * t / rt60)
    for c in range(2):
        tail = noise(length) * decay
        tail = band(tail, 120, damp)
        pd = int(predelay * SR)
        tail[:pd] = 0.0
        for k in range(10):
            d = int((0.008 + 0.006 * k + 0.003 * c) * SR) + pd
            if d < length:
                tail[d] += (0.6 - 0.05 * k) * (1 if (k + c) % 2 else -1)
        ir[:, c] = tail
    ir /= np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True)) * 1.6
    full = np.zeros((n_max, 2))
    full[:length] = ir
    return full


def tilt_eq(x):
    """Voice the mix for phone speakers: high-pass the sub, trim the low end,
    lift presence and air. Done on the whole loop in the frequency domain, so
    it stays seamless."""
    X = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    fs = np.maximum(f, 1e-3)
    g = 1.0 / np.sqrt(1.0 + (45.0 / fs) ** 4)
    g *= 10 ** (-6.0 / 20 / (1.0 + (fs / 160.0) ** 2))
    g *= 10 ** (4.0 / 20 * np.exp(-0.5 * (np.log2(fs / 3200.0) / 1.1) ** 2))
    g *= 10 ** (2.5 / 20 / (1.0 + (9000.0 / fs) ** 2))
    return np.fft.irfft(X * g[:, None], len(x), axis=0)


def master_bus(x, level=0.9):
    """Gentle glue: phone EQ, slow RMS compression, soft clip, normalise."""
    x = tilt_eq(x)
    power = np.mean(x ** 2, axis=1)
    w = 4410
    c = np.cumsum(np.concatenate(([0.0], power, power[:w])))
    rms = np.sqrt((c[w:w + len(power)] - c[:len(power)]) / w + 1e-9)
    thr = np.percentile(rms, 70)
    gain = np.where(rms > thr, (thr / rms) ** 0.35, 1.0)
    x = x * gain[:, None]
    x = np.tanh(x / np.max(np.abs(x)) * 1.25)
    return x / np.max(np.abs(x)) * level


def fade(sig, inn=0.003, out=0.02):
    n = len(sig)
    a = min(n, int(inn * SR))
    b = min(n, int(out * SR))
    sig = sig.copy()
    if a:
        sig[:a] *= np.linspace(0, 1, a)
    if b:
        sig[n - b:] *= np.linspace(1, 0, b)
    return sig
