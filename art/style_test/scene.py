"""Style test: the farm yard in the v2 look (32 px per tile), day and night.

The ground here (grass, tufts, flowers, the dirt path) is generated pixel by
pixel; the objects are the v2 Blender renders. See README.md."""

import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "blender"))
from frames import frame  # noqa: E402

CAT = os.environ.get("ACRES_ART_CATALOG") or os.path.join(HERE, ".catalog")
PX = 32
TW, TH = 20, 11
W, H = TW * PX, TH * PX


def hexc(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


GRASS = [hexc(c) for c in ("2b5a32", "3d7a3a", "548f3e", "6fa846", "93c254", "b9d86a")]
DIRT = [hexc(c) for c in ("6e4a32", "93693f", "b08552", "c9a068", "dcb87e")]
PEBBLE = [hexc(c) for c in ("6d6a66", "9c978c", "c8c2b2")]


def fbm(h, w, cells, seed, octaves=3):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gh, gw = max(2, int(h / cells) + 2), max(2, int(w / cells) + 2)
        grid = Image.fromarray(rng.random((gh, gw)).astype(np.float32), "F")
        out += amp * np.asarray(grid.resize((w, h), Image.BICUBIC))
        total += amp
        amp *= 0.5
        cells /= 2
    return out / total


def stamp(img, x, y, pattern, palette, rng=None):
    """Draws a little pixel pattern (rows of palette keys, '.' = none) with its bottom-centre at x, y."""
    rows = pattern.strip("\n").split("\n")
    ph, pw = len(rows), max(len(r) for r in rows)
    x0, y0 = int(x - pw // 2), int(y - ph + 1)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "." or ch == " ":
                continue
            yy, xx = y0 + j, x0 + i
            if 0 <= yy < img.shape[0] and 0 <= xx < img.shape[1]:
                img[yy, xx] = palette[ch]


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


def daisy_patch(img, rng, x, y, n):
    pal = {"p": hexc("f6f4ea"), "c": hexc("f0c040"), "s": GRASS[1]}
    for _ in range(n):
        stamp(img, int(x + rng.normal(0, 9)), int(y + rng.normal(0, 6)), ".p.\npcp\n.s.", pal)


def grass_ground(seed=1):
    rng = np.random.default_rng(seed)
    img = np.zeros((H, W, 3), np.float32)
    n = fbm(H, W, 40, seed)
    fine = fbm(H, W, 7, seed + 9, octaves=2)
    level = np.full((H, W), 2)
    level[(n < 0.42) & (fine < 0.32)] = 1          # small darker flecks, not big blotches
    level[n + (fine - 0.5) * 0.25 > 0.64] = 3       # soft sunny patches
    level[(n > 0.74) & (fine > 0.6)] = 4
    for k in range(5):
        img[level == k] = GRASS[k]
    pal = {"k": GRASS[0], "d": GRASS[1], "m": GRASS[2], "l": GRASS[3], "h": GRASS[4], "w": GRASS[5]}
    # Tufts everywhere, lighter where the ground is lighter.
    for _ in range(int(W * H / 18)):
        x, y = rng.integers(0, W), rng.integers(0, H)
        p = dict(pal)
        if level[y, x] >= 3:
            p = {"k": GRASS[1], "d": GRASS[2], "m": GRASS[3], "l": GRASS[4], "h": GRASS[5]}
        elif level[y, x] <= 1:
            p = {"k": GRASS[0], "d": GRASS[0], "m": GRASS[1], "l": GRASS[2], "h": GRASS[3]}
        stamp(img, x, y, TUFTS[rng.integers(0, len(TUFTS))], p)
    for _ in range(int(W * H / 900)):
        x, y = rng.integers(0, W), rng.integers(0, H)
        stamp(img, x, y, CLOVER, pal)
    for _ in range(int(W * H / 260)):
        x, y = rng.integers(0, W), rng.integers(0, H)
        stamp(img, x, y, LEAFY[rng.integers(0, len(LEAFY))], pal)
    return img, level


def flowers(img, rng, count, kinds=("white", "yellow", "pink")):
    petals = {"white": hexc("f4f1e4"), "yellow": hexc("f2d04a"), "pink": hexc("f29ab4"), "blue": hexc("9ab4f4")}
    centre = hexc("e8a83a")
    shade = GRASS[1]
    for _ in range(count):
        x, y = rng.integers(1, W - 1), rng.integers(1, H - 1)
        c = petals[kinds[rng.integers(0, len(kinds))]]
        pal = {"p": c, "c": centre if not np.allclose(c, petals["yellow"]) else hexc("c8742a"), "s": shade}
        stamp(img, x, y, ".p.\npcp\nsps", pal)


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


def clump(img, x, y, kind="purple"):
    pal = {"p": hexc("9a5ac8"), "P": hexc("c48ae8"), "c": hexc("f2c84a"), "w": hexc("f4f1e4"),
           "l": GRASS[3], "m": GRASS[2], "d": GRASS[1]}
    stamp(img, x, y, PURPLE_CLUMP if kind == "purple" else WHITE_CLUMP, pal)


def segment_distance(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / max(1e-6, dx * dx + dy * dy), 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def to_px(x, y):
    return x * PX, (TH - y) * PX


def dirt_path(img, paths, width, seed=4):
    """Paths as polylines in tiles; a soft, ragged edge with a dark rim and pebbles."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dist = np.full((H, W), 1e9, np.float32)
    for line in paths:
        pts = [to_px(*p) for p in line]
        for a, b in zip(pts, pts[1:]):
            dist = np.minimum(dist, segment_distance(xx, yy, a, b))
    wobble = (fbm(H, W, 14, seed) - 0.5) * 10 + (fbm(H, W, 4, seed + 1, octaves=1) - 0.5) * 4
    edge = width * PX / 2 + wobble
    inside = dist < edge
    tex = fbm(H, W, 3, seed + 2, octaves=1)
    shade = np.where(tex < 0.22, 2, np.where(tex > 0.8, 4, 3))
    for k in (2, 3, 4):
        img[inside & (shade == k)] = DIRT[k]
    rim = inside & (dist > edge - 2)
    img[rim] = DIRT[0]
    lip = inside & (dist > edge - 3.5) & ~rim
    img[lip] = DIRT[1]
    # Pebbles.
    pal = {"d": PEBBLE[0], "m": PEBBLE[1], "l": PEBBLE[2]}
    for _ in range(int(inside.sum() / 140)):
        y, x = rng.integers(0, H), rng.integers(0, W)
        if inside[y, x] and dist[y, x] < edge[y, x] - 4:
            stamp(img, x, y, [".l.\nlmd\n.d.", "lm\nmd", "l.\nmd"][rng.integers(0, 3)], pal)
    # Grass creeping over the edge.
    gp = {"k": GRASS[0], "d": GRASS[1], "m": GRASS[2], "l": GRASS[3], "h": GRASS[4]}
    edge_px = np.argwhere(rim)
    for y, x in edge_px[rng.choice(len(edge_px), size=len(edge_px) // 9, replace=False)]:
        stamp(img, x, y + 1, TUFTS[rng.integers(0, len(TUFTS))], gp)
    return inside


def sprite(name):
    return Image.open(os.path.join(CAT, name + ".imageset", name + ".png")).convert("RGBA")


def shadow_mask(objects):
    mask = Image.new("L", (W, H), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(mask)
    for name, x, y in objects:
        if name.startswith(("crop_", "prop_fence", "nature_grass", "fx_")) or "_load" in name or name.endswith("_lights"):
            continue
        tw, th, _ = frame(name)
        fx, fy = to_px(x, y)
        if name.startswith("building_"):
            rx = tw * PX * 0.38
            d.rectangle([fx - rx + 6, fy - 2, fx + rx + 8, fy + 4], fill=255)
        else:
            rx = min(tw, 2.0) * PX * (0.42 if name.startswith("tree_") else 0.4)
            d.ellipse([fx - rx + 4, fy - rx * 0.3, fx + rx + 4, fy + rx * 0.32], fill=255)
    return np.asarray(mask, np.float32) / 255


# The game's breeze (Acres/World/WindSway.swift): (top lean in texels, still share, speed).
# Lean in tiles at the top, so texels = lean × pixels per tile.
SWAY = {"tree": (0.1 * PX, 0.3, 2 * np.pi / 4.8), "sapling": (0.08 * PX, 0.15, 2 * np.pi / 2.4),
        "bush": (0.06 * PX, 0.25, 2 * np.pi / 4.8), "plant": (0.06 * PX, 0.0, 2 * np.pi / 2.4)}


def sway_kind(name):
    if name.startswith("tree_") and name != "tree_stump":
        return "sapling" if name.endswith("_young") else "tree"
    if name.startswith("nature_bush"):
        return "bush"
    if name.startswith(("nature_grass_tuft", "nature_flowers")):
        return "plant"
    return None


def swayed(img, kind, t, phase):
    """The same whole-texel lean as the game's shader, rows pushed sideways."""
    texels, root, speed = SWAY[kind]
    a = np.asarray(img).copy()
    h = a.shape[0]
    wind = np.sin(t * speed + phase) * 0.75 + np.sin(t * speed * 2 + phase * 1.7) * 0.25
    out = np.zeros_like(a)
    for row in range(h):
        v = 1 - (row + 0.5) / h
        k = min(1.0, max(0.0, (v - root) / max(0.001, 1 - root)))
        shift = int(np.floor(wind * texels * k ** 1.5 + 0.5))
        if shift > 0:
            out[row, shift:] = a[row, :-shift]
        elif shift < 0:
            out[row, :shift] = a[row, -shift:]
        else:
            out[row] = a[row]
    return Image.fromarray(out, "RGBA")


def place(canvas, name, x, y, t=None):
    tw, th, anchor = frame(name)
    img = sprite(name)
    kind = sway_kind(name)
    if t is not None and kind is not None:
        img = swayed(img, kind, t, x * 2.0 + y * 1.1)
    w, h = img.size
    fx, fy = to_px(x, y)
    canvas.alpha_composite(img, (int(round(fx - w / 2)), int(round(fy - h * (1 - anchor)))))


def glow_layer(objects):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for name, x, y in objects:
        lights = name + "_lights"
        if os.path.exists(os.path.join(CAT, lights + ".imageset")):
            place(layer, lights, x, y)
    return np.asarray(layer, np.float32) / 255


def compose(ground, objects, night=False, pools=(), fireflies=0, seed=5, t=None):
    img = ground.copy()
    sh = shadow_mask(objects)
    img *= (1 - 0.34 * sh)[..., None]
    canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    for name, x, y in sorted(objects, key=lambda o: (-o[2], "_load" in o[0])):
        place(canvas, name, x, y, t)
    day = np.asarray(canvas, np.float32)[..., :3]
    if not night:
        return day
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = np.zeros((H, W), np.float32)
    for (x, y, r, strength) in pools:
        px_, py_ = to_px(x, y)
        d = np.hypot((xx - px_), (yy - py_) * 1.25) / (r * PX)
        light = np.maximum(light, strength * np.clip(1 - d, 0, 1) ** 1.6)
    light = np.round(light * 10) / 10  # light in steps, like the shading
    night_tint = np.array([0.42, 0.5, 0.86], np.float32)
    warm = np.array([1.12, 0.96, 0.78], np.float32)
    out = day * night_tint * (1 - light[..., None]) + day * warm * light[..., None]
    # Vignette.
    v = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
    out *= (1 - 0.45 * np.clip(v - 0.6, 0, 1))[..., None]
    glow = glow_layer(objects)
    out += glow[..., :3] * glow[..., 3:4] * 255 * 0.9
    rng = np.random.default_rng(seed)
    for _ in range(fireflies):
        x, y = rng.integers(10, W - 10), rng.integers(10, H - 10)
        out[y - 2:y + 3, x - 2:x + 3] += np.array([40, 44, 18], np.float32)
        out[y - 1:y + 2, x - 1:x + 2] += np.array([70, 80, 30], np.float32)
        out[y, x] = np.array([250, 248, 170], np.float32)
    return out


def scene():
    ground, level = grass_ground()
    rng = np.random.default_rng(11)
    flowers(ground, rng, 240)
    for (x, y, n) in [(1.6, 5.4, 14), (12.4, 8.2, 12), (17.6, 2.6, 16), (6.8, 0.8, 10), (19.2, 9.0, 10), (10.2, 7.6, 8)]:
        daisy_patch(ground, rng, *to_px(x, y), n)
    for (x, y, k) in [(2.4, 4.2, "purple"), (11.6, 7.6, "purple"), (17.2, 3.4, "white"), (6.2, 1.4, "white"),
                      (13.2, 4.6, "purple"), (19.0, 7.8, "white"), (1.0, 6.2, "purple"), (8.2, 8.4, "white")]:
        clump(ground, *to_px(x, y), kind=k)
    dirt_path(ground, [[(5.6, 6.4), (5.4, 4.4), (5.0, 1.8), (4.8, -0.5)], [(5.4, 4.6), (9.0, 4.4), (14.6, 4.8), (14.8, 6.2)]], 1.3)
    soil, wet = sprite("field_soil_plowed").convert("RGB"), sprite("field_soil_watered").convert("RGB")
    for i in range(5):
        for j in range(3):
            tile = np.asarray(wet if j == 0 else soil, np.float32)
            px_, py_ = to_px(8 + i, 1 + j + 1)
            ground[int(py_):int(py_) + PX, int(px_):int(px_) + PX] = tile
    objects = [
        ("building_farmhouse_t0", 6.6, 6.8), ("building_barn_old", 14.6, 7.0), ("prop_well", 10.6, 6.0),
        ("prop_lamp_post", 8.4, 5.0), ("prop_mailbox", 4.4, 4.8), ("prop_log_pile", 3.0, 6.6),
        ("prop_hay_bale", 17.8, 5.6), ("prop_hay_bale", 18.5, 6.2), ("prop_crate", 12.2, 5.2),
        ("vehicle_truck_old_dir14", 3.6, 2.8), ("vehicle_truck_old_load1_dir14", 3.6, 2.8),
        ("tree_stump", 14.6, 2.2), ("nature_rock_large", 18.6, 1.4), ("nature_rock_small", 16.0, 0.8),
        ("tree_oak_summer", 18.4, 8.6), ("tree_oak_young", 16.8, 2.6), ("tree_birch_young", 1.4, 2.0),
        ("nature_bush_a", 19.4, 4.0), ("nature_bush_b", 0.7, 4.4), ("nature_bush_a", 12.8, 0.6),
        ("nature_bush_b", 7.0, 0.5), ("nature_grass_tuft_a", 11.4, 3.6), ("nature_grass_tuft_b", 2.6, 5.4),
    ]
    # The forest that hems the farm in: pines along the back and the left.
    for k, x in enumerate(np.arange(0.4, 20.5, 1.45)):
        objects.append(("tree_pine_summer", float(x) + (0.3 if k % 2 else 0), 9.9 + (0.5 if k % 2 else 0)))
    for y in (8.2, 6.9):
        objects.append(("tree_pine_summer", 0.3 if y > 7.5 else -0.2, y))
    objects.append(("tree_pine_summer", 20.0, 6.6))
    for i in range(5):
        for j, stage in enumerate(("crop_wheat_stage4", "crop_wheat_stage3", "crop_wheat_stage2")):
            objects.append((stage, 8.5 + i, 1.3 + j + 1 - 1))
    for i in range(6):
        objects.append(("prop_fence_wood_h", 8 + i, 0.9))
    pools = [(8.4, 4.7, 3.8, 1.0), (6.6, 6.3, 2.6, 0.6), (14.6, 6.4, 1.8, 0.3)]
    return ground, objects, pools


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    ground, objects, pools = scene()
    for night in (False, True):
        img = compose(ground, objects, night=night, pools=pools, fireflies=16)
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
        im.resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(out, "yard_%s.png" % ("night" if night else "day")))
