#!/usr/bin/env python3
"""Gera as texturas procedurais (tileáveis) do jogo em assets/textures.

Todas as texturas são criadas do zero (sem assets de terceiros), portanto
livres para uso comercial. Execute:  python3 tools/gen_textures.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1234)
S = 256


def value_noise(size, cells, seed):
    """Ruído de valor periódico (tileável) em [0,1]."""
    r = np.random.default_rng(seed)
    grid = r.random((cells, cells))
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    top = a * (1 - fx) + b * fx
    bot = c * (1 - fx) + d * fx
    return top * (1 - fy) + bot * fy


def fbm(size, base_cells, octaves, seed, gain=0.5):
    total = np.zeros((size, size))
    amp = 1.0
    norm = 0.0
    cells = base_cells
    for o in range(octaves):
        total += value_noise(size, cells, seed + o * 17) * amp
        norm += amp
        amp *= gain
        cells *= 2
    return total / norm


def save(name, arr, mode="RGB"):
    arr = np.clip(arr, 0, 1)
    img = Image.fromarray((arr * 255).astype(np.uint8), mode)
    img.save(os.path.join(OUT, name))
    print("ok", name)


def gray3(g):
    return np.stack([g, g, g], axis=-1)


# 1. Reboco/pintura (multiplicado pela cor do vértice)
n = fbm(S, 8, 5, 1)
plaster = 0.88 + (n - 0.5) * 0.14
save("plaster.png", gray3(plaster))

# 2. Granilite (piso clássico de escola) — 2x2 placas por textura
n = fbm(S, 16, 3, 2)
speck = rng.random((S, S))
g = 0.86 + (n - 0.5) * 0.08
g = np.where(speck > 0.93, g - 0.22, g)
g = np.where(speck < 0.04, g + 0.08, g)
yy, xx = np.mgrid[0:S, 0:S]
tile = S // 2
for ty in range(2):
    for tx in range(2):
        g[ty * tile:(ty + 1) * tile, tx * tile:(tx + 1) * tile] *= 0.97 + rng.random() * 0.06
grout = ((xx % tile) < 2) | ((yy % tile) < 2)
g = np.where(grout, 0.55, g)
save("tiles.png", gray3(g))

# 3. Madeira
n = fbm(S, 4, 4, 3)
lines = np.sin((yy / S) * np.pi * 2 * 14 + n * 9.0) * 0.5 + 0.5
wood = 0.78 + lines * 0.14 + (fbm(S, 32, 2, 4) - 0.5) * 0.1
planks = (yy % (S // 4)) < 2
wood = np.where(planks, wood * 0.7, wood)
save("wood.png", np.stack([wood, wood * 0.93, wood * 0.86], axis=-1))

# 4. Grama
n1 = fbm(S, 8, 5, 5)
n2 = fbm(S, 32, 3, 6)
blades = rng.random((S, S))
r = 0.32 + n1 * 0.12 + (blades - 0.5) * 0.05
gch = 0.55 + n1 * 0.18 + n2 * 0.08 + (blades - 0.5) * 0.08
b = 0.18 + n1 * 0.06
save("grass.png", np.stack([r, gch, b], axis=-1))

# 5. Cimento queimado (pátio)
n = fbm(S, 6, 6, 7)
spots = fbm(S, 24, 2, 8)
c = 0.82 + (n - 0.5) * 0.16 + (spots - 0.5) * 0.06
joint = ((xx % S) < 2) | ((yy % S) < 2)
c = np.where(joint, c * 0.75, c)
save("concrete.png", gray3(c))

# 6. Tijolinho (murada)
brick = np.zeros((S, S))
bh = S // 8
bw = S // 4
n = fbm(S, 16, 3, 9)
for row in range(8):
    off = (bw // 2) if row % 2 else 0
    for col in range(5):
        x0 = (col * bw + off) % S
        shade = 0.82 + rng.random() * 0.18
        xs = (np.arange(bw) + x0) % S
        brick[row * bh:(row + 1) * bh][:, xs] = shade
brick = brick * (0.92 + (n - 0.5) * 0.15)
mortar = ((yy % bh) < 3) | ((((xx + (yy // bh % 2) * (bw // 2)) % bw) < 3))
brick = np.where(mortar, 0.92, brick)
save("brick.png", gray3(brick))

# 7. Terra / areia
n = fbm(S, 8, 6, 10)
grain = rng.random((S, S))
d = 0.80 + (n - 0.5) * 0.25 + (grain - 0.5) * 0.08
save("dirt.png", np.stack([d, d * 0.86, d * 0.66], axis=-1))

# 8. Telha colonial
v = (yy % (S // 8)) / (S // 8)
u = (xx % (S // 6)) / (S // 6)
wave = np.sin(u * np.pi) * 0.25 + 0.75
shade = 0.7 + v * 0.3
n = fbm(S, 8, 3, 11)
roof = wave * shade * (0.9 + (n - 0.5) * 0.2)
save("roof.png", gray3(roof))

# 9. Alambrado (tela losangular com alpha)
rgba = np.zeros((128, 128, 4))
y2, x2 = np.mgrid[0:128, 0:128]
d1 = np.abs(((x2 + y2) % 32) - 16)
d2 = np.abs(((x2 - y2) % 32) - 16)
wire = (d1 > 14) | (d2 > 14)
rgba[..., 0:3] = 0.75
rgba[..., 3] = np.where(wire, 1.0, 0.0)
save("fence.png", rgba, "RGBA")

# 10. Folhagem (ruído para árvores e arbustos)
n = fbm(S, 8, 5, 12)
leaf = 0.75 + (n - 0.5) * 0.5 + (rng.random((S, S)) - 0.5) * 0.12
save("foliage.png", gray3(leaf))

# 11. Asfalto
n = fbm(S, 16, 4, 13)
grain = rng.random((S, S))
a = 0.55 + (n - 0.5) * 0.12 + (grain - 0.5) * 0.12
save("asphalt.png", gray3(a))
