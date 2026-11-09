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


# ---------------------------------------------------------------- FASE 6
# Música (síntese de cordas dedilhadas Karplus-Strong + marimba + percussão leve)

def pluck(freq, dur, decay=0.996, bright=0.5):
    n = int(SR * dur)
    period = max(int(SR / freq), 2)
    buf = rng.uniform(-1, 1, period)
    buf = lowpass(buf, bright)
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = decay * 0.5 * (v + buf[(i + 1) % period])
    return out * np.minimum(1, np.arange(n) / (SR * 0.004))


def marimba(freq, dur):
    tt = t(dur)
    e = np.exp(-tt * 7.0)
    return (np.sin(2 * np.pi * freq * tt) + 0.25 * np.sin(2 * np.pi * freq * 4 * tt) * np.exp(-tt * 20)) * e


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base = names[name[0]]
    octave = int(name[-1])
    acc = 1 if "#" in name else 0
    return 440.0 * 2 ** ((base + acc + (octave - 4) * 12) / 12.0)


def song(bpm, chords, melody, length_beats, swing=0.0, kick=True, name="m.wav", vol=0.5):
    beat = 60.0 / bpm
    n = int(SR * beat * length_beats) + SR
    out = np.zeros(n)

    def add(sig, at, gain):
        s = int(at * SR)
        e = min(n, s + len(sig))
        out[s:e] += sig[: e - s] * gain

    for bi in range(length_beats):
        ch = chords[(bi // 4) % len(chords)]
        # violão dedilhado: arpejo em colcheias
        for k in range(2):
            ti = (bi + k * 0.5 + (swing if k == 1 else 0)) * beat
            nn = ch[(bi * 2 + k) % len(ch)]
            add(pluck(note(nn), beat * 1.6, 0.995, 0.45), ti, 0.32)
        if bi % 4 == 0:
            add(pluck(note(ch[0][0] + "2"), beat * 3.5, 0.997, 0.3), bi * beat, 0.4)
        if kick:
            if bi % 2 == 0:
                tt = t(0.18)
                add(np.sin(2 * np.pi * (110 - 60 * tt / 0.18) * tt) * np.exp(-tt * 25), bi * beat, 0.5)
            hat = lowpass(rng.standard_normal(int(SR * 0.04)), 0.9) * np.exp(-np.arange(int(SR * 0.04)) / (SR * 0.008))
            add(hat - lowpass(hat, 0.2), (bi + 0.5) * beat, 0.12)
    for (start, nn, d) in melody:
        add(marimba(note(nn), d * beat + 0.3), start * beat, 0.45)
    # loop: cauda volta para o início
    tail = out[int(SR * beat * length_beats):]
    out = out[: int(SR * beat * length_beats)]
    out[: len(tail)] += tail
    write(name, out, vol)


C = ["C4", "E4", "G4", "E4"]
Am = ["A3", "C4", "E4", "C4"]
F = ["F3", "A3", "C4", "A3"]
G = ["G3", "B3", "D4", "B3"]
Dm = ["D4", "F4", "A4", "F4"]
mel = []
phrase = [("E5", 1), ("G5", 1), ("A5", 0.5), ("G5", 0.5), ("E5", 1), ("C5", 1), ("D5", 1), ("E5", 2),
          ("D5", 0.5), ("C5", 0.5), ("A4", 1), ("C5", 1), ("D5", 1), ("G4", 2), ("C5", 2)]
pos = 0.0
for rep in range(2):
    for nn, d in phrase:
        mel.append((pos, nn, d))
        pos += d
    pos = 16.0 * (rep + 1)
song(118, [C, Am, F, G], mel, 32, swing=0.06, name="music_recreio.wav", vol=0.45)
calm = [(0, "E5", 2), (2, "D5", 2), (4, "C5", 3), (8, "A4", 2), (10, "C5", 2), (12, "G4", 3),
        (16, "E5", 2), (18, "F5", 2), (20, "E5", 3), (24, "D5", 2), (26, "B4", 2), (28, "C5", 3)]
song(84, [C, F, Am, G], calm, 32, kick=False, name="music_aula.wav", vol=0.35)
menu = [(0, "G4", 1), (1, "C5", 1), (2, "E5", 1), (3, "G5", 2), (6, "E5", 1), (7, "D5", 1), (8, "C5", 2),
        (12, "A4", 1), (13, "C5", 1), (14, "D5", 2)]
song(100, [C, G, Am, F], menu, 16, swing=0.04, name="music_menu.wav", vol=0.4)

# Burburinho de crianças (vozes ininteligíveis: ruído com formantes + sílabas)
def babble(dur, voices, rate, seed):
    r = np.random.default_rng(seed)
    n = int(SR * dur)
    out = np.zeros(n)
    for v in range(voices):
        noise = r.standard_normal(n)
        f1 = r.uniform(500, 900)
        f2 = r.uniform(1300, 2400)
        band = lowpass(noise, 2 * np.pi * f2 / SR) - lowpass(noise, 2 * np.pi * f1 / SR)
        syl = np.zeros(n)
        tpos = r.uniform(0, 0.5)
        while tpos < dur - 0.3:
            ln = r.uniform(0.08, 0.22)
            s = int(tpos * SR)
            e = s + int(ln * SR)
            syl[s:e] += np.hanning(e - s) * r.uniform(0.4, 1.0)
            tpos += ln + (r.uniform(0.02, 0.1) if r.random() > 0.15 else r.uniform(0.4, 1.2)) / rate
        out += band * syl
    xf = int(SR * 0.4)
    out[:xf] = out[:xf] * np.linspace(0, 1, xf) + out[-xf:] * np.linspace(1, 0, xf)
    return out[:-xf]


write("ambient_recreio.wav", babble(10.0, 10, 1.0, 5) + lowpass(rng.standard_normal(int(SR * 10.0) - int(SR * 0.4)), 0.01) * 0.6, 0.4)
cant = babble(8.0, 6, 0.8, 9)
for k in range(10):
    s = int(rng.uniform(0, len(cant) - SR * 0.3))
    ln = int(SR * 0.25)
    tt = np.arange(ln) / SR
    cant[s:s + ln] += (np.sin(2 * np.pi * 3100 * tt) + 0.6 * np.sin(2 * np.pi * 4700 * tt)) * np.exp(-tt * 18) * 0.5
write("ambient_cantina.wav", cant, 0.35)
write("ambient_sala.wav", babble(6.0, 4, 0.6, 11) * 0.7 + lowpass(rng.standard_normal(int(SR * 6.0) - int(SR * 0.4)), 0.02) * 0.2, 0.18)

# Apito (futebol) e aplausos
tt = t(0.6)
wh = np.sin(2 * np.pi * (2800 + 120 * np.sin(2 * np.pi * 30 * tt)) * tt) * np.minimum(1, np.minimum(tt / 0.02, (0.6 - tt) / 0.05))
write("whistle.wav", wh, 0.5)
n = int(SR * 2.0)
clap = np.zeros(n)
for k in range(140):
    s = int(rng.uniform(0, n - SR * 0.05))
    ln = int(SR * 0.03)
    clap[s:s + ln] += lowpass(rng.standard_normal(ln), 0.6) * np.exp(-np.arange(ln) / (SR * 0.006))
clap *= np.minimum(1, np.minimum(np.arange(n) / (SR * 0.1), (n - np.arange(n)) / (SR * 0.6)))
write("applause.wav", clap, 0.5)
