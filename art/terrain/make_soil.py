"""Generates the field soil as pixel art, straight into the asset catalog.

- `field_soil_plowed`, `_watered`, `_fertilized` (plus `_2`, `_3` variants of
  each): 32 × 32, one tile. Furrows run left to right, four to a tile, so
  tiles join into long rows; ridges lit from the top, dark troughs, clods,
  pebbles and bits of straw. Watered soil is darker with wet glints.
- `field_edge_n`, `_e`, `_s`, `_w`: grass creeping over a field's border on
  that side, with a dark lip where the soil drops away; the game lays them
  over plots whose neighbour on that side isn't a plot.

    uv run --with pillow --with numpy python art/terrain/make_soil.py
"""

import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CATALOG = os.environ.get("ACRES_ART_CATALOG") or os.path.join(REPO, "Acres", "Resources", "Assets.xcassets", "Art")
N = 32


def hexc(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)] + [255], dtype=np.uint8)


DRY = [hexc(c) for c in ("4a2c18", "5e3a20", "7a4e2c", "8f6038", "a8784a", "bf9260")]
WET = [hexc(c) for c in ("2e1b10", "3d2617", "553824", "694830", "80603f", "9a7a5a")]
GRASS = [hexc(c) for c in ("2b5a32", "3d7a3a", "548f3e", "6fa846", "93c254")]
PEBBLE = [hexc(c) for c in ("5f584f", "8f867a", "b8af9f")]
STRAW = [hexc(c) for c in ("b89a5a", "d8bc7a")]

# One furrow, top to bottom (8 rows): the lit crest, the ridge, the slope
# down, the dark trough, and back up.
PROFILE = [4, 3, 3, 2, 2, 1, 0, 1]


def soil(palette, seed, glints=False, fertilizer=False):
    rng = np.random.default_rng(seed)
    img = np.zeros((N, N, 4), np.uint8)
    for x in range(N):
        # A gentle wobble along each furrow (the same for every tile, so rows line up).
        wobble = int(round(np.sin(x / N * 2 * np.pi) * 0.6))
        for y in range(N):
            level = PROFILE[(y - wobble) % 8]
            r = rng.random()
            if r < 0.12:
                level = min(5, level + 1)
            elif r < 0.24:
                level = max(0, level - 1)
            img[y, x] = palette[level]
    # Clods on the ridges: a lit lump with a shadow under it.
    for _ in range(int(rng.integers(5, 9))):
        x, y = int(rng.integers(0, N)), int(rng.integers(0, 4)) * 8 + int(rng.integers(0, 3))
        img[y % N, x] = palette[5]
        img[y % N, (x + 1) % N] = palette[4]
        img[(y + 1) % N, x] = palette[2]
    # Pebbles and straw.
    for _ in range(int(rng.integers(2, 4))):
        x, y = int(rng.integers(0, N)), int(rng.integers(0, N))
        img[y, x], img[y, (x + 1) % N], img[(y + 1) % N, x] = PEBBLE[2], PEBBLE[1], PEBBLE[0]
    for _ in range(int(rng.integers(1, 3))):
        x, y = int(rng.integers(0, N)), int(rng.integers(0, N))
        img[y, x], img[(y + 1) % N, (x + 1) % N] = STRAW[1], STRAW[0]
    if glints:  # wet soil catches the light on the crests
        for _ in range(int(rng.integers(6, 10))):
            x, y = int(rng.integers(0, N)), int(rng.integers(0, 4)) * 8
            img[y, x] = hexc("b8a48c")
    if fertilizer:
        for _ in range(int(rng.integers(14, 20))):
            x, y = int(rng.integers(0, N)), int(rng.integers(0, N))
            img[y, x] = hexc("efe6c8")
    return img


TUFT = ["""
.l.h.
.lml.
dmmmd
""", """
.h.
lml
dmd
""", """
l.l.h
ml.lm
dmlmd
"""]


def edge(side, seed=3):
    """Grass over the border on one side (an uneven strip with a dark lip
    where the soil ends), and upright tufts straddling it."""
    rng = np.random.default_rng(seed)
    img = np.zeros((N, N, 4), np.uint8)
    lip = hexc("3a2214")

    def put(t, d, colour):  # t along the edge, d inwards from it
        y, x = {"n": (d, t), "s": (N - 1 - d, t), "w": (t, d), "e": (t, N - 1 - d)}[side]
        img[y, x] = colour

    for t in range(N):
        depth = 2 + int(rng.integers(0, 3)) + (1 if rng.random() < 0.2 else 0)
        for d in range(depth):
            put(t, d, GRASS[2] if d < depth - 1 else GRASS[1])
        put(t, depth, lip)
    pal = {"d": GRASS[1], "m": GRASS[2], "l": GRASS[3], "h": GRASS[4]}
    t = int(rng.integers(0, 4))
    while t < N:
        rows = TUFT[int(rng.integers(0, len(TUFT)))].strip("\n").split("\n")
        h, w = len(rows), max(len(r) for r in rows)
        # Where the tuft's bottom-left goes, tips always pointing up.
        reach = int(rng.integers(0, 3))  # some tufts lean further over the soil
        x0, base = {"n": (t, 4 + reach), "s": (t, N - 1), "w": (reach, t + h), "e": (N - w - reach, t + h)}[side]
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                xx, yy = x0 + i, base - (h - 1) + j
                if ch != "." and 0 <= xx < N and 0 <= yy < N:
                    img[yy, xx] = pal[ch]
        t += int(rng.integers(3, 7))
    return img


def write(name, arr):
    folder = os.path.join(CATALOG, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(folder, name + ".png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                              {"idiom": "universal", "scale": "2x"}, {"idiom": "universal", "scale": "3x"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    for k, suffix in enumerate(("", "_2", "_3")):
        write("field_soil_plowed" + suffix, soil(DRY, 10 + k))
        write("field_soil_watered" + suffix, soil(WET, 10 + k, glints=True))
        write("field_soil_fertilized" + suffix, soil(DRY, 10 + k, fertilizer=True))
    for k, side in enumerate("nesw"):
        write("field_edge_" + side, edge(side, seed=20 + k))
    print("wrote soil and field edges")
