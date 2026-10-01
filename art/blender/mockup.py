"""A mock of the first screen, built from the rendered sprites in the asset
catalog, to judge how they sit together before trying them in the game.
It's a hand-placed scene (not the real map), one tile = 16 px, shown 4×.

    python3 art/blender/mockup.py out.png
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from render import frame  # noqa: E402  (sprite sizes from docs/ASSETS.md)

CATALOG = os.path.join(HERE, "..", "..", "Acres", "Resources", "Assets.xcassets", "Art")
PX = 16
TILES_W, TILES_H = 22, 12

GRASS = [(98, 166, 52), (88, 152, 46), (112, 180, 60)]
PATH = [(184, 140, 88), (168, 124, 76)]

# (sprite, x, y) foot points in tiles; x east, y north from the bottom-left.
SCENE = [
    ("building_farmhouse_t0", 7.0, 7.2),
    ("building_barn_old", 15.0, 7.6),
    ("prop_well", 11.2, 6.4),
    ("prop_mailbox", 4.6, 4.9),
    ("prop_log_pile", 3.6, 7.0),
    ("prop_hay_bale", 18.6, 6.2),
    ("prop_hay_bale", 17.9, 5.6),
    ("prop_crate", 12.4, 5.3),
    ("vehicle_truck_old_dir14", 5.0, 3.4),
    ("vehicle_truck_old_load1_dir14", 5.0, 3.4),
    ("tree_oak_summer", 1.4, 10.6),
    ("tree_oak_summer", 20.6, 9.8),
    ("tree_oak_young", 19.2, 3.0),
    ("tree_birch_young", 2.0, 2.0),
    ("tree_stump", 13.6, 2.2),
    ("nature_rock_large", 20.4, 1.2),
    ("nature_rock_small", 15.4, 1.0),
    ("nature_grass_tuft_a", 7.3, 4.6),
    ("nature_grass_tuft_b", 12.6, 8.4),
]
# The cramped edges: brush all round.
BRUSH = [
    ("nature_bush_a", 0.6, 7.6), ("nature_bush_b", 0.8, 5.0), ("nature_bush_a", 0.4, 3.2),
    ("nature_bush_b", 21.4, 7.2), ("nature_bush_a", 21.2, 5.2), ("nature_bush_b", 21.5, 3.4),
    ("nature_bush_a", 4.0, 11.6), ("nature_bush_b", 9.6, 11.8), ("nature_bush_a", 12.8, 11.5),
    ("nature_bush_b", 17.2, 11.7), ("tree_oak_young", 6.6, 11.9), ("tree_birch_young", 15.2, 11.9),
    ("nature_bush_a", 10.4, 0.5), ("nature_bush_b", 17.0, 0.6), ("nature_rock_small", 1.6, 0.6),
]
FIELD = (8, 1, 4, 3)  # x, y, w, h in tiles
FENCE_Y = 0.6


def sprite(name):
    path = os.path.join(CATALOG, name + ".imageset", name + ".png")
    return Image.open(path).convert("RGBA")


def to_px(x, y):
    return x * PX, (TILES_H - y) * PX


def ground():
    rng = np.random.default_rng(7)
    img = Image.new("RGBA", (TILES_W * PX, TILES_H * PX), GRASS[0] + (255,))
    px = img.load()
    for _ in range(TILES_W * TILES_H * 10):
        x, y = rng.integers(0, TILES_W * PX), rng.integers(0, TILES_H * PX)
        px[int(x), int(y)] = GRASS[int(rng.integers(1, 3))] + (255,)
    draw = ImageDraw.Draw(img)
    # Dirt track from the yard down past the truck.
    for (x0, y0, x1, y1) in ((4.2, 6.6, 5.6, 0), (5.6, 6.6, 15.0, 5.6)):
        a, b = to_px(x0, y0), to_px(x1, y1)
        draw.rectangle([a[0], a[1], b[0] - 1, b[1] - 1], fill=PATH[0] + (255,))
    for _ in range(300):
        x, y = rng.integers(0, TILES_W * PX), rng.integers(0, TILES_H * PX)
        if px[int(x), int(y)][:3] == PATH[0]:
            px[int(x), int(y)] = PATH[1] + (255,)
    # The first field: soil tiles, wheat on two rows.
    fx, fy, fw, fh = FIELD
    soil = sprite("field_soil_plowed").resize((PX, PX), Image.NEAREST)
    wet = sprite("field_soil_watered").resize((PX, PX), Image.NEAREST)
    for i in range(fw):
        for j in range(fh):
            img.alpha_composite(wet if j == 0 else soil, to_px(fx + i, fy + j + 1))
    return img


def place(canvas, name, x, y, shadow=True):
    tiles_w, tiles_h, anchor_y = frame(name)
    img = sprite(name)
    w, h = img.size
    fx, fy = to_px(x, y)
    if shadow and "_load" not in name and "grass" not in name:
        s = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        r = w * 0.36
        ImageDraw.Draw(s).ellipse([fx - r + 2, fy - r * 0.35, fx + r + 2, fy + r * 0.35], fill=(20, 40, 10, 70))
        canvas.alpha_composite(s)
    canvas.alpha_composite(img, (int(round(fx - w / 2)), int(round(fy - h * (1 - anchor_y)))))


def main(out):
    canvas = ground()
    fx, fy, fw, fh = FIELD
    items = list(SCENE) + list(BRUSH)
    for i in range(fw):
        for j in range(1, fh):
            items.append(("crop_wheat_stage4" if j == 1 else "crop_wheat_stage2", fx + i + 0.5, fy + j + 0.3))
    for i in range(fw + 1):
        items.append(("prop_fence_wood_h", fx + i, FENCE_Y))
    # Back to front: higher y (further north) first.
    for name, x, y in sorted(items, key=lambda it: (-it[2], "_load" in it[0])):
        place(canvas, name, x, y, shadow=not name.startswith(("crop_", "prop_fence")))
    canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST).save(out)


if __name__ == "__main__":
    main(sys.argv[1])
