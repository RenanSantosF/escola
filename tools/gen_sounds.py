#!/usr/bin/env python3
"""Sons e músicas do Turma Viva: Recreio — síntese própria (sem bancos de terceiros).

Efeitos: camadas (ataque + corpo + brilho), varreduras de pitch, filtros,
reverb curto e compressão, a 44,1 kHz. Músicas: bateria, baixo, acordes
"supersaw" com sidechain, lead e arpejos, em estéreo, salvas em OGG (leve).

Rode depois do gen_audio.py (que faz os ambientes):  python3 tools/gen_sounds.py
Precisa de numpy, scipy e ffmpeg.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ básico

def tt(d):
    return np.arange(int(SR * d)) / SR


def silence(d):
    return np.zeros(int(SR * d))


def noise(d):
    return rng.standard_normal(int(SR * d))


def expdec(d, tau):
    return np.exp(-tt(d) / tau)


def adsr(n, a=0.005, d=0.1, s=0.6, r=0.1):
    e = np.ones(n) * s
    na, nd, nr = int(SR * a), int(SR * d), int(SR * r)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    nd = min(nd, max(n - na, 0))
    e[na:na + nd] = np.linspace(1, s, nd)
    nr = min(nr, n)
    if nr > 0:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def sweep(f0, f1, d, kind="exp", wave_="sine"):
    n = int(SR * d)
    if kind == "exp":
        f = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    else:
        f = np.linspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "sine":
        return np.sin(ph)
    if wave_ == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if wave_ == "square":
        return np.tanh(np.sin(ph) * 4)
    return 2 * ((ph / (2 * np.pi)) % 1.0) - 1  # saw


def osc(f, d, wave_="sine", phase=0.0):
    x = tt(d)
    ph = 2 * np.pi * f * x + phase
    if wave_ == "sine":
        return np.sin(ph)
    if wave_ == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if wave_ == "square":
        return np.sign(np.sin(ph)) * 0.8
    if wave_ == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    raise ValueError(wave_)


def fm(fc, ratio, index, d, idx_tau=0.15):
    x = tt(d)
    mod = np.sin(2 * np.pi * fc * ratio * x) * index * np.exp(-x / idx_tau)
    return np.sin(2 * np.pi * fc * x + mod)


def _sos(kind, f, order=2):
    f = np.atleast_1d(f)
    f = np.clip(f, 20, SR / 2 - 100)
    return signal.butter(order, f if len(f) > 1 else f[0], btype=kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("lowpass", f, order), x)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("highpass", f, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, delay):
    return np.concatenate([silence(delay), x])


def reverb(x, size=1.0, wet=0.18, damp=6000):
    n = int(SR * size)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * size / 5.5))
    ir = lp(ir, damp)
    ir[:int(SR * 0.012)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    w = signal.fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(w) - len(x))])
    return dry * (1 - wet * 0.5) + w * wet


def soft(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def fade_out(x, d=0.02):
    n = min(int(SR * d), len(x))
    x = x.copy()
    x[len(x) - n:] *= np.linspace(1, 0, n)
    return x


def trim(x, thresh=1e-4):
    idx = np.where(np.abs(x) > thresh * np.max(np.abs(x)))[0]
    return x[: idx[-1] + 1] if len(idx) else x


def write(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    x = fade_out(trim(x), 0.01)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("ok", name, f"{len(x) / SR:.2f}s")


def write_ogg(name, st, peak=0.9, q=5):
    """st: array (n, 2) estéreo. Remove o .wav antigo de mesmo nome."""
    st = np.asarray(st, dtype=np.float64)
    m = np.max(np.abs(st)) or 1.0
    st = st / m * peak
    data = (np.clip(st, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "x.wav")
        with wave.open(tmp, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), dst], check=True)
    for ext in (".wav", ".wav.import"):
        old = os.path.join(OUT, name + ext)
        if os.path.exists(old):
            os.remove(old)
    print("ok", name + ".ogg", f"{len(st) / SR:.1f}s", f"{os.path.getsize(dst) // 1024} KB")


NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(n):
    """'A4' -> 440; número = semitons a partir do A4."""
    if isinstance(n, (int, float)):
        return 440.0 * 2 ** (n / 12)
    name, octv = n[:-1], int(n[-1])
    return 440.0 * 2 ** ((NOTE[name] - 9 + (octv - 4) * 12) / 12)


# ------------------------------------------------------------------ efeitos (UI)

def ui_click():
    body = sweep(700, 1300, 0.045) * expdec(0.045, 0.012)
    tick = hp(noise(0.006), 3000) * expdec(0.006, 0.0015) * 0.4
    return mix(body, tick)


def ui_confirm():
    a = fm(hz("E6"), 3.5, 1.2, 0.18, 0.05) * expdec(0.18, 0.05)
    b = fm(hz("B6"), 3.5, 1.2, 0.45, 0.07) * expdec(0.45, 0.12)
    sp = hp(noise(0.3), 6000) * expdec(0.3, 0.06) * 0.05
    return reverb(mix(a, at(b, 0.07), at(sp, 0.07)), 0.6, 0.18)


def ui_back():
    a = fm(hz("G5"), 2, 0.8, 0.12, 0.05) * expdec(0.12, 0.04)
    b = fm(hz("D5"), 2, 0.8, 0.25, 0.05) * expdec(0.25, 0.07)
    return reverb(mix(a, at(b, 0.06)), 0.4, 0.12)


def ui_error():
    a = lp(osc(160, 0.12, "square"), 1200) * adsr(int(SR * 0.12), 0.003, 0.05, 0.6, 0.04)
    return mix(a, at(a * 0.9, 0.14))


def coin():
    a = osc(hz("B5"), 0.07, "square") * 0.5
    b = osc(hz("E6"), 0.42, "square") * expdec(0.42, 0.12) * 0.5
    x = lp(np.concatenate([a, b]), 7000)
    sh = fm(hz("E7"), 2.01, 2, 0.4, 0.1) * expdec(0.4, 0.08) * 0.25
    return reverb(mix(x, at(sh, 0.07)), 0.5, 0.15)


def sparkle(n=6, base="C6", step=4, gap=0.045, d=0.35):
    out = silence(0.01)
    scale = [0, 4, 7, 12, 16, 19, 24, 28]
    for i in range(n):
        f = hz(base) * 2 ** (scale[i % len(scale)] / 12)
        nt = fm(f, 3.0, 1.5, d, 0.05) * expdec(d, 0.08) * (0.6 + 0.4 * i / n)
        out = mix(out, at(nt, i * gap))
    return reverb(out, 0.9, 0.25)


def levelup():
    arp = sparkle(8, "C5", gap=0.06, d=0.4)
    chord = mix(*[supersaw(hz(n), 1.2, voices=5) * 0.18 for n in ["C5", "E5", "G5", "C6"]])
    chord = lp(chord, 5000) * adsr(len(chord), 0.01, 0.3, 0.5, 0.6)
    boom = sweep(120, 45, 0.5) * expdec(0.5, 0.15) * 0.6
    return reverb(mix(arp, at(chord, 0.45), at(boom, 0.45)), 1.4, 0.25)


def countdown_tick():
    b = osc(hz("A5"), 0.16, "tri") * expdec(0.16, 0.05)
    c = sweep(1600, 900, 0.02) * expdec(0.02, 0.006) * 0.5
    th = sweep(140, 60, 0.1) * expdec(0.1, 0.03) * 0.6
    return reverb(mix(b, c, th), 0.4, 0.12)


def countdown_go():
    ch = mix(*[osc(hz(n), 0.7, "saw") * 0.25 for n in ["A5", "C#6", "E6"]])
    ch = lp(ch, 6000) * adsr(len(ch), 0.005, 0.2, 0.5, 0.35)
    up = bp(noise(0.5), 800, 6000) * np.linspace(0, 1, int(SR * 0.5)) ** 2 * 0.25
    kick = sweep(160, 45, 0.35) * expdec(0.35, 0.1)
    return reverb(mix(at(up, 0.0), at(ch, 0.25), at(kick, 0.25)), 1.0, 0.22)[int(SR * 0.2):]


def timer_warn():
    a = osc(hz("E6"), 0.06, "tri") * expdec(0.06, 0.02)
    b = osc(hz("B5"), 0.06, "tri") * expdec(0.06, 0.02)
    return mix(a, at(b, 0.18))


# ------------------------------------------------------------------ efeitos (jogo)

def kick_ball():
    thump = sweep(180, 60, 0.12) * expdec(0.12, 0.035)
    slap = bp(noise(0.05), 900, 4000) * expdec(0.05, 0.008) * 0.9
    snap = hp(noise(0.01), 5000) * expdec(0.01, 0.002) * 0.6
    return soft(mix(thump, slap, snap), 1.8)


def ball_bounce():
    b = sweep(260, 120, 0.12) * expdec(0.12, 0.03)
    s = bp(noise(0.03), 600, 2500) * expdec(0.03, 0.006) * 0.5
    return mix(b, s)


def whoosh(d=0.45, lo=300, hi=3500):
    n = int(SR * d)
    x = noise(d)
    # duas faixas de filtro que "passam" (grave -> agudo -> grave)
    env = np.sin(np.pi * np.arange(n) / n) ** 2
    low = bp(x, lo, (lo + hi) / 2) * env
    high = bp(x, (lo + hi) / 2, hi) * np.sin(np.pi * np.arange(n) / n) ** 6
    return (low + high * 0.8) * 0.9


def throw():
    return whoosh(0.22, 600, 5000)


def hit():
    slap = bp(noise(0.06), 1200, 6000) * expdec(0.06, 0.01)
    body = sweep(220, 70, 0.18) * expdec(0.18, 0.05) * 0.9
    pow_ = fm(hz("C6"), 1.5, 3, 0.3, 0.05) * expdec(0.3, 0.07) * 0.35
    return reverb(soft(mix(slap, body, at(pow_, 0.02)), 2.0), 0.4, 0.12)


def catch():
    th = sweep(200, 90, 0.1) * expdec(0.1, 0.03)
    dg = fm(hz("G6"), 3, 1, 0.3, 0.05) * expdec(0.3, 0.08) * 0.3
    return mix(th, at(dg, 0.02))


def jump():
    b = sweep(260, 760, 0.18, "exp", "tri") * adsr(int(SR * 0.18), 0.005, 0.05, 0.7, 0.08)
    vib = 1 + 0.15 * np.sin(2 * np.pi * 30 * tt(0.18))
    return b * vib * 0.8


def boing():
    d = 0.5
    x = tt(d)
    f = 220 * (1 + 1.6 * np.exp(-x / 0.05)) * (1 + 0.08 * np.sin(2 * np.pi * 18 * x) * np.exp(-x / 0.25))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * expdec(d, 0.16) + np.sin(2 * ph) * expdec(d, 0.08) * 0.3


def land():
    return mix(sweep(150, 50, 0.12) * expdec(0.12, 0.03), lp(noise(0.06), 800) * expdec(0.06, 0.015) * 0.5)


def trip():
    d = 0.7
    x = tt(d)
    f = 900 * (0.35 / 0.9) ** (x / d)
    f = f * (1 + 0.04 * np.sin(2 * np.pi * 7 * x))
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = (np.sin(ph) + 0.15 * hp(noise(d), 2000) * 0.2) * adsr(len(x), 0.02, 0.1, 0.8, 0.2)
    return mix(w * 0.8, at(land(), d - 0.05))


def point():
    a = fm(hz("E6"), 2.0, 1.8, 0.35, 0.04) * expdec(0.35, 0.09)
    b = osc(hz("E7"), 0.2, "sine") * expdec(0.2, 0.04) * 0.25
    return reverb(mix(a, b), 0.5, 0.15)


def combo():
    return sparkle(4, "E6", gap=0.035, d=0.28)


def crowd_cheer(d=2.6, swell=0.25):
    n = int(SR * d)
    x = np.zeros(n)
    for k in range(18):
        v = bp(noise(d), 500 + rng.uniform(0, 600), 2500 + rng.uniform(0, 1500), 1)
        x += v * (1 + 0.5 * np.sin(2 * np.pi * rng.uniform(3, 8) * tt(d) + rng.uniform(0, 6)))
    e = np.minimum(tt(d) / swell, 1.0) * np.exp(-np.maximum(tt(d) - d * 0.45, 0) / (d * 0.25))
    return x * e / 18


def air_horn(d=0.9):
    tones = [hz("A#4"), hz("D5"), hz("F5")]
    x = mix(*[lp(osc(f, d, "saw"), 3500) * 0.3 for f in tones])
    x = soft(x * 2.5, 1.5) * adsr(len(x), 0.02, 0.1, 0.9, 0.12)
    return x


def goal():
    return reverb(mix(air_horn(0.8) * 0.7, at(air_horn(0.6) * 0.6, 0.9), crowd_cheer(3.2) * 1.4), 1.2, 0.2)


def win():
    mel = ["C5", "E5", "G5", "C6", "E6", "G6"]
    out = silence(0.01)
    for i, n in enumerate(mel):
        nt = (fm(hz(n), 1.0, 1.2, 0.3, 0.06) * 0.6 + osc(hz(n), 0.3, "square") * 0.12) * expdec(0.3, 0.1)
        out = mix(out, at(nt, i * 0.085))
    chord = mix(*[supersaw(hz(n), 1.4, voices=5) * 0.16 for n in ["C5", "E5", "G5", "C6"]])
    chord = lp(chord, 6000) * adsr(len(chord), 0.01, 0.4, 0.55, 0.7)
    drums = mix(kick(0.3), at(snare(0.3) * 0.7, 0.0), at(kick(0.3), 0.55))
    sp = sparkle(6, "G6", gap=0.04, d=0.3) * 0.5
    return reverb(mix(out, at(chord, 0.52), at(drums, 0.52), at(sp, 0.6)), 1.5, 0.22)


def lose():
    notes = ["G4", "F#4", "F4", "E4"]
    out = silence(0.01)
    for i, n in enumerate(notes):
        d = 0.32 if i < 3 else 0.9
        x = tt(d)
        f = hz(n) * (1 + (0.012 * np.sin(2 * np.pi * 6 * x) if i == 3 else 0))
        ph = 2 * np.pi * np.cumsum(np.full(len(x), 1.0) * f) / SR
        tone = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
        wah = lp(tone, 900 + 1500 * np.sin(np.pi * np.minimum(x / d, 1)) ** 2 if False else 1800)
        nt = wah * adsr(len(x), 0.02, 0.05, 0.85, 0.12 if i < 3 else 0.5)
        out = mix(out, at(nt, i * 0.34))
    return reverb(out * 0.7, 0.8, 0.18)


def whistle():
    d = 0.55
    x = tt(d)
    f = 2900 * (1 + 0.035 * np.sign(np.sin(2 * np.pi * 26 * x)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.2 * np.sin(2 * ph)
    air = bp(noise(d), 2400, 4500) * 0.25
    e = adsr(len(x), 0.01, 0.05, 0.9, 0.08)
    return mix((tone + air) * e, at((tone[: int(SR * 0.2)] + air[: int(SR * 0.2)]) * adsr(int(SR * 0.2), 0.01, 0.05, 0.9, 0.05), d + 0.07))


def applause(d=2.4):
    n = int(SR * d)
    x = np.zeros(n)
    clap = bp(noise(0.03), 900, 5000) * expdec(0.03, 0.006)
    for _ in range(int(d * 90)):
        s = int(rng.uniform(0, n - len(clap)))
        x[s:s + len(clap)] += clap * rng.uniform(0.3, 1.0)
    return x * np.minimum(tt(d) / 0.1, 1) * np.exp(-np.maximum(tt(d) - d * 0.55, 0) / (d * 0.18))


def celebrate():
    pop = mix(hp(noise(0.05), 1500) * expdec(0.05, 0.01), sweep(400, 120, 0.06) * expdec(0.06, 0.02))
    return mix(pop, at(sparkle(7, "C6", gap=0.035, d=0.3) * 0.7, 0.04), at(crowd_cheer(1.4, 0.1) * 0.5, 0.05))


def pickup():
    return reverb(mix(sweep(500, 1400, 0.09, "exp", "sine") * expdec(0.09, 0.04), fm(hz("A6"), 2, 1, 0.15, 0.03) * expdec(0.15, 0.04) * 0.3), 0.3, 0.1)


def bonk():
    wood = fm(520, 1.48, 2.5, 0.25, 0.02) * expdec(0.25, 0.04)
    drop = sweep(500, 180, 0.2, "exp", "tri") * expdec(0.2, 0.07) * 0.6
    return mix(wood, drop)


def drink():
    out = silence(0.01)
    for i in range(3):
        g = sweep(300 + i * 40, 650 + i * 30, 0.08) * np.sin(np.pi * np.arange(int(SR * 0.08)) / int(SR * 0.08))
        out = mix(out, at(lp(g, 1500), i * 0.17))
    return out


def school_bell():
    d = 2.6
    x = tt(d)
    ring = 0
    for f, a in [(1180, 1), (2600, 0.5), (3900, 0.3), (5100, 0.15)]:
        ring = ring + np.sin(2 * np.pi * f * x) * a
    clap = (np.sin(2 * np.pi * 22 * x) > 0).astype(float) * 0.6 + 0.4
    e = np.minimum(x / 0.02, 1) * np.where(x < 2.1, 1, np.exp(-(x - 2.1) / 0.15))
    return reverb(ring * clap * e, 1.2, 0.25)


def clack():
    return bp(noise(0.03), 1500, 5000) * expdec(0.03, 0.005) + sweep(900, 600, 0.03) * expdec(0.03, 0.008) * 0.4


def wind_loop(d=3.0):
    x = noise(d)
    y = lp(x, 900) * 0.8 + bp(x, 1500, 3500) * 0.2 * (1 + 0.5 * np.sin(2 * np.pi * 0.7 * tt(d)))
    # emenda sem clique
    n = int(SR * 0.3)
    y[:n] = y[:n] * np.linspace(0, 1, n) + y[-n:] * np.linspace(1, 0, n)
    return y[:-n]


def step(hard=True, i=0):
    if hard:
        th = sweep(130 + i * 12, 60, 0.07) * expdec(0.07, 0.015)
        tk = bp(noise(0.03), 1500, 5000) * expdec(0.03, 0.004) * 0.6
        return mix(th, tk)
    ru = bp(noise(0.09), 800, 4000) * expdec(0.09, 0.025)
    th = sweep(110, 50, 0.06) * expdec(0.06, 0.015) * 0.4
    return mix(ru, th)


# ------------------------------------------------------------------ instrumentos (música)

def supersaw(f, d, voices=7, detune=0.012):
    out = np.zeros(int(SR * d))
    for v in range(voices):
        k = (v - (voices - 1) / 2) / max((voices - 1) / 2, 1)
        out += osc(f * (1 + k * detune), d, "saw", phase=rng.uniform(0, 6.28))
    return out / voices


def kick(d=0.4):
    body = sweep(150, 42, d) * expdec(d, 0.13)
    click = hp(noise(0.008), 3000) * expdec(0.008, 0.002) * 0.5
    return soft(mix(body, click), 1.6)


def snare(d=0.25):
    body = sweep(240, 170, d) * expdec(d, 0.05) * 0.6
    nz = bp(noise(d), 1500, 9000) * expdec(d, 0.07)
    return mix(body, nz)


def clap(d=0.3):
    out = silence(d)
    for k, g in enumerate([0.0, 0.011, 0.022]):
        b = bp(noise(d), 900, 6000) * expdec(d, 0.012 if k < 2 else 0.09)
        out = mix(out, at(b, g))
    return out[: int(SR * d)]


def hat(d=0.05, open_=False):
    n = hp(noise(d if not open_ else 0.25), 7000)
    return n * expdec(len(n) / SR, 0.012 if not open_ else 0.08)


def bass_note(f, d):
    x = osc(f, d, "saw") * 0.6 + osc(f / 2, d, "sine") * 0.7
    e = adsr(len(x), 0.004, 0.08, 0.7, 0.04)
    # filtro que abre no ataque
    return lp(x, 900) * e + lp(x, 2400) * e * expdec(d, 0.04)[: len(x)] * 0.4


def pluck(f, d, bright=4500):
    x = mix(osc(f, d, "saw") * 0.5, osc(f * 1.005, d, "square") * 0.3)
    e = expdec(d, 0.18)
    return lp(x, bright) * e * 0.9 + lp(x, bright * 2) * expdec(d, 0.03) * 0.3


def bell(f, d):
    return fm(f, 3.5, 2.0, d, 0.12) * expdec(d, 0.35)


def rhodes(f, d):
    x = tt(d)
    tone = fm(f, 1.0, 1.4, d, 0.25) + 0.25 * np.sin(2 * np.pi * f * 2 * x)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * x)
    return tone * trem * adsr(len(x), 0.005, 0.4, 0.5, 0.25)


class Track:
    """Sequenciador simples: posições em batidas, saída estéreo."""

    def __init__(self, bpm, bars, beats=4):
        self.bpm = bpm
        self.spb = 60.0 / bpm
        self.n = int(SR * self.spb * beats * bars)
        self.L = np.zeros(self.n + SR * 3)
        self.R = np.zeros(self.n + SR * 3)
        self.duck = np.ones(self.n + SR * 3)

    def add(self, x, beat, gain=1.0, pan=0.0):
        s = int(beat * self.spb * SR)
        if s >= self.n:
            return
        e = min(s + len(x), len(self.L))
        seg = x[: e - s] * gain
        self.L[s:e] += seg * np.cos((pan + 1) * np.pi / 4) * 1.414
        self.R[s:e] += seg * np.sin((pan + 1) * np.pi / 4) * 1.414

    def sidechain(self, beat, depth=0.55, rel=0.22):
        s = int(beat * self.spb * SR)
        n = int(SR * rel)
        e = min(s + n, len(self.duck))
        curve = 1 - depth * np.exp(-np.arange(e - s) / (SR * rel / 4))
        self.duck[s:e] = np.minimum(self.duck[s:e], curve)

    def render(self, music_bus, drums_bus, loop=True):
        # music_bus: (L, R) que sofre sidechain; drums_bus: sem
        L = music_bus[0] * self.duck + drums_bus[0]
        R = music_bus[1] * self.duck + drums_bus[1]
        if loop:
            # cauda do fim volta para o começo (loop perfeito)
            tail = slice(self.n, len(L))
            L[: len(L) - self.n] += L[tail]
            R[: len(R) - self.n] += R[tail]
        L, R = L[: self.n], R[: self.n]
        st = np.stack([L, R], axis=1)
        st = np.tanh(st * 1.3) / np.tanh(1.3)  # "master" com cola
        return st


def chord_notes(root, kind="maj", octave=4):
    iv = {"maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10]}[kind]
    base = hz(root + str(octave))
    return [base * 2 ** (i / 12) for i in iv]


def stereo_verb(L, R, size=1.6, wet=0.22):
    return reverb(L, size, wet), reverb(R, size * 1.07, wet)


def song_pop(name, bpm, prog, melody_a, melody_b, energy=1.0, bars=24, lead="pluck", swing=0.0):
    """Pop/eletrônico infantil: intro 4, A 8, B 8, ponte 4 (volta para a intro)."""
    seq = Track(bpm, bars)
    drums = Track(bpm, bars)
    mus = Track(bpm, bars)
    total_beats = bars * 4
    for b in range(total_beats):
        bar = b // 4
        sec = "intro" if bar < 4 else ("A" if bar < 12 else ("B" if bar < 20 else "bridge"))
        sw = swing if b % 2 else 0
        # bateria
        if sec != "intro" and not (sec == "bridge" and bar >= 22):
            drums.add(kick(), b, 0.62)
            seq.sidechain(b)
        elif sec == "intro" and b % 2 == 0 and bar >= 2:
            drums.add(kick(), b, 0.7)
            seq.sidechain(b, 0.35)
        if b % 4 in (1, 3) and sec != "intro":
            drums.add(clap(), b, 0.55, 0.0)
            drums.add(snare(), b, 0.3)
        for h in (0.5,):
            if sec in ("A", "B"):
                drums.add(hat(open_=(b % 2 == 1)), b + h + sw * 0.5, 0.22 * energy, 0.3)
        if sec == "B":
            drums.add(hat(), b + 0.25, 0.1, -0.3)
            drums.add(hat(), b + 0.75, 0.1, -0.3)
        if sec == "bridge" and bar >= 22:
            # virada: caixa acelerando
            for k in range(4 if bar == 22 else 8):
                drums.add(snare(0.08), b + k / (4 if bar == 22 else 8), (0.06 + 0.05 * (bar - 22)) * (0.5 + 0.5 * (b % 4) / 3))
    # harmonia
    for bar in range(bars):
        root, kind = prog[bar % len(prog)]
        sec = "intro" if bar < 4 else ("A" if bar < 12 else ("B" if bar < 20 else "bridge"))
        notes = chord_notes(root, kind, 4)
        d = seq.spb * 4
        pad = mix(*[supersaw(f, d, 5) for f in notes]) * 0.3
        pad = lp(pad, 1800 if sec == "intro" else 3200) * adsr(len(pad), 0.02, 0.2, 0.8, 0.1)
        seq.add(pad, bar * 4, 1.0, -0.35)
        seq.add(pad, bar * 4 + 0.02, 1.0, 0.35)
        # baixo (colcheias com oitava)
        if sec != "intro" or bar >= 2:
            fb = hz(root + "2")
            for k in range(8):
                f = fb * (2 if k % 4 == 3 else 1)
                seq.add(bass_note(f, seq.spb * 0.45), bar * 4 + k * 0.5, 0.36)
        # arpejo de sino no B e na ponte
        if sec in ("B", "bridge"):
            arp = notes + [notes[0] * 2]
            for k in range(8):
                f = arp[k % len(arp)] * 2
                seq.add(bell(f, seq.spb * 0.9), bar * 4 + k * 0.5, 0.11, 0.5 if k % 2 else -0.5)
    # melodia: lista de (batida, nota, duração em batidas) por compasso de 8 compassos
    def lay(mel, start_bar, gain):
        for beat, n, dur in mel:
            f = hz(n)
            x = pluck(f, seq.spb * dur + 0.2) if lead == "pluck" else rhodes(f, seq.spb * dur + 0.3)
            mus.add(x, start_bar * 4 + beat, gain, 0.1)
            mus.add(x, start_bar * 4 + beat + 0.75, gain * 0.25, -0.6)  # eco
    lay(melody_a, 4, 0.5)
    lay(melody_b, 12, 0.5)
    # na ponte a melodia A volta mais baixinha (dá vontade de continuar)
    lay([(b, n, d) for b, n, d in melody_a if b < 12], 20, 0.25)
    vl, vr = stereo_verb(seq.L + mus.L, seq.R + mus.R, 1.8, 0.2)
    n = len(seq.L)
    st = seq.render((vl[:n], vr[:n]), (drums.L, drums.R))
    write_ogg(name, st)


def song_lofi(name, bpm, prog, bars=16):
    seq = Track(bpm, bars)
    drums = Track(bpm, bars)
    for bar in range(bars):
        root, kind = prog[bar % len(prog)]
        notes = chord_notes(root, kind, 4)
        d = seq.spb * 4
        for i, f in enumerate(notes):
            seq.add(rhodes(f, d * 0.95), bar * 4 + i * 0.03, 0.22, -0.2 + 0.2 * i)
        seq.add(bass_note(hz(root + "2"), seq.spb * 1.8) * 0.7, bar * 4, 0.6)
        seq.add(bass_note(hz(root + "2"), seq.spb * 1.4) * 0.7, bar * 4 + 2.5, 0.5)
        if bar % 2 == 1:
            # frase de sino suave
            for k, step_ in enumerate([0, 2, 1]):
                seq.add(bell(notes[step_] * 2, seq.spb * 1.5), bar * 4 + 1 + k, 0.06, 0.4)
        for b in range(4):
            beat = bar * 4 + b
            if b in (0, 2):
                drums.add(lp(kick(0.35), 2500), beat + (0.5 if b == 2 and bar % 2 else 0), 0.45)
            if b in (1, 3):
                drums.add(lp(snare(0.2), 3500), beat, 0.25)
            for h in (0, 0.5):
                drums.add(lp(hat(), 9000), beat + h + (0.08 if h else 0), 0.14, 0.3)
    n = len(seq.L)
    crackle = np.zeros(n + SR * 3)
    for _ in range(int(n / SR * 9)):
        s = int(rng.uniform(0, n))
        crackle[s] += rng.uniform(-0.15, 0.15)
    crackle = lp(crackle, 5000) + lp(noise((n + SR * 3) / SR)[: n + SR * 3], 2000) * 0.004
    vl, vr = stereo_verb(seq.L, seq.R, 1.4, 0.2)
    st = seq.render((lp(vl[:len(seq.L)], 8000) + crackle[: len(seq.L)], lp(vr[:len(seq.R)], 8000) + crackle[: len(seq.L)]), (drums.L, drums.R))
    write_ogg(name, st)


# ------------------------------------------------------------------ gerar

def main():
    sfx = {
        "ui_click": (ui_click, 0.5), "ui_confirm": (ui_confirm, 0.55), "ui_back": (ui_back, 0.5),
        "ui_error": (ui_error, 0.5), "coin": (coin, 0.55), "reward": (lambda: sparkle(6, "C6"), 0.55),
        "levelup": (levelup, 0.7), "countdown_tick": (countdown_tick, 0.6), "countdown_go": (countdown_go, 0.7),
        "timer_warn": (timer_warn, 0.5), "kick": (kick_ball, 0.85), "ball_bounce": (ball_bounce, 0.6),
        "whoosh": (whoosh, 0.55), "throw": (throw, 0.55), "hit": (hit, 0.8), "catch": (catch, 0.65),
        "jump": (jump, 0.5), "boing": (boing, 0.6), "land": (land, 0.5), "trip": (trip, 0.6),
        "point": (point, 0.55), "combo": (combo, 0.55), "goal": (goal, 0.8), "crowd_cheer": (crowd_cheer, 0.6),
        "win": (win, 0.75), "lose": (lose, 0.6), "whistle": (whistle, 0.55), "applause": (applause, 0.55),
        "celebrate": (celebrate, 0.6), "pickup": (pickup, 0.5), "bonk": (bonk, 0.6), "drink": (drink, 0.45),
        "school_bell": (school_bell, 0.6), "clack": (clack, 0.5), "wind": (wind_loop, 0.35),
    }
    for name, (fn, peak) in sfx.items():
        write(name, fn(), peak)
    for i in range(3):
        write(f"step_hard_{i}", step(True, i), 0.5)
        write(f"step_grass_{i}", step(False, i), 0.42)

    # músicas
    C, Am, F, G, Em, Dm = ("C", "maj"), ("A", "min"), ("F", "maj"), ("G", "maj"), ("E", "min"), ("D", "min")
    # recreio: alegre e com pegada (Am F C G)
    mel_a = [(0, "E5", 0.5), (0.5, "G5", 0.5), (1, "A5", 1), (2.5, "G5", 0.5), (3, "E5", 1),
             (4, "F5", 0.5), (4.5, "A5", 0.5), (5, "C6", 1), (6.5, "A5", 0.5), (7, "G5", 1),
             (8, "E5", 0.5), (8.5, "G5", 0.5), (9, "C6", 1), (10.5, "B5", 0.5), (11, "G5", 1),
             (12, "D5", 0.5), (12.5, "G5", 0.5), (13, "B5", 1.5), (14.5, "A5", 0.5), (15, "G5", 1)]
    mel_a = mel_a + [(b + 16, n, d) for b, n, d in mel_a]
    mel_b = [(0, "A5", 0.5), (0.5, "C6", 0.5), (1, "E6", 1), (2, "D6", 0.5), (2.5, "C6", 0.5), (3, "A5", 1),
             (4, "A5", 0.5), (4.5, "C6", 0.5), (5, "F6", 1), (6, "E6", 0.5), (6.5, "C6", 0.5), (7, "A5", 1),
             (8, "G5", 0.5), (8.5, "C6", 0.5), (9, "E6", 1.5), (10.5, "D6", 0.5), (11, "C6", 1),
             (12, "B5", 0.5), (12.5, "D6", 0.5), (13, "G6", 1.5), (14.5, "F6", 0.5), (15, "D6", 1)]
    mel_b = mel_b + [(b + 16, n, d) for b, n, d in mel_b]
    song_pop("music_recreio", 122, [Am, F, C, G], mel_a, mel_b)
    # brincadeiras: mais rápida e eletrizante (C G Am F)
    mel_j = [(0, "C6", 0.5), (0.5, "C6", 0.5), (1, "G5", 0.5), (1.5, "C6", 0.5), (2, "E6", 1), (3, "D6", 1),
             (4, "B5", 0.5), (4.5, "B5", 0.5), (5, "G5", 0.5), (5.5, "B5", 0.5), (6, "D6", 1), (7, "C6", 1),
             (8, "A5", 0.5), (8.5, "C6", 0.5), (9, "E6", 0.5), (9.5, "A6", 0.5), (10, "G6", 1), (11, "E6", 1),
             (12, "F6", 0.5), (12.5, "E6", 0.5), (13, "D6", 0.5), (13.5, "C6", 0.5), (14, "D6", 2)]
    mel_j = mel_j + [(b + 16, n, d) for b, n, d in mel_j]
    mel_j2 = [(b, n.replace("5", "6") if "5" in n else n, d) for b, n, d in mel_j]
    song_pop("music_jogo", 138, [C, G, Am, F], mel_j, mel_j2, energy=1.3)
    # menu: simpático e grudento (F C G Am)
    mel_m = [(0, "A5", 1), (1, "C6", 0.5), (1.5, "A5", 0.5), (2, "G5", 2),
             (4, "G5", 1), (5, "E5", 0.5), (5.5, "G5", 0.5), (6, "C6", 2),
             (8, "D6", 1), (9, "C6", 0.5), (9.5, "B5", 0.5), (10, "G5", 2),
             (12, "A5", 1), (13, "B5", 0.5), (13.5, "C6", 0.5), (14, "E6", 2)]
    mel_m = mel_m + [(b + 16, n, d) for b, n, d in mel_m]
    song_pop("music_menu", 108, [F, C, G, Am], mel_m, mel_m, energy=0.8, lead="rhodes")
    # aula: lo-fi tranquilo
    song_lofi("music_aula", 78, [("F", "maj7"), ("E", "min7"), ("D", "min7"), ("C", "maj7")])


if __name__ == "__main__":
    main()
