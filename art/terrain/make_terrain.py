"""Generates the ground textures as pixel art, straight into the asset catalog:
grass with tufts, clover and flowers; packed dirt with pebbles; gravel; old
asphalt. Each is 512 × 512 (16 × 16 tiles at 32 px per tile, one whole chunk,
so the pattern doesn't repeat on screen) and tiles seamlessly.

    uv run --with pillow --with numpy python art/terrain/make_terrain.py
"""

import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CATALOG = os.environ.get("ACRES_ART_CATALOG") or os.path.join(REPO, "Acres", "Resources", "Assets.xcassets", "Art")
N = 512


def hexc(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


GRASS = [hexc(c) for c in ("2b5a32", "3d7a3a", "548f3e", "6fa846", "93c254", "b9d86a")]
DIRT = [hexc(c) for c in ("6e4a32", "93693f", "b08552", "c9a068", "dcb87e")]
PEBBLE = [hexc(c) for c in ("6d6a66", "9c978c", "c8c2b2")]


def noise(cells, seed, octaves=3):
    """Seamless value noise, 0…1, N × N."""
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N), np.float32)
    amp, total = 1.0, 0.0
    for _ in range(octaves):
        g = max(2, int(round(N / cells)))
        grid = rng.random((g, g)).astype(np.float32)
        big = Image.fromarray(np.tile(grid, (3, 3)), "F").resize((N * 3, N * 3), Image.BICUBIC)
        out += amp * np.asarray(big)[N:2 * N, N:2 * N]
        total += amp
        amp *= 0.5
        cells /= 2
    return out / total


def stamp(img, x, y, pattern, palette):
    """A little pixel pattern with its bottom centre at x, y, wrapping round the edges."""
    rows = pattern.strip("\n").split("\n")
    ph, pw = len(rows), max(len(r) for r in rows)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch not in ". ":
                img[(y - ph + 1 + j) % N, (x - pw // 2 + i) % N] = palette[ch]


TUFTS = ["""
.l.h.
.lml.
dmmmd
""", """
h...l
lh.ll
mlhlm
.dmd.
""", """
.h.
lml
dmd
""", """
l.l.h
ml.lm
dmlmd
"""]
CLOVER = """
.h.l.
hlmlh
.lmd.
..d..
"""
LEAFY = ["""
.l.h.l.
lml.lml
.dmlmd.
..dmd..
""", """
..h..
.lml.
lmdml
.dkd.
"""]
PURPLE_CLUMP = """
..p.P..
.pPp.Pp
pPcPpPc
.lPdPl.
ldlmldl
.dmdmd.
"""
WHITE_CLUMP = """
.w..w.
wcw.wcw
.wlwlw.
.ldmdl.
"""


def grass(seed=1):
    rng = np.random.default_rng(seed)
    img = np.zeros((N, N, 3), np.float32)
    n, fine = noise(40, seed), noise(7, seed + 9, octaves=2)
    level = np.full((N, N), 2)
    level[(n < 0.42) & (fine < 0.32)] = 1
    level[n + (fine - 0.5) * 0.25 > 0.64] = 3
    level[(n > 0.74) & (fine > 0.6)] = 4
    for k in range(5):
        img[level == k] = GRASS[k]
    base = {"k": GRASS[0], "d": GRASS[1], "m": GRASS[2], "l": GRASS[3], "h": GRASS[4]}
    sunny = {"k": GRASS[1], "d": GRASS[2], "m": GRASS[3], "l": GRASS[4], "h": GRASS[5]}
    shady = {"k": GRASS[0], "d": GRASS[0], "m": GRASS[1], "l": GRASS[2], "h": GRASS[3]}
    for _ in range(N * N // 18):
        x, y = int(rng.integers(0, N)), int(rng.integers(0, N))
        pal = sunny if level[y, x] >= 3 else shady if level[y, x] <= 1 else base
        stamp(img, x, y, TUFTS[rng.integers(0, len(TUFTS))], pal)
    for _ in range(N * N // 900):
        stamp(img, int(rng.integers(0, N)), int(rng.integers(0, N)), CLOVER, base)
    for _ in range(N * N // 260):
        stamp(img, int(rng.integers(0, N)), int(rng.integers(0, N)), LEAFY[rng.integers(0, 2)], base)
    # Flowers: specks everywhere, a few daisy patches and clumps.
    petals = [hexc("f4f1e4"), hexc("f2d04a"), hexc("f29ab4")]
    for _ in range(N * N // 1100):
        c = petals[rng.integers(0, 3)]
        stamp(img, int(rng.integers(0, N)), int(rng.integers(0, N)), ".p.\npcp\nsps",
              {"p": c, "c": hexc("e8a83a") if c[2] > 100 else hexc("c8742a"), "s": GRASS[1]})
    daisy = {"p": hexc("f6f4ea"), "c": hexc("f0c040"), "s": GRASS[1]}
    for _ in range(6):
        cx, cy = rng.integers(0, N), rng.integers(0, N)
        for _ in range(int(rng.integers(8, 15))):
            stamp(img, int(cx + rng.normal(0, 9)), int(cy + rng.normal(0, 6)), ".p.\npcp\n.s.", daisy)
    clump = {"p": hexc("9a5ac8"), "P": hexc("c48ae8"), "c": hexc("f2c84a"), "w": hexc("f4f1e4"),
             "l": GRASS[3], "m": GRASS[2], "d": GRASS[1]}
    for k in range(10):
        stamp(img, int(rng.integers(0, N)), int(rng.integers(0, N)), PURPLE_CLUMP if k % 2 else WHITE_CLUMP, clump)
    return img


def dirt(seed=4):
    rng = np.random.default_rng(seed)
    img = np.zeros((N, N, 3), np.float32)
    tex, blot = noise(3, seed, octaves=1), noise(24, seed + 3)
    shade = np.where(tex < 0.22, 2, np.where(tex > 0.8, 4, 3))
    shade = np.where((blot < 0.27) & (shade == 3), 2, shade)  # a few darker, damper patches
    for k in (2, 3, 4):
        img[shade == k] = DIRT[k]
    pal = {"d": PEBBLE[0], "m": PEBBLE[1], "l": PEBBLE[2]}
    for _ in range(N * N // 160):
        stamp(img, int(rng.integers(0, N)), int(rng.integers(0, N)),
              [".l.\nlmd\n.d.", "lm\nmd", "l.\nmd"][rng.integers(0, 3)], pal)
    return img


def gravel(seed=6):
    rng = np.random.default_rng(seed)
    dust = [hexc(c) for c in ("8f8370", "a5987f", "b9ad94")]
    stones = [hexc(c) for c in ("6f6a62", "958e82", "bdb5a6", "d8d1c2")]
    tex = noise(3, seed, octaves=1)
    img = np.zeros((N, N, 3), np.float32)
    img[:] = dust[1]
    img[tex < 0.3] = dust[0]
    img[tex > 0.75] = dust[2]
    pal = {"k": stones[0], "d": stones[1], "m": stones[2], "l": stones[3]}
    for _ in range(N * N // 28):
        stamp(img, int(rng.integers(0, N)), int(rng.integers(0, N)),
              [".lm.\nlmmd\n.dk.", "lm\ndk", "lmd\nmdk", "l\nd"][rng.integers(0, 4)], pal)
    return img


def asphalt(seed=8):
    rng = np.random.default_rng(seed)
    tones = [hexc(c) for c in ("3a3634", "46413e", "504a46", "5c5550")]
    tex, blot = noise(2, seed, octaves=1), noise(30, seed + 1)
    img = np.zeros((N, N, 3), np.float32)
    img[:] = tones[1]
    img[tex < 0.25] = tones[0]
    img[tex > 0.78] = tones[2]
    img[(blot > 0.7) & (tex > 0.5)] = tones[3]  # worn, paler patches
    for _ in range(9):  # hairline cracks
        x, y = float(rng.integers(0, N)), float(rng.integers(0, N))
        angle = rng.uniform(0, 2 * np.pi)
        for _ in range(int(rng.integers(20, 60))):
            img[int(y) % N, int(x) % N] = hexc("2a2725")
            angle += rng.normal(0, 0.5)
            x, y = x + np.cos(angle), y + np.sin(angle)
    return img


def write(name, img):
    folder = os.path.join(CATALOG, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(os.path.join(folder, name + ".png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                              {"idiom": "universal", "scale": "2x"}, {"idiom": "universal", "scale": "3x"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    for name, make in (("terrain_grass", grass), ("terrain_dirt", dirt), ("terrain_gravel", gravel), ("terrain_asphalt", asphalt)):
        write(name, make())
        print("wrote", name)
