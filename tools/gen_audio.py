#!/usr/bin/env python3
"""Sintetiza os efeitos sonoros do jogo em assets/audio (WAV mono 16 bits).

Todos os sons são gerados matematicamente — sem dependência de bancos de
sons de terceiros. Execute:  python3 tools/gen_audio.py
"""
import os
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 22050
rng = np.random.default_rng(42)


def write(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("ok", name, f"{len(x) / SR:.2f}s")


def t(dur):
    return np.arange(int(SR * dur)) / SR


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def env(n, attack, decay):
    tt = np.arange(n) / SR
    a = np.clip(tt / max(attack, 1e-4), 0, 1)
    return a * np.exp(-tt / decay)


# Passos — piso duro (3 variações) e grama (3 variações)
for i in range(3):
    n = int(SR * 0.16)
    noise = rng.standard_normal(n)
    thump = np.sin(2 * np.pi * (90 + i * 12) * t(0.16)) * env(n, 0.002, 0.03)
    tick = lowpass(noise, 0.35 + i * 0.05) * env(n, 0.001, 0.018)
    write(f"step_hard_{i}.wav", thump * 0.8 + tick * 1.2, 0.55)
for i in range(3):
    n = int(SR * 0.2)
    noise = rng.standard_normal(n)
    hp = noise - lowpass(noise, 0.1)
    rustle = hp * env(n, 0.01, 0.05)
    thump = np.sin(2 * np.pi * 70 * t(0.2)) * env(n, 0.003, 0.025)
    write(f"step_grass_{i}.wav", rustle * 0.7 + thump * 0.4, 0.45)

# Clique de interface
n = int(SR * 0.06)
click = np.sin(2 * np.pi * 1400 * t(0.06)) * env(n, 0.001, 0.012)
click += np.sin(2 * np.pi * 2100 * t(0.06)) * env(n, 0.001, 0.006) * 0.5
write("ui_click.wav", click, 0.5)

# Confirmação (duas notas)
d = 0.22
a = np.sin(2 * np.pi * 784 * t(d)) * env(int(SR * d), 0.005, 0.08)
b = np.sin(2 * np.pi * 1046 * t(d)) * env(int(SR * d), 0.005, 0.12)
write("ui_confirm.wav", np.concatenate([a[: int(SR * 0.09)], b]), 0.5)

# Chute na bola
n = int(SR * 0.25)
thud = np.sin(2 * np.pi * 120 * t(0.25) * (1 - t(0.25) * 1.5)) * env(n, 0.001, 0.05)
slap = lowpass(rng.standard_normal(n), 0.5) * env(n, 0.0005, 0.012)
write("kick.wav", thud + slap * 0.9, 0.8)

# Quique da bola
n = int(SR * 0.18)
bounce = np.sin(2 * np.pi * 180 * t(0.18)) * env(n, 0.001, 0.035)
bounce += lowpass(rng.standard_normal(n), 0.3) * env(n, 0.0005, 0.008) * 0.6
write("ball_bounce.wav", bounce, 0.6)

# Arremesso (whoosh)
n = int(SR * 0.35)
noise = rng.standard_normal(n)
sweep = np.zeros(n)
acc = 0.0
for i in range(n):
    alpha = 0.05 + 0.4 * np.sin(np.pi * i / n)
    acc += alpha * (noise[i] - acc)
    sweep[i] = acc
write("whoosh.wav", sweep * np.sin(np.pi * np.arange(n) / n) ** 2, 0.5)

# Pegar objeto (pop)
n = int(SR * 0.12)
f = 500 + 900 * t(0.12) / 0.12
pop = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.002, 0.04)
write("pickup.wav", pop, 0.5)

# Batida (bonk cômico)
n = int(SR * 0.4)
f = 420 * np.exp(-t(0.4) * 6) + 160
bonk = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.12)
write("bonk.wav", bonk, 0.6)

# Gole d'água
n = int(SR * 0.5)
gl = np.zeros(n)
for k in range(4):
    st = int(SR * (0.05 + k * 0.1))
    ln = int(SR * 0.06)
    f = 300 + 500 * np.linspace(0, 1, ln)
    gl[st:st + ln] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(ln)
write("drink.wav", gl, 0.45)

# Comemoração (arpejo alegre)
notes = [523, 659, 784, 1046]
parts = []
for i, fr in enumerate(notes):
    d = 0.11 if i < 3 else 0.35
    x = np.sin(2 * np.pi * fr * t(d)) + 0.3 * np.sin(2 * np.pi * fr * 2 * t(d))
    parts.append(x * env(int(SR * d), 0.004, d * 0.6))
write("celebrate.wav", np.concatenate(parts), 0.5)

# Sinal da escola (campainha elétrica)
d = 2.6
tt = t(d)
ring = np.sign(np.sin(2 * np.pi * 28 * tt)) * 0.5 + 0.5
tone = (np.sin(2 * np.pi * 1180 * tt) + 0.6 * np.sin(2 * np.pi * 2350 * tt)
        + 0.3 * np.sin(2 * np.pi * 3530 * tt))
bell = tone * (0.6 + 0.4 * ring)
fade = np.minimum(1, np.minimum(tt / 0.02, (d - tt) / 0.3))
write("school_bell.wav", bell * fade, 0.6)

# Ambiente externo (vento suave + passarinhos), loop de 12 s
d = 12.0
n = int(SR * d)
wind = lowpass(rng.standard_normal(n), 0.015)
wind *= 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(n) / n * 3)
amb = wind * 0.9
for k in range(14):
    st = int(rng.random() * (n - SR))
    chirps = rng.integers(2, 5)
    base = 2600 + rng.random() * 1800
    for c in range(chirps):
        ln = int(SR * (0.05 + rng.random() * 0.05))
        s0 = st + c * int(SR * 0.09)
        if s0 + ln >= n:
            break
        f = base + 900 * np.sin(np.linspace(0, np.pi, ln))
        amb[s0:s0 + ln] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(ln) * 0.18
# torna o loop contínuo
xf = int(SR * 0.5)
amb[:xf] = amb[:xf] * np.linspace(0, 1, xf) + amb[-xf:] * np.linspace(1, 0, xf)
amb = amb[:-xf]
write("ambient_outdoor.wav", amb, 0.35)

# Ambiente interno (zumbido leve de sala), loop de 6 s
d = 6.0
n = int(SR * d)
hum = lowpass(rng.standard_normal(n), 0.02) * 0.5
hum += np.sin(2 * np.pi * 60 * np.arange(n) / SR) * 0.03
write("ambient_indoor.wav", hum, 0.15)
