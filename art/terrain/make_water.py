"""Generates the farm pond, Willow Lake and lily pads as pixel art (seen from
above, like the ground), straight into the asset catalog.

- `nature_pond_small` (3.4 × 2.4 tiles): a round farm pond, a soft muddy
  bank, shallow water lightening the edge, a few reeds and lily pads.
- `nature_lake` (10.4 × 5.8 tiles): Willow Lake, sandy on the near shore and
  grassy round the back, with deep blue water in the middle.
- `nature_lily_pads` (1 × 0.6 tiles): a few pads and a pink flower.

Water steps from shallow to deep in flat bands with a dithered seam, and
short light dashes sit on top as ripples and glints.

    uv run --with pillow --with numpy python art/terrain/make_water.py
"""

import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CATALOG = os.environ.get("ACRES_ART_CATALOG") or os.path.join(REPO, "Acres", "Resources", "Assets.xcassets", "Art")
PX = 32


def hexc(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)] + [255], dtype=np.uint8)


WATER = [hexc(c) for c in ("2c5f9c", "3672b0", "4489c4", "56a0d4", "6fb8e0")]  # deep → shallow
GLINT = [hexc("a8dcf2"), hexc("e4f6fc")]
MUD = [hexc(c) for c in ("5e4128", "75533a", "8d6a48")]
SAND = [hexc(c) for c in ("b89a62", "d2b67c", "e4cc94")]
GRASS = [hexc(c) for c in ("2b5a32", "3d7a3a", "548f3e")]
REED = [hexc("4f7f2e"), hexc("78a83e"), hexc("6b4526")]
PAD = [hexc("3d7a3a"), hexc("5aa048"), hexc("8cc85a")]
PINK = [hexc("f29ab4"), hexc("fbd0de")]


def blob_mask(w, h, rng, wobble=0.06, inset=1.5):
    """A rounded shape filling the frame, its edge wobbling gently."""
    phases = rng.uniform(0, 2 * math.pi, 4)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    ang = np.arctan2((yy - cy) / h, (xx - cx) / w)
    r = 1 - wobble * (np.sin(2 * ang + phases[0]) * 0.6 + np.sin(3 * ang + phases[1]) * 0.4
                      + np.sin(5 * ang + phases[2]) * 0.25 + 0.6)
    d = np.hypot((xx - cx) / (w / 2 - inset), (yy - cy) / (h / 2 - inset))
    return d <= r, d / r


def depth_bands(img, mask, dist, rng, bands):
    """Water: shallow at the edge to deep in the middle, with a dithered seam between bands."""
    h, w = mask.shape
    # Uneven bottom: the bands wander, and the deep water takes up more of the middle.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ph = rng.uniform(0, 2 * math.pi, 6)
    wander = (np.sin(xx / w * 9 + ph[0]) * np.cos(yy / h * 7 + ph[1]) * 0.6
              + np.sin((xx + yy) / (w + h) * 23 + ph[2]) * 0.4)
    inner = np.clip(1 - dist + 0.07 * wander, 0, 1) ** 0.75
    level = np.clip((inner * bands).astype(int), 0, bands - 1)
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            lv = level[y, x]
            frac = inner[y, x] * bands - lv
            if frac < 0.25 and lv > 0 and (x + y) % 2 == 0:
                lv -= 1
            img[y, x] = WATER[len(WATER) - 1 - min(lv, len(WATER) - 1)]


def bank(img, mask, rng, near="mud", far="mud", width=2):
    """The shore: a few pixels round the water, mud or sand in front, grass behind."""
    h, w = mask.shape
    grown = mask.copy()
    for _ in range(width):
        g = grown.copy()
        g[1:] |= grown[:-1]
        g[:-1] |= grown[1:]
        g[:, 1:] |= grown[:, :-1]
        g[:, :-1] |= grown[:, 1:]
        grown = g
    ring = grown & ~mask
    for y in range(h):
        for x in range(w):
            if ring[y, x]:
                front = y > h * 0.45
                kind = near if front else far
                pal = SAND if kind == "sand" else (MUD if kind == "mud" else GRASS)
                img[y, x] = pal[int(rng.integers(0, len(pal)))]
    # A dark lip right at the water, where the bank drops in.
    lip = mask.copy()
    lip[1:] &= mask[:-1]
    edge = mask & ~lip
    img[edge] = MUD[0]
    return grown


def glints(img, mask, dist, rng, n):
    h, w = mask.shape
    for _ in range(n):
        x, y = int(rng.integers(2, w - 4)), int(rng.integers(2, h - 2))
        if not mask[y, x] or dist[y, x] > 0.85:
            continue
        length = int(rng.integers(2, 5))
        c = GLINT[int(rng.integers(0, 2))]
        for k in range(length):
            if x + k < w and mask[y, x + k]:
                img[y, x + k] = c


def reed_tuft(img, x, y):
    for k, dx in enumerate((-1, 0, 1, 2)):
        height = (5, 7, 6, 4)[k]
        for j in range(height):
            if 0 <= y - j < img.shape[0] and 0 <= x + dx < img.shape[1]:
                img[y - j, x + dx] = REED[k % 2]
    if 0 <= y - 7 < img.shape[0]:
        img[y - 7:y - 4, x] = REED[2]


def lily(img, x, y, r=2, flower=False):
    h, w = img.shape[:2]
    for dy in range(-r, r + 1):
        for dx in range(-r - 1, r + 2):
            if (dx / (r + 1)) ** 2 + (dy / (r + 0.3)) ** 2 <= 1 and not (dx > 0 and abs(dy) <= dx // 2 and dx >= 1 and dy <= 0):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w:
                    img[yy, xx] = PAD[1] if dy < 0 else PAD[0]
    if 0 <= y - 1 < h and 0 <= x - 1 < w:
        img[y - 1, x - 1] = PAD[2]
    if flower:
        for dx, dy, c in ((0, -1, 0), (-1, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1)):
            if 0 <= y + dy < h and 0 <= x + dx < w:
                img[y + dy, x + dx] = PINK[c]


def pond():
    w, h = round(3.4 * PX), round(2.4 * PX)
    rng = np.random.default_rng(3)
    img = np.zeros((h, w, 4), np.uint8)
    mask, dist = blob_mask(w, h, rng, wobble=0.05, inset=4)
    bank(img, mask, rng, near="mud", far="grass", width=3)
    depth_bands(img, mask, dist, rng, 4)
    edge = mask.copy()
    edge[1:] &= mask[:-1]
    img[mask & ~edge] = MUD[0]
    glints(img, mask, dist, rng, 14)
    lily(img, int(w * 0.68), int(h * 0.62), flower=True)
    lily(img, int(w * 0.78), int(h * 0.48))
    lily(img, int(w * 0.25), int(h * 0.36))
    for x, y in ((8, int(h * 0.55)), (int(w * 0.86), int(h * 0.3)), (int(w * 0.5), 6)):
        reed_tuft(img, x, y)
    return Image.fromarray(img, "RGBA")


def lake():
    w, h = round(10.4 * PX), round(5.8 * PX)
    rng = np.random.default_rng(11)
    img = np.zeros((h, w, 4), np.uint8)
    mask, dist = blob_mask(w, h, rng, wobble=0.07, inset=5)
    bank(img, mask, rng, near="sand", far="grass", width=4)
    depth_bands(img, mask, dist, rng, 5)
    edge = mask.copy()
    edge[1:] &= mask[:-1]
    img[mask & ~edge] = SAND[0]
    glints(img, mask, dist, rng, 60)
    for k in range(5):
        lily(img, int(w * (0.12 + 0.05 * k)), int(h * (0.35 + 0.08 * (k % 3))), flower=k == 2)
    for x, y in ((14, int(h * 0.45)), (24, int(h * 0.3)), (int(w * 0.92), int(h * 0.4)), (int(w * 0.4), 9), (int(w * 0.65), 8)):
        reed_tuft(img, x, y)
    return Image.fromarray(img, "RGBA")


def lily_pads():
    w, h = PX, round(0.6 * PX)
    img = np.zeros((h, w, 4), np.uint8)
    lily(img, 8, 9, r=3, flower=True)
    lily(img, 21, 6, r=2)
    lily(img, 24, 13, r=2)
    return Image.fromarray(img, "RGBA")


def write(name, img):
    folder = os.path.join(CATALOG, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                              {"idiom": "universal", "scale": "2x"}, {"idiom": "universal", "scale": "3x"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    write("nature_pond_small", pond())
    write("nature_lake", lake())
    write("nature_lily_pads", lily_pads())
    print("wrote the pond, the lake and the lily pads")
