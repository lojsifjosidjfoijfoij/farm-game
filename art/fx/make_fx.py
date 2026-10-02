"""Generates the small world effects as pixel art at the world's 32 px per
tile, straight into the asset catalog: shadows, puffs, sparkles, drops,
the tapped-tile ring, the guide arrow, bubbles, the bobber and the heart.

Soft things (shadows, smoke, dust, glows) keep a few steps of see-through,
like the rest of the game's soft effects; everything else is hard-edged with
a dark outline. Things the game tints (the tile ring, the job marker) are
drawn light so the tint shows.

    uv run --with pillow --with numpy python art/fx/make_fx.py
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


def c(s, a=255):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)] + [a], dtype=np.uint8)


def canvas(w_tiles, h_tiles):
    return np.zeros((round(h_tiles * PX), round(w_tiles * PX), 4), np.uint8)


def ellipse_mask(h, w, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2


def outline(img, colour=c("2a1e18")):
    solid = img[..., 3] > 127
    edge = np.zeros_like(solid)
    edge[1:] |= solid[:-1]
    edge[:-1] |= solid[1:]
    edge[:, 1:] |= solid[:, :-1]
    edge[:, :-1] |= solid[:, 1:]
    edge &= ~solid
    img[edge] = colour
    return img


def stepped_alpha(value):
    """Soft alpha in quarter steps."""
    return (np.clip(np.round(value * 4) / 4, 0, 1) * 255).astype(np.uint8)


def shadow():
    img = canvas(1, 0.5)
    h, w = img.shape[:2]
    d = ellipse_mask(h, w, w / 2, h / 2, w / 2 - 0.5, h / 2 - 0.5)
    img[..., :3] = 0
    img[..., 3] = stepped_alpha(np.clip(1.25 - d, 0, 1))
    return img


def puff(colours, seed):
    """A cluster of round lumps, lit at the top, soft at the rim."""
    img = canvas(0.5, 0.5)
    h, w = img.shape[:2]
    rng = np.random.default_rng(seed)
    lumps = [(w * 0.5, h * 0.55, 5.5), (w * 0.3, h * 0.6, 4.0), (w * 0.7, h * 0.62, 4.0), (w * 0.45, h * 0.35, 4.2),
             (w * 0.65, h * 0.4, 3.4)]
    value = np.zeros((h, w))
    shade = np.zeros((h, w), int)
    for cx, cy, r in lumps:
        d = ellipse_mask(h, w, cx + rng.uniform(-0.5, 0.5), cy, r, r)
        inside = d < 1
        value = np.maximum(value, np.clip(1.3 - d, 0, 1))
        yy = np.mgrid[0:h, 0:w][0]
        lit = (yy + 0.5 < cy - r * 0.2) & inside
        shade = np.where(inside, np.where(lit, 2, np.maximum(shade, 1)), shade)
    for k, col in enumerate(colours):
        img[shade == k] = col
    img[..., 3] = np.where(value > 0, stepped_alpha(value * 0.9 + 0.1), 0)
    img[value <= 0.05] = 0
    return img


def sparkle():
    img = canvas(0.3, 0.3)
    h, w = img.shape[:2]
    cx, cy = w // 2, h // 2
    gold, light, white = c("f2b23a"), c("ffe07a"), c("ffffff")
    for k in range(-4, 5):
        for (x, y) in ((cx + k, cy), (cx, cy + k)):
            if 0 <= x < w and 0 <= y < h:
                img[y, x] = gold if abs(k) > 2 else light
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        img[cy + dy, cx + dx] = light
    img[cy, cx] = white
    return img


def heart():
    rows = ["..##..##..",
            ".#RR##rr#.",
            "#RrrrrrrH#",
            "#rrrrrrrH#",
            ".#rrrrrH#.",
            "..#rrrH#..",
            "...#rH#...",
            "....##....",
            ".........."]
    pal = {"#": c("6a1a1a"), "R": c("f8a0a0"), "r": c("e8404a"), "H": c("b82a34")}
    return from_rows(rows, pal, canvas(0.3, 0.3))


def bobber():
    rows = ["....##....",
            "...#ww#...",
            "..#wwww#..",
            "..#rrrr#..",
            "..#rrRr#..",
            "...#rr#...",
            "....##....",
            "....#.....",
            ".........."]
    pal = {"#": c("2a1e18"), "w": c("f6f4ee"), "r": c("e0302a"), "R": c("ff8a70")}
    return from_rows(rows, pal, canvas(0.3, 0.3))


def from_rows(rows, pal, img):
    h, w = img.shape[:2]
    oy, ox = (h - len(rows)) // 2, (w - len(rows[0])) // 2
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in pal and 0 <= oy + j < h and 0 <= ox + i < w:
                img[oy + j, ox + i] = pal[ch]
    return img


def drops():
    img = canvas(0.6, 0.6)
    blue, light, dark = c("5aa6e0"), c("c8ecfa"), c("2f6aa8")
    for (x, y) in ((5, 6), (12, 4), (9, 11), (15, 12), (4, 14)):
        img[y - 2:y + 1, x] = blue
        img[y:y + 2, x - 1:x + 2] = blue
        img[y, x - 1] = light
        img[y + 2, x] = dark
    return outline(img, c("1e3a5a"))


def harvest_pop():
    img = canvas(0.6, 0.6)
    h, w = img.shape[:2]
    leaf, leaf_l, soil, soil_l = c("5aa83a"), c("8fd24e"), c("6e4a32"), c("93693f")
    rng = np.random.default_rng(4)
    for k in range(8):
        a = k * math.pi / 4 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(5, 8)
        x, y = int(w / 2 + math.cos(a) * r), int(h / 2 + math.sin(a) * r * 0.85)
        col = (leaf, leaf_l) if k % 2 == 0 else (soil, soil_l)
        img[y:y + 2, x:x + 2] = col[0]
        img[y, x] = col[1]
    return outline(img)


def wood_chip():
    img = canvas(0.15, 0.15)
    img[1:4, 1:4] = c("e2b980")
    img[1, 1:4] = c("f2d4a0")
    img[3, 2:4] = c("a8743f")
    return img


def tile_highlight():
    """A light rounded ring with a soft glow inside; the game tints it."""
    img = canvas(1, 1)
    n = img.shape[0]
    yy, xx = np.mgrid[0:n, 0:n]
    edge = np.minimum(np.minimum(xx, yy), np.minimum(n - 1 - xx, n - 1 - yy))
    corner = (np.minimum(xx, n - 1 - xx) < 3) & (np.minimum(yy, n - 1 - yy) < 3) & \
             ((np.minimum(xx, n - 1 - xx) + np.minimum(yy, n - 1 - yy)) < 3)
    img[..., :3] = 255
    alpha = np.where(edge <= 1, 1.0, np.where(edge == 2, 0.5, np.where(edge <= 5, 0.25, 0.0)))
    alpha = np.where(corner, 0.0, alpha)
    img[..., 3] = stepped_alpha(alpha)
    return img


def job_marker():
    img = canvas(0.5, 0.5)
    h, w = img.shape[:2]
    d = ellipse_mask(h, w, w / 2, h / 2, w / 2 - 1, h / 2 - 1)
    img[..., :3] = 255
    img[..., 3] = stepped_alpha(np.where(d < 0.35, 1.0, np.where(d < 1, 0.5 * (1 - d) + 0.25, 0)))
    img[d >= 1] = 0
    return img


def guide_arrow():
    """A chunky arrow pointing right, orange with a dark outline (the game rotates it)."""
    img = canvas(0.8, 0.8)
    h, w = img.shape[:2]
    body, light, dark = c("f2992a"), c("ffc46a"), c("c8661a")
    cy = h // 2
    img[cy - 3:cy + 3, 3:14] = body
    for k in range(10):
        img[cy - 9 + k:cy + 9 - k, 13 + k] = body
    img[cy - 3, 3:14] = light
    for k in range(9):
        img[cy - 9 + k, 13 + k] = light
    img[cy + 2, 3:14] = dark
    for k in range(9):
        img[cy + 8 - k, 13 + k] = dark
    return outline(img)


def bubble(mark=None, w_tiles=0.7):
    """A round white speech bubble with a tail at the bottom (and a bold "!")."""
    img = canvas(w_tiles, w_tiles)
    h, w = img.shape[:2]
    body_h = int(h * 0.8)
    d = ellipse_mask(h, w, w / 2, body_h / 2, w / 2 - 1, body_h / 2 - 0.5)
    white, shade = c("fbf8f0"), c("e0d8c8")
    img[d < 1] = white
    yy = np.mgrid[0:h, 0:w][0]
    img[(d < 1) & (d > 0.6) & (yy > body_h * 0.55)] = shade
    tail_x = int(w * 0.4)
    for k in range(h - body_h):
        img[body_h - 1 + k, tail_x:tail_x + max(1, 3 - k)] = white
    if mark == "!":
        x = w // 2
        img[3:body_h - 6, x - 1:x + 1] = c("e0302a")
        img[body_h - 4:body_h - 2, x - 1:x + 1] = c("e0302a")
    return outline(img)


def ripple():
    img = canvas(1, 0.5)
    h, w = img.shape[:2]
    d = ellipse_mask(h, w, w / 2, h / 2, w / 2 - 1, h / 2 - 1)
    ring = (d < 1) & (d > 0.72)
    img[ring] = c("e4f6fc", 220)
    inner = (d < 0.55) & (d > 0.42)
    img[inner] = c("c8ecfa", 140)
    return img


EFFECTS = {
    "fx_shadow_soft": shadow, "fx_smoke_puff": lambda: puff([c("b8bcc4"), c("d8dce2"), c("f4f6f8")], 1),
    "fx_dust_puff": lambda: puff([c("a88a62"), c("c8aa7e"), c("e4cca0")], 2), "fx_sparkle": sparkle,
    "fx_heart": heart, "fx_bobber": bobber, "fx_water_drops": drops, "fx_harvest_pop": harvest_pop,
    "fx_wood_chip": wood_chip, "fx_tile_highlight": tile_highlight, "fx_job_marker": job_marker,
    "fx_guide_arrow": guide_arrow, "fx_bubble": bubble, "fx_exclaim": lambda: bubble("!", 0.5),
    "fx_water_ripple": ripple,
}


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
    for name, make in EFFECTS.items():
        write(name, make())
    print("wrote", len(EFFECTS), "effects")
