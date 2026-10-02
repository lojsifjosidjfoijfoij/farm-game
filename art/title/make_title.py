"""Generates the title screen's picture: the farm on a calm evening, in the
game's pixel art. A deep blue starry sky with a crescent moon, hills with a
line of pines, and the farmhouse with warm windows, a lamp, the barn, a
wheat field and the old truck, lit like the game at night. The title screen
adds what moves (twinkling stars, fireflies, chimney smoke) on top.

    # the sprites at 16 px per tile, for a wider view of the valley:
    ACRES_PX_PER_TILE=16 ACRES_ART_CATALOG=art/title/.sprites \\
      uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy python art/blender/render.py \\
      building_farmhouse_t0 building_barn_old tree_oak_summer tree_pine_summer tree_oak_young \\
      tree_birch_young nature_bush prop_lamp_post prop_fence_wood_h prop_hay_bale prop_well \\
      crop_wheat_stage4 vehicle_truck_old_dir02 prop_log_pile
    uv run --with pillow --with numpy python art/title/make_title.py

It writes `ui_title_scene` (480 × 240 art pixels) into the asset catalog and
prints where the chimney and the lights are, for TitleScreenView.
"""

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "blender"))
from frames import frame  # noqa: E402

SPRITES = os.environ.get("ACRES_TITLE_SPRITES") or os.path.join(HERE, ".sprites")
CATALOG = os.path.join(REPO, "Acres", "Resources", "Assets.xcassets", "Art")
W, H = 480, 240
PX = 16  # art pixels per tile in this picture
HORIZON = 150


def hexc(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def sky(rng):
    bands = ["0b1023", "0f152c", "131b35", "17213e", "1c2747", "222d50", "293357", "31385d", "3b3c61", "463f64", "52456a"]
    img = np.zeros((H, W, 3), np.float32)
    index = [min(len(bands) - 1, int(min(1.0, y / HORIZON) ** 1.6 * len(bands))) for y in range(H)]
    for y in range(H):
        img[y] = hexc(bands[index[y]])
    # Dither where one band meets the next, so the sky steps softly.
    xs = np.arange(W)
    for y in range(1, H - 1):
        if index[y] != index[y - 1]:
            above = hexc(bands[index[y - 1]])
            img[y, xs % 2 == 0] = above
            img[y + 1, xs % 4 == 1] = above
            img[y - 1, xs % 4 == 3] = hexc(bands[index[y]])
    # Stars: mostly faint, a few bright, a handful with a little cross.
    for _ in range(170):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, HORIZON - 30))
        b = rng.random()
        img[y, x] = hexc("e8ecff") if b > 0.85 else hexc("b4bcdc") if b > 0.5 else hexc("7880a8")
    for _ in range(5):
        x, y = int(rng.integers(10, W - 10)), int(rng.integers(5, 80))
        img[y, x] = hexc("ffffff")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            img[y + dy, x + dx] = hexc("9aa4cc")
    return img


def moon(img, cx=400, cy=72):
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot(xx - cx, yy - cy)
    for r, lift in ((26, 1.10), (19, 1.18)):  # a soft halo, in steps
        img[d < r] *= lift
    disc = d < 11
    cut = np.hypot(xx - (cx + 5), yy - (cy - 3)) < 10
    img[disc & ~cut] = hexc("f4ecc8")
    img[disc & ~cut & (np.hypot(xx - (cx - 3), yy - (cy + 2)) < 6)] = hexc("e2d6aa")  # a little shading


def hills(img, rng):
    def ridge(base, amp, seed, cells):
        r = np.random.default_rng(seed)
        pts = r.random(W // cells + 3)
        xs = np.arange(W) / cells
        i = xs.astype(int)
        f = xs - i
        f = f * f * (3 - 2 * f)
        return base - amp * (pts[i] * (1 - f) + pts[i + 1] * f)
    far = ridge(HORIZON - 4, 22, 3, 60)
    near = ridge(HORIZON + 10, 16, 4, 45)
    for x in range(W):
        img[int(far[x]):, x] = hexc("1d2944")
    # A line of pines along the far ridge.
    x = 0
    while x < W:
        h = int(rng.integers(5, 11))
        top = int(far[min(W - 1, x)]) - h
        for j in range(h):
            half = max(0, (j * 3) // (2 * max(1, h // 3)) // 2)
            for dx in range(-half, half + 1):
                if 0 <= x + dx < W:
                    img[top + j, x + dx] = hexc("17223a")
        x += int(rng.integers(3, 9))
    for x in range(W):
        img[int(near[x]):, x] = hexc("1a2a35")
    return near


def sprite(name):
    return Image.open(os.path.join(SPRITES, name + ".imageset", name + ".png")).convert("RGBA")


def place(canvas, name, x, y):
    _, _, anchor = frame(name)
    img = sprite(name)
    canvas.alpha_composite(img, (int(round(x - img.width / 2)), int(round(y - img.height * (1 - anchor)))))
    return img.size, anchor


def farm(rng):
    """The farm by day (it gets its evening light afterwards); transparent above the ground."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grass = Image.open(os.path.join(CATALOG, "terrain_grass.imageset", "terrain_grass.png")).convert("RGBA")
    grass = grass.resize((grass.width // 2, grass.height // 2), Image.NEAREST)  # 16 px per tile
    ground_top = HORIZON + 14
    for gx in range(0, W, grass.width):
        for gy in range(ground_top, H, grass.height):
            layer.alpha_composite(grass, (gx, gy))
    # An uneven edge where the meadow meets the hills.
    a = np.asarray(layer).copy()
    for x in range(W):
        cut = ground_top + int(2 * np.sin(x / 9) + rng.integers(0, 2))
        a[:cut, x, 3] = 0
    layer = Image.fromarray(a, "RGBA")
    d = ImageDraw.Draw(layer)
    # A dirt track from the bottom up to the porch, and on to the barn.
    dirt = [(176, 140, 96), (160, 124, 84), (196, 160, 112)]
    for (x0, y0, x1, y1) in ((140, 204, 156, 240), (156, 206, 300, 214)):
        d.rectangle([x0, y0, x1, y1], fill=dirt[0])
    px = layer.load()
    for _ in range(500):
        x, y = int(rng.integers(140, 300)), int(rng.integers(204, 240))
        if px[x, y][:3] == dirt[0]:
            px[x, y] = dirt[int(rng.integers(1, 3))] + (255,)
    # The field: soil rows (16 px per tile) with ripe wheat.
    soil = Image.open(os.path.join(CATALOG, "field_soil_plowed.imageset", "field_soil_plowed.png")).convert("RGBA")
    soil = soil.resize((16, 16), Image.NEAREST)
    for i in range(6):
        for j in range(2):
            layer.alpha_composite(soil, (318 + i * 16, 214 + j * 16))
    objects = [
        ("tree_pine_summer", 18, 186), ("tree_pine_summer", 44, 182), ("tree_pine_summer", 238, 176),
        ("tree_pine_summer", 262, 180), ("tree_pine_summer", 436, 182), ("tree_pine_summer", 462, 186),
        ("tree_oak_summer", 388, 196), ("building_farmhouse_t0", 150, 204), ("building_barn_old", 300, 200),
        ("prop_log_pile", 104, 206), ("prop_hay_bale", 344, 206), ("prop_well", 226, 207),
        ("prop_lamp_post", 196, 214), ("vehicle_truck_old_dir02", 96, 228), ("tree_birch_young", 24, 232),
        ("tree_oak_young", 470, 236), ("nature_bush_a", 60, 238), ("nature_bush_b", 420, 240),
    ]
    for i in range(6):
        objects += [("crop_wheat_stage4", 326 + i * 16, 226), ("crop_wheat_stage4", 326 + i * 16, 242)]
    objects += [("prop_fence_wood_h", 318 + i * 16 + 8, 247) for i in range(6)]
    spots = {}
    for name, x, y in sorted(objects, key=lambda o: o[2]):
        size, anchor = place(layer, name, x, y)
        spots[name] = (x, y, size, anchor)
    return layer, spots


def light(day_rgba, spots):
    """Evening: a cool blue grade, warm pools of light, glowing windows."""
    a = np.asarray(day_rgba).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3:]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    lit = np.zeros((H, W), np.float32)
    for (x, y, r, s) in ((158, 210, 48, 0.75), (196, 216, 54, 1.0), (300, 206, 26, 0.25)):
        d = np.hypot(xx - x, (yy - y) * 1.3) / r
        lit = np.maximum(lit, s * np.clip(1 - d, 0, 1) ** 1.5)
    lit = (np.round(lit * 8) / 8)[..., None]
    night = rgb * np.array([0.36, 0.44, 0.8], np.float32)
    warm = rgb * np.array([1.08, 0.9, 0.7], np.float32)
    rgb = night * (1 - lit) + warm * lit
    out = Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), alpha], -1).astype(np.uint8), "RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for name in ("building_farmhouse_t0", "prop_lamp_post"):
        x, y, _, _ = spots[name]
        place(glow, name + "_lights", x, y)
    g = np.asarray(glow).astype(np.float32)
    o = np.asarray(out).astype(np.float32)
    o[..., :3] = np.clip(o[..., :3] + g[..., :3] * (g[..., 3:] / 255) * 0.95, 0, 255)
    return Image.fromarray(o.astype(np.uint8), "RGBA")


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
    rng = np.random.default_rng(21)
    img = sky(rng)
    moon(img)
    hills(img, rng)
    canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    day, spots = farm(rng)
    canvas.alpha_composite(light(day, spots))
    # A gentle darkening towards the edges.
    yy, xx = np.mgrid[0:H, 0:W]
    v = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
    a = np.asarray(canvas).astype(np.float32)
    a[..., :3] *= (1 - 0.35 * np.clip(v - 0.7, 0, 1))[..., None]
    canvas = Image.fromarray(a.astype(np.uint8), "RGBA").convert("RGB")
    write("ui_title_scene", canvas)
    # Where things are, as fractions of the picture, for the title screen's animation.
    fx, fy, (sw, sh), anchor = spots["building_farmhouse_t0"]
    chimney = (fx - sw / 2 + 0.77 * sw, fy - (0.896 - anchor) * sh)
    print(json.dumps({"chimney": [round(chimney[0] / W, 4), round(chimney[1] / H, 4)],
                      "meadow_top": round((HORIZON + 14) / H, 4), "horizon": round(HORIZON / H, 4)}))
