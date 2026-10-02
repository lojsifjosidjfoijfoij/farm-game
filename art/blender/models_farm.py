"""The farm in the new look: crops, fruit and forest trees, saplings, farm
buildings and props. Same conventions as models.py (1 unit = 1 tile, foot
point at the origin, x east, y north = away from the camera, z up)."""

import math

import numpy as np

from acres_art import blob, box, cyl, empty, hexrgb, holdout, mat, prism, stick
from models import (BARK, DEPTH_STRETCH, FENCE_WOOD, GLASS, GLOW, HAY, LEAVES, RED, RED_DARK, ROOF_BROWN,
                    ROOF_GREY, SHINGLE, SNOW, STONE, TRIM, WOOD, WOOD_DARK, _canopy, roof_slopes)

# ------------------------------------------------------------------------ crops

GREEN = hexrgb("6cba3c")
GREEN_LIGHT = hexrgb("8fd24e")
GREEN_DARK = hexrgb("4a9a2e")
GREEN_BLUE = hexrgb("5e9a72")

# Plant spots on one soil tile (the tile's centre is the origin).
GRID9 = [(x * 0.27 + 0.03 * ((i * 5) % 3 - 1), y * 0.22) for i, (y, x) in
         enumerate((y, x) for y in (1, 0, -1) for x in (-1, 0, 1))]
GRID4 = [(-0.25, 0.17), (0.11, 0.19), (-0.1, -0.13), (0.25, -0.11)]  # staggered, so the back row shows
ROW3 = [(-0.27, 0.02), (0.0, -0.02), (0.27, 0.03)]
ONE = [(0.0, 0.0)]


def _m(name, hexc, **kw):
    return mat(name, hexrgb(hexc), **kw)


def _seeds(spots, colour, size=0.06):
    seed = _m("seed_" + colour, colour)
    for k, (x, y) in enumerate(spots):
        box((size, size, 0.03), (x + 0.02 * (k % 2), y, 0), seed)


def _sprouts(spots, colour="8fd24e", h=0.13, leaf=0.055):
    m = _m("sprout_" + colour, colour)
    for k, (x, y) in enumerate(spots):
        stick((x, y, 0), (x, y, h), 0.015, m, verts=4)
        for side in (-1, 1):
            leaf_obj = blob(leaf, (x + side * 0.045, y, h + 0.01), m, squash=(1.5, 0.9, 0.45), seed=k)
            leaf_obj.rotation_euler = (0, side * -0.4, 0)


def _leaf(at, length, width, m, tilt=0.0, yaw=0.0, seed=0, thick=0.35):
    """A leaf: a flattened, stretched ball, tilted up (or drooping) and turned."""
    o = blob(1.0, at, m, squash=(width, length, width * thick), seed=seed, jitter=0.1)
    o.rotation_euler = (tilt, 0, yaw)
    return o


def _rosette(x, y, n, length, width, mats, lift=0.05, tilt=0.6, seed=0, z=0.0):
    """Leaves fanned out round a point, rising at `tilt` (radians)."""
    for k in range(n):
        yaw = k * 2 * math.pi / n + seed * 0.7
        cx = x + math.sin(yaw) * length * 0.8
        cy = y - math.cos(yaw) * length * 0.8
        _leaf((cx, cy, z + lift + math.sin(tilt) * length), length, width, mats[k % len(mats)],
              tilt=-tilt, yaw=yaw, seed=seed + k)


def _blades(x, y, n, height, m, lean=0.12, radius=0.022, seed=0, droop=0.0):
    rng = np.random.default_rng(seed)
    for k in range(n):
        a = k * 2 * math.pi / n + rng.uniform(-0.3, 0.3)
        dx, dy = math.cos(a) * lean, math.sin(a) * lean * 0.6
        h = height * rng.uniform(0.8, 1.05)
        if droop:
            mid = (x + dx * 0.6, y + dy * 0.6, h * 0.75)
            stick((x, y, 0), mid, radius, m, verts=4)
            stick(mid, (x + dx * (1 + droop * 2.5), y + dy * (1 + droop * 2), h * (0.75 - droop * 0.5)), radius * 0.8, m,
                  verts=4, tip_radius=0.004)
        else:
            stick((x, y, 0), (x + dx, y + dy, h), radius, m, verts=4, tip_radius=0.004)


def _bush(x, y, r, mats, seed=0, n=4, z=0.0, squash=0.85):
    blob(r, (x, y, z + r * 0.8), mats[0], squash=(1.1, 1.0, squash), subdiv=2, seed=seed, jitter=0.1)
    for k in range(n):
        a = k * 2 * math.pi / n + seed
        blob(r * 0.6, (x + math.cos(a) * r * 0.65, y + math.sin(a) * r * 0.45, z + r * (0.8 + 0.3 * (k % 2))),
             mats[(k + 1) % len(mats)], squash=(1, 0.9, 0.85), subdiv=2, seed=seed + k + 1, jitter=0.1)


def _berries(x, y, z, r, n, m, spread, seed=0, front_only=True):
    rng = np.random.default_rng(seed)
    for k in range(n):
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9) if front_only else rng.uniform(0, 2 * math.pi)
        rr = spread * rng.uniform(0.6, 1.0)
        blob(r, (x + math.cos(a) * rr * 1.2, y + math.sin(a) * rr * 0.7, z + rng.uniform(-spread, spread) * 0.6), m,
             subdiv=1, seed=seed + k, jitter=0.05)


def crop(kind, stage):
    """One soil tile of a crop at growth `stage` 0 (sown) … 4 (ripe)."""
    globals()["_crop_" + kind](stage)


def _crop_carrot(stage):
    if stage == 0:
        return _seeds(GRID9, "c79a5a", 0.045)
    if stage == 1:
        return _sprouts(GRID9, "9ad858", h=0.1, leaf=0.04)
    tops = [_m("carrot_top", "6cba3c"), _m("carrot_top_l", "8fd24e")]
    height = {2: 0.25, 3: 0.38, 4: 0.46}[stage]
    for k, (x, y) in enumerate(GRID9):
        for j in range(5):
            a = j * 1.25 + k
            tip = (x + math.cos(a) * 0.09, y + math.sin(a) * 0.05, height * (0.75 + 0.25 * (j % 2)))
            stick((x, y, 0), tip, 0.012, tops[j % 2], verts=4)
            blob(0.04 + 0.01 * stage, tip, tops[(j + 1) % 2], squash=(1.2, 1, 0.8), seed=k * 5 + j)
        if stage == 4:
            cyl(0.06, 0.09, (x, y - 0.03, 0), _m("carrot", "f27a1e"), verts=8, radius2=0.05)


def _crop_potato(stage):
    if stage == 0:
        mound = _m("potato_mound", "7a5434", noise=0.2, noise_scale=20)
        for k, (x, y) in enumerate(ROW3):
            blob(0.13, (x, y, 0.02), mound, squash=(1.2, 1, 0.4), seed=k)
            blob(0.05, (x + 0.03, y - 0.03, 0.07), _m("potato_seed", "c8a46a"), seed=k)
        return
    if stage == 1:
        return _sprouts(ROW3, "7cc548", h=0.12)
    leaves = {2: ["5aa83a", "6cba3c"], 3: ["4f9a2e", "62b23a"], 4: ["9a9a3a", "b8b04a", "7a8a32"]}[stage]
    mats = [_m(f"potato_leaf{i}_{c}", c, noise=0.15, noise_scale=10, leaves=7.0) for i, c in enumerate(leaves)]
    r = {2: 0.15, 3: 0.22, 4: 0.21}[stage]
    for k, (x, y) in enumerate(ROW3):
        _bush(x, y, r, mats, seed=k * 3, n=4)
        if stage == 3:
            _berries(x, y, r * 1.6, 0.03, 4, _m("potato_flower", "f4f0f8"), r * 0.8, seed=k)
        if stage == 4:
            for j, dx in enumerate((-0.09, 0.08)):
                blob(0.055, (x + dx, y - 0.14, 0.04), _m("potato", "c8a05a", noise=0.15, noise_scale=30),
                     squash=(1.2, 1, 0.8), seed=k + j)


def _crop_strawberry(stage):
    if stage == 0:
        return _seeds(GRID4, "d8a060", 0.05)
    if stage == 1:
        return _sprouts(GRID4, "7cc548")
    mats = [_m("straw_leaf", "3f8a2a", noise=0.1, noise_scale=20, leaves=12.0),
            _m("straw_leaf_l", "62b23a", noise=0.1, noise_scale=20, leaves=12.0)]
    size = {2: 0.09, 3: 0.12, 4: 0.12}[stage]
    for k, (x, y) in enumerate(GRID4):
        _rosette(x, y, 5, size, size * 0.8, mats, tilt=0.5, seed=k)
        if stage == 3:
            _berries(x, y, 0.1, 0.03, 3, _m("straw_flower", "f8f6f0"), 0.1, seed=k)
        if stage == 4:
            berry = _m("strawberry", "ec3a3a", noise=0.25, noise_scale=60)
            for j, (dx, dz) in enumerate(((-0.08, 0.08), (0.04, 0.06), (0.11, 0.1), (-0.01, 0.13))):
                blob(0.06, (x + dx, y - 0.16, dz), berry, squash=(0.9, 0.9, 1.15), subdiv=2, seed=k * 4 + j, jitter=0.05)


def _crop_corn(stage):
    if stage == 0:
        return _seeds(GRID4, "f0c040", 0.05)
    if stage == 1:
        return _sprouts(GRID4, "8fd24e", h=0.16)
    stalk = _m("corn_stalk", "5aa83a")
    leaf = [_m("corn_leaf", "6cba3c"), _m("corn_leaf_d", "4a9a2e")]
    height = {2: 0.55, 3: 1.35, 4: 1.45}[stage]
    for k, (x, y) in enumerate(GRID4):
        stick((x, y, 0), (x, y, height), 0.038, stalk, verts=5, tip_radius=0.022)
        for j, z in enumerate(np.linspace(0.15, height * 0.85, 2 if stage == 2 else 4)):
            side = 1 if (j + k) % 2 else -1
            stick((x, y, z), (x + side * 0.2, y - 0.03, z + 0.14), 0.04, leaf[j % 2], verts=4, tip_radius=0.02)
            stick((x + side * 0.2, y - 0.03, z + 0.14), (x + side * 0.32, y - 0.05, z + 0.0), 0.02, leaf[j % 2],
                  verts=4, tip_radius=0.004)
        if stage >= 3:
            tassel = _m("corn_tassel", "d8b04a" if stage == 4 else "b8c45a")
            for j in range(3):
                stick((x, y, height), (x + (j - 1) * 0.06, y, height + 0.14), 0.012, tassel, verts=4)
            husk = _m("corn_husk", "7cbc48")
            for side in (-1, 1):
                cz = height * 0.5
                stick((x, y, cz), (x + side * 0.1, y - 0.06, cz + 0.2), 0.05, husk, verts=6, tip_radius=0.02)
                if stage == 4:
                    stick((x + side * 0.05, y - 0.08, cz + 0.12), (x + side * 0.1, y - 0.1, cz + 0.24), 0.035,
                          _m("corn_cob", "f2c43a", noise=0.2, noise_scale=40), verts=6, tip_radius=0.02)


def _crop_pumpkin(stage):
    if stage == 0:
        return _seeds([(-0.08, 0), (0.08, 0.02)], "efe0b0", 0.05)
    if stage == 1:
        return _sprouts([(0, 0)], "8fd24e", h=0.12, leaf=0.07)
    vine = _m("pumpkin_vine", "5aa83a")
    leaves = [_m("pumpkin_leaf", "4f9a2e", noise=0.12, noise_scale=12), _m("pumpkin_leaf_l", "62b23a", noise=0.12, noise_scale=12)]
    n = {2: 4, 3: 6, 4: 6}[stage]
    size = {2: 0.12, 3: 0.16, 4: 0.16}[stage]
    for k in range(n):
        a = k * 2 * math.pi / n + 0.4
        x, y = math.cos(a) * 0.28, math.sin(a) * 0.22
        stick((0, 0, 0.02), (x, y, 0.04), 0.018, vine, verts=4)
        _leaf((x, y, 0.1), size, size * 0.9, leaves[k % 2], tilt=-0.5, yaw=a + math.pi / 2, seed=k)
    if stage >= 3:
        colour = "f08a24" if stage == 4 else "8cb84a"
        r = 0.27 if stage == 4 else 0.13
        rib = _m("pumpkin_" + colour, colour, noise=0.08, noise_scale=10)
        for k in range(7):
            a = k * 2 * math.pi / 7
            blob(r * 0.62, (math.cos(a) * r * 0.42, -0.08 + math.sin(a) * r * 0.32, r * 0.72), rib,
                 squash=(1, 1, 1.05), subdiv=2, seed=k, jitter=0.03)
        stick((0, -0.08, r * 1.3), (0.03, -0.08, r * 1.3 + 0.1), 0.03, _m("pumpkin_stem", "6b7a2e"), verts=5)


def _crop_lettuce(stage):
    if stage == 0:
        return _seeds(GRID4, "c8b070", 0.04)
    if stage == 1:
        return _sprouts(GRID4, "9ad858")
    mats = [_m("lettuce", "5fae34", noise=0.12, noise_scale=16, leaves=14.0),
            _m("lettuce_l", "8fd24e", noise=0.12, noise_scale=16, leaves=14.0)]
    heart = _m("lettuce_heart", "c4ec7a", noise=0.15, noise_scale=30, leaves=16.0)
    size = {2: 0.08, 3: 0.12, 4: 0.15}[stage]
    for k, (x, y) in enumerate(GRID4):
        _rosette(x, y, 7, size, size, mats, tilt=0.75, seed=k)
        if stage >= 3:
            blob(size * 0.7, (x, y, size * 0.8), heart, squash=(1, 1, 0.8), subdiv=2, seed=k, jitter=0.2)


def _crop_onion(stage, dry=False):
    if stage == 0:
        return _seeds(GRID9, "3a3028", 0.04)
    if stage == 1:
        return _sprouts(GRID9, "8fd24e", h=0.12, leaf=0.035)
    height = {2: 0.25, 3: 0.42, 4: 0.36}[stage]
    colour = ("c8b46a" if dry else "8cb84a") if stage == 4 else "6cba3c"
    m = _m("onion_leaf_" + colour, colour)
    for k, (x, y) in enumerate(GRID9):
        _blades(x, y, 3 if stage == 2 else 4, height, m, lean=0.07, radius=0.018, seed=k, droop=0.35 if stage == 4 else 0)
        if stage == 4:
            bulb = _m("garlic_bulb" if dry else "onion_bulb", "f2ece0" if dry else "e0a648", noise=0.1, noise_scale=30)
            blob(0.07, (x, y - 0.02, 0.05), bulb, squash=(1, 1, 0.85), subdiv=2, seed=k)


def _crop_garlic(stage):
    _crop_onion(stage, dry=True)


def _crop_kale(stage):
    if stage == 0:
        return _seeds([(-0.05, 0), (0.06, 0.03)], "4a3a2a", 0.04)
    if stage == 1:
        return _sprouts([(0, 0)], "7cb878", h=0.12, leaf=0.07)
    mats = [_m("kale", "5e9a72", noise=0.25, noise_scale=30, leaves=14.0), _m("kale_l", "9cc4a8", noise=0.25, noise_scale=30, leaves=14.0),
            _m("kale_d", "3f7454", noise=0.25, noise_scale=30, leaves=14.0)]
    stem = _m("kale_stem", "a8c8a0")
    n = {2: 5, 3: 7, 4: 9}[stage]
    height = {2: 0.2, 3: 0.32, 4: 0.42}[stage]
    stick((0, 0, 0), (0, 0, height * 0.6), 0.04, stem, verts=6)
    for k in range(n):
        a = k * 2.39996
        reach = 0.12 + 0.12 * (k / n)
        tip = (math.cos(a) * reach * 1.2, math.sin(a) * reach * 0.8, height * (0.55 + 0.45 * (1 - k / n)))
        stick((0, 0, height * 0.4), tip, 0.018, stem, verts=4)
        blob(0.07 + 0.03 * (stage - 2), tip, mats[k % 3], squash=(1.1, 1, 0.75), subdiv=1, seed=k, jitter=0.25)


def _crop_tomato(stage):
    if stage == 0:
        return _seeds([(-0.06, 0), (0.06, 0.02)], "e8d8a0", 0.04)
    if stage == 1:
        return _sprouts([(0, 0)], "7cc548", h=0.14, leaf=0.06)
    leaf = [_m("tomato_leaf", "4f9a2e", noise=0.15, noise_scale=14, leaves=8.0),
            _m("tomato_leaf_l", "62b23a", noise=0.15, noise_scale=14, leaves=8.0)]
    if stage >= 3:
        stick((0.06, 0.04, 0), (0.06, 0.04, 0.95), 0.025, _m("stake", "a07a4a"), verts=5)
    height = {2: 0.3, 3: 0.75, 4: 0.8}[stage]
    stick((0, 0, 0), (0.03, 0.02, height), 0.025, _m("tomato_stem", "5a9a3a"), verts=5)
    for k, z in enumerate(np.linspace(height * 0.3, height, 3 if stage == 2 else 5)):
        side = 1 if k % 2 else -1
        blob(0.11 if stage > 2 else 0.08, (side * 0.09, 0.0, z), leaf[k % 2], squash=(1.3, 1, 0.8), subdiv=2, seed=k)
    if stage >= 3:
        colour = "e8402e" if stage == 4 else "8cc048"
        fruit = _m("tomato_" + colour, colour, noise=0.05, noise_scale=30)
        for k, (x, z) in enumerate(((-0.12, 0.3), (0.1, 0.42), (-0.06, 0.55), (0.13, 0.62), (-0.1, 0.7))):
            blob(0.055, (x, -0.1, z), fruit, subdiv=2, seed=k, jitter=0.04)


def _crop_sunflower(stage):
    if stage == 0:
        return _seeds([(-0.06, 0), (0.06, 0.02)], "4a4038", 0.05)
    if stage == 1:
        return _sprouts([(0, 0)], "8fd24e", h=0.16, leaf=0.07)
    stalk = _m("sun_stalk", "5aa83a")
    leaf = [_m("sun_leaf", "4f9a2e", noise=0.1, noise_scale=14), _m("sun_leaf_l", "62b23a", noise=0.1, noise_scale=14)]
    height = {2: 0.5, 3: 1.2, 4: 1.35}[stage]
    stick((0, 0, 0), (0, 0, height), 0.04, stalk, verts=6, tip_radius=0.03)
    for k, z in enumerate(np.linspace(0.2, height * 0.8, 2 if stage == 2 else 4)):
        side = 1 if k % 2 else -1
        _leaf((side * 0.15, -0.02, z), 0.13, 0.11, leaf[k % 2], tilt=0.2, yaw=side * math.pi / 2, seed=k)
    if stage == 2:
        return
    head = empty("sunhead", (0, -0.05, height + 0.05))
    head.rotation_euler = (math.radians(70), 0, 0)  # face the camera
    if stage == 3:
        blob(0.12, (0, 0, 0), _m("sun_bud", "6cb040"), squash=(1, 1, 0.6), seed=1, parent=head)
        return
    petals = _m("sun_petal", "f6c22a", noise=0.1, noise_scale=30)
    for k in range(12):
        a = k * 2 * math.pi / 12
        petal = blob(0.09, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0), petals, squash=(1.3, 0.7, 0.3), seed=k)
        petal.rotation_euler = (0, 0, a)
        petal.parent = head
    cyl(0.15, 0.06, (0, 0, -0.01), _m("sun_disc", "6a4224", noise=0.3, noise_scale=40), verts=12, parent=head)


def _crop_blueberry(stage):
    if stage == 0:
        return _seeds([(-0.06, 0), (0.06, 0.02)], "6a5a8a", 0.04)
    if stage == 1:
        return _sprouts([(0, 0)], "7cb860", h=0.14)
    mats = [_m("blue_leaf", "357a30", noise=0.15, noise_scale=10, leaves=12.0), _m("blue_leaf_l", "5aa848", noise=0.15, noise_scale=10, leaves=12.0)]
    r = {2: 0.2, 3: 0.3, 4: 0.32}[stage]
    _bush(0, 0.02, r, mats, seed=2, n=5)
    if stage == 3:
        _berries(0, 0, r * 1.1, 0.03, 8, _m("blue_unripe", "b8d0a0"), r * 0.9, seed=3)
    if stage == 4:
        _berries(0, -0.05, r * 1.1, 0.045, 12, _m("blueberry", "3a48b0"), r * 0.95, seed=3)
        _berries(0, -0.05, r * 1.2, 0.04, 8, _m("blueberry_l", "7d8ee0"), r * 0.9, seed=9)


def _crop_cabbage(stage):
    if stage == 0:
        return _seeds([(-0.05, 0), (0.06, 0.03)], "4a3a2a", 0.04)
    if stage == 1:
        return _sprouts([(0, 0)], "8cc0a0", h=0.1, leaf=0.07)
    outer = [_m("cab_outer", "4f8a64", noise=0.12, noise_scale=14, leaves=10.0), _m("cab_outer_l", "78b088", noise=0.12, noise_scale=14, leaves=10.0)]
    size = {2: 0.14, 3: 0.2, 4: 0.24}[stage]
    _rosette(0, 0, 6, size, size * 0.9, outer, tilt=0.55, seed=4)
    if stage >= 3:
        r = 0.14 if stage == 3 else 0.2
        blob(r, (0, -0.02, r * 0.9), _m("cab_head", "c8e8a8", noise=0.1, noise_scale=12, lines=("z", 0.07, 0.015, 0.85)),
             squash=(1, 1, 0.9), subdiv=2, seed=5, jitter=0.04)


def _crop_melon(stage):
    if stage == 0:
        return _seeds([(-0.08, 0), (0.08, 0.02)], "e8e0c0", 0.045)
    if stage == 1:
        return _sprouts([(0, 0)], "8fd24e", h=0.12, leaf=0.07)
    vine = _m("melon_vine", "5aa83a")
    leaves = [_m("melon_leaf", "4f9a2e", noise=0.12, noise_scale=12), _m("melon_leaf_l", "62b23a", noise=0.12, noise_scale=12)]
    n = 4 if stage == 2 else 6
    for k in range(n):
        a = k * 2 * math.pi / n + 0.9
        x, y = math.cos(a) * 0.3, math.sin(a) * 0.22
        stick((0, 0, 0.02), (x, y, 0.04), 0.018, vine, verts=4)
        _leaf((x, y, 0.09), 0.13, 0.12, leaves[k % 2], tilt=-0.5, yaw=a + math.pi / 2, seed=k)
    if stage >= 3:
        r = 0.24 if stage == 4 else 0.12
        colour = "4f9a3a" if stage == 4 else "7cbc58"
        blob(r, (0.02, -0.1, r * 0.8), _m("melon_" + colour, colour, lines=("x", 0.09, 0.035, 0.7), noise=0.08, noise_scale=14),
             squash=(1.3, 1, 0.85), subdiv=2, seed=6, jitter=0.02)


CROPS = ["carrot", "potato", "strawberry", "corn", "pumpkin", "lettuce", "onion", "kale", "tomato", "garlic",
         "sunflower", "blueberry", "cabbage", "melon"]


# ------------------------------------------------------------------------ trees

BIRCH_BARK = hexrgb("ece6da")
FOLIAGE = {
    "birch": {"spring": ["a8dc6a", "93d05a", "bfe680"], "summer": ["5fae3a", "4f9a2e", "74c046"],
              "autumn": ["f0c43a", "e3a52c", "f7d863"]},
    "maple": {"spring": ["8ccf52", "7cc548", "a2da66"], "summer": ["3f8a2a", "357a24", "4f9c32"],
              "autumn": ["d8402a", "e8682c", "b8302a"]},
    "apple": {"spring": ["7cc548", "93d65a", "6ab63c"], "summer": ["4f9a2e", "3e8526", "62b23a"],
              "autumn": ["9aa83a", "c8a838", "7f9a30"]},
    "cherry": {"spring": ["f6bccb", "f9cfdb", "ea9fb6"], "summer": ["3f8a34", "347a2c", "4f9c3e"],
               "autumn": ["e0702c", "c8482a", "eea040"]},
}


def leaf_mats(colours, name="leaf"):
    return [mat(f"{name}{i}_{c}", hexrgb(c), noise=0.16, noise_scale=7, leaves=6.5) for i, c in enumerate(colours)]


def canopy(centre, radius, mats, seed, lumps=9, squash=0.85):
    """A round leafy crown (the same shape as models._canopy), from given materials."""
    cx, cy, cz = centre
    blob(radius * 0.9, (cx, cy, cz), mats[0], squash=(1.1, 0.9, squash), subdiv=2, seed=seed, jitter=0.08)
    for k in range(lumps):
        theta = math.acos(1 - 1.25 * (k + 0.5) / lumps)
        phi = k * 2.39996 + seed
        x = cx + radius * 0.62 * math.sin(theta) * math.cos(phi) * 1.15
        y = cy + radius * 0.5 * math.sin(theta) * math.sin(phi)
        z = cz + radius * 0.62 * math.cos(theta) * squash
        blob(radius * 0.5, (x, y, z), mats[(k + 1) % len(mats)], squash=(1, 0.9, 0.9), subdiv=2,
             seed=seed + k + 1, jitter=0.1)


def surface_points(centre, radius, n, seed, squash=0.85, front=True):
    """Points on the front of a crown (fruit, blossom)."""
    rng = np.random.default_rng(seed)
    cx, cy, cz = centre
    out = []
    while len(out) < n:
        theta = rng.uniform(0.35, 2.1)
        phi = rng.uniform(math.pi * 1.1, math.pi * 1.9) if front else rng.uniform(0, 2 * math.pi)
        out.append((cx + radius * 1.02 * math.sin(theta) * math.cos(phi),
                    cy + radius * 0.85 * math.sin(theta) * math.sin(phi),
                    cz + radius * 0.95 * math.cos(theta) * squash))
    return out


def bare_crown(base, angles, length, radius, bark, seed=0, depth_max=2, snow=True):
    """Winter: limbs fanning out from the trunk top, forking twice, snow along the flatter twigs."""
    twig = mat("twig", hexrgb("6a4630"))
    snow_m = mat("snow", SNOW)

    def limb(start, angle, length, radius, depth, k):
        a = math.radians(angle)
        tip = (start[0] + math.sin(a) * length, start[1] + 0.04 * ((k % 3) - 1), start[2] + math.cos(a) * length)
        stick(start, tip, radius, bark if depth == 0 else twig, verts=5, tip_radius=radius * 0.6)
        if depth < depth_max:
            fork = tuple(b + (t - b) * 0.7 for b, t in zip(start, tip))
            for j, turn in enumerate((-18, 20)):
                limb(fork if depth == 0 else tip, angle + turn, length * (0.62 if depth == 0 else 0.5),
                     radius * 0.62, depth + 1, k * 3 + j)
        elif snow and abs(angle) > 30 and k % 2 == 0:
            blob(0.07, (tip[0], tip[1], tip[2] + 0.03), snow_m, squash=(1.8, 1, 0.45), seed=seed + k)
    for k, angle in enumerate(angles):
        limb(base, angle, length, radius, 0, k)


def birch(season="summer", seed=13, young=False):
    """Slender birch: white bark with dark marks, an airy crown of small clumps."""
    bark = mat("birch_bark", BIRCH_BARK, lines=("z", 0.22, 0.045, 0.3), grain=0.1)
    h = 1.6 if young else 2.5
    stick((0, 0, 0), (0.05, 0, h), 0.1 if not young else 0.07, bark, verts=7, tip_radius=0.05)
    if season == "winter":
        bare_crown((0.05, 0, h * 0.85), (-38, -16, 4, 22, 40), 1.0, 0.06, bark, seed=seed)
        return
    mats = leaf_mats(FOLIAGE["birch"][season], "birch")
    clumps = [(-0.35, 2.0, 0.5), (0.4, 2.25, 0.5), (0.0, 2.75, 0.56), (-0.25, 3.2, 0.42), (0.3, 3.05, 0.4)]
    if young:
        clumps = [(-0.15, 1.45, 0.38), (0.2, 1.6, 0.36), (0.02, 1.95, 0.4)]
    for k, (x, z, r) in enumerate(clumps):
        canopy((x, 0.05, z), r, mats, seed + k * 7, lumps=6, squash=1.05)


def maple(season="summer", seed=17, young=False):
    """Rare maple: a strong trunk and an elegant spreading crown (fiery in autumn)."""
    bark = mat("maple_bark", hexrgb("6e4a34"), noise=0.15, noise_scale=12, lines=("z", 0.28, 0.04, 0.8), grain=0.15)
    if young:
        stick((0, 0, 0), (0, 0, 1.1), 0.1, bark, verts=6, tip_radius=0.07)
        canopy((0, 0.05, 1.5), 0.72, leaf_mats(FOLIAGE["maple"]["summer"], "maple"), seed, lumps=8, squash=0.75)
        return
    stick((0, 0, 0), (0, 0, 1.5), 0.24, bark, verts=8, tip_radius=0.15)
    for side in (-1, 1):
        stick((0, 0, 1.2), (side * 0.6, 0.02, 1.9), 0.11, bark, verts=6, tip_radius=0.07)
        stick((0, 0, 0.1), (side * 0.38, -0.05, 0.0), 0.08, bark, verts=5, tip_radius=0.03)
    if season == "winter":
        bare_crown((0, 0, 1.5), (-60, -38, -16, 6, 26, 46, 64), 1.15, 0.1, bark, seed=seed)
        return
    mats = leaf_mats(FOLIAGE["maple"][season], "maple")
    for k, (x, z, r) in enumerate(((-0.7, 2.25, 0.78), (0.72, 2.3, 0.78), (0.0, 2.7, 0.9))):
        canopy((x, 0.1, z), r, mats, seed + k * 5, lumps=8, squash=0.72)


def fruit_tree(kind="apple", season="summer", seed=23, young=False, overlay=False):
    """Small orchard tree (apple or cherry): short trunk, rounded crown. In
    spring the apple flowers white and the cherry turns all pink. `overlay`
    draws only the fruit (the tree cuts it out where it's in front)."""
    H = holdout()
    bark = H if overlay else mat(f"{kind}_bark", hexrgb("6e4a34" if kind == "apple" else "7a4038"), noise=0.15,
                                 noise_scale=12, lines=("z", 0.25, 0.04, 0.8), grain=0.15)
    if young:
        stick((0, 0, 0), (0, 0, 0.75), 0.08, bark, verts=6, tip_radius=0.06)
        canopy((0, 0.05, 1.05), 0.55, leaf_mats(FOLIAGE[kind]["summer"], kind), seed, lumps=7)
        return
    trunk_top = 1.05 if kind == "apple" else 1.15
    stick((0, 0, 0), (0, 0, trunk_top), 0.15, bark, verts=7, tip_radius=0.1)
    for side in (-1, 1):
        stick((0, 0, trunk_top * 0.8), (side * 0.45, 0.02, trunk_top + 0.35), 0.08, bark, verts=5, tip_radius=0.05)
    if season == "winter" and not overlay:
        bare_crown((0, 0, trunk_top), (-52, -28, -6, 16, 38, 58), 0.95, 0.08, bark, seed=seed)
        return
    mats = [H] if overlay else leaf_mats(FOLIAGE[kind][season], kind)
    if kind == "apple":
        crowns = [((0, 0.1, 1.85), 0.98)]
    else:
        crowns = [((-0.42, 0.1, 1.8), 0.72), ((0.45, 0.1, 1.85), 0.7), ((0.0, 0.1, 2.15), 0.72)]
    for k, (centre, r) in enumerate(crowns):
        canopy(centre, r, mats, seed + k * 5, lumps=8 if kind == "apple" else 6, squash=0.85)
    if overlay:
        fruit = mat(f"{kind}_fruit", hexrgb("e0332a" if kind == "apple" else "a8142a"), noise=0.05, noise_scale=30)
        shine = mat(f"{kind}_shine", hexrgb("ff8a70" if kind == "apple" else "e05068"))
        for k, (centre, r) in enumerate(crowns):
            for j, p in enumerate(surface_points(centre, r, 9 if kind == "apple" else 6, seed + k * 11)):
                if kind == "apple":
                    blob(0.085, p, fruit, subdiv=2, seed=j, jitter=0.03)
                    blob(0.03, (p[0] - 0.03, p[1] - 0.06, p[2] + 0.03), shine, seed=j)
                else:
                    for dx in (-0.045, 0.045):
                        blob(0.055, (p[0] + dx, p[1], p[2] - 0.02), fruit, subdiv=2, seed=j, jitter=0.03)
    elif season == "spring" and kind == "apple":
        blossom = [mat("blossom_w", hexrgb("fbf4f6")), mat("blossom_p", hexrgb("f6c8d8"))]
        for k, (centre, r) in enumerate(crowns):
            for j, p in enumerate(surface_points(centre, r, 26, seed + 40 + k, front=True)):
                blob(0.06, p, blossom[j % 2], squash=(1, 1, 0.7), seed=j)


def young_pine(seed=7):
    bark = mat("bark", BARK, noise=0.15, noise_scale=12)
    stick((0, 0, 0), (0, 0, 0.5), 0.07, bark, verts=6)
    needles = [mat(f"yneedles{i}", c, noise=0.12, noise_scale=8, leaves=9.0)
               for i, c in enumerate((hexrgb("2e7a4c"), hexrgb("3a8c58")))]
    for k, (z, r, h) in enumerate(((0.3, 0.5, 0.75), (0.75, 0.4, 0.7), (1.2, 0.27, 0.65))):
        cyl(r, h, (0, 0, z), needles[k % 2], verts=12, radius2=0.0)


def sapling(kind="oak"):
    """A freshly planted sapling tied to a little stake, in a ring of soil."""
    blob(0.2, (0, 0.02, -0.02), mat("sap_soil", hexrgb("6b4a30"), noise=0.2, noise_scale=20), squash=(1.3, 1, 0.25), seed=1)
    stick((0.12, 0.05, 0), (0.12, 0.05, 0.75), 0.022, mat("stake", hexrgb("b08a5a")), verts=5)
    box((0.12, 0.04, 0.03), (0.06, 0.03, 0.42), mat("twine", hexrgb("d8c08a")))
    stem = mat("sap_stem", hexrgb("7a5232" if kind != "birch" else "e8e2d6"))
    stick((0, 0, 0), (0, 0, 0.6), 0.025, stem, verts=5, tip_radius=0.015)
    if kind == "pine":
        needles = mat("sap_needles", hexrgb("2e7a4c"), noise=0.12, noise_scale=8)
        for z, r in ((0.2, 0.18), (0.38, 0.14), (0.54, 0.09)):
            cyl(r, 0.24, (0, 0, z), needles, verts=10, radius2=0.0)
        return
    colours = {"oak": "5fae34", "birch": "8fd24e", "maple": "4f9c32", "apple": "6ab63c", "cherry": "4f9c3e"}[kind]
    leaf = mat("sap_leaf_" + kind, hexrgb(colours), noise=0.15, noise_scale=12)
    for k, (x, z) in enumerate(((-0.1, 0.42), (0.1, 0.5), (-0.05, 0.62), (0.06, 0.66), (0.0, 0.32))):
        blob(0.075, (x, -0.02, z), leaf, squash=(1.3, 1, 0.8), seed=k)


def felled(seed=29):
    """A tree just chopped, lying on the ground: the trunk along x, a leafy top on the right."""
    bark = mat("bark", BARK, noise=0.15, noise_scale=12, lines=("x", 0.3, 0.04, 0.8), grain=0.15)
    ends = mat("log_ends", hexrgb("e2b980"), noise=0.08)
    stick((-1.3, 0.1, 0.2), (0.5, 0.15, 0.17), 0.2, bark, verts=8, tip_radius=0.16)
    stick((-1.3, 0.1, 0.2), (-1.32, 0.1, 0.2), 0.18, ends, verts=8)
    mats = leaf_mats(LEAVES_SUMMER, "felled")
    for k, (x, y, r) in enumerate(((0.75, 0.15, 0.42), (1.05, 0.05, 0.36), (0.9, 0.35, 0.34))):
        blob(r, (x, y, r * 0.75), mats[k % 3], squash=(1.2, 1, 0.75), subdiv=2, seed=seed + k, jitter=0.12)


LEAVES_SUMMER = ["4f9a2e", "3e8526", "62b23a"]
SEASONS = ("spring", "summer", "autumn", "winter")


# -------------------------------------------------------------- farm buildings

PAINT_FRESH = hexrgb("9cc8e8")
SHUTTER_GREEN = hexrgb("4f8a4a")
ROOF_GREEN = hexrgb("4f8a5a")
GOLD = hexrgb("e8b83a")
FLOWER_COLOURS = ["e8607a", "f2c43a", "f4f0f8", "b07ad8", "f08a3a"]


def _window(x, z, front, glass, trim, w=0.68, h=0.55, shutters=None):
    box((w, 0.05, h), (x, front - 0.02, z), glass)
    for zz in (z - 0.07, z + h - 0.01):
        box((w + 0.14, 0.07, 0.08), (x, front - 0.04, zz), trim)
    box((0.07, 0.07, h), (x, front - 0.04, z), trim)
    if shutters is not None:
        for side in (-1, 1):
            box((0.2, 0.05, h + 0.06), (x + side * (w / 2 + 0.16), front - 0.03, z - 0.03), shutters)


def _flower_box(x, z, front, wood, night, w=0.8):
    if night:
        return
    box((w, 0.16, 0.14), (x, front - 0.12, z), wood)
    for k in range(5):
        c = FLOWER_COLOURS[(k * 2 + int(x * 10)) % len(FLOWER_COLOURS)]
        blob(0.07, (x - w / 2 + 0.1 + k * (w - 0.2) / 4, front - 0.14, z + 0.18), mat("flower_" + c, hexrgb(c)), seed=k)


def _dormer(x, front, roof, walls, glass, trim, night):
    """A little gabled window poking out of the front roof slope."""
    y = front + 0.62
    box((0.72, 0.7, 0.62), (x, y + 0.2, 1.9), walls)
    box((0.42, 0.05, 0.36), (x, y - 0.17, 2.0), glass)
    box((0.52, 0.06, 0.06), (x, y - 0.18, 1.96), trim)
    if not night:
        box((0.86, 0.85, 0.07), (x, y + 0.2, 2.5), roof, rot=(math.radians(8), 0, 0))
        box((0.86, 0.06, 0.08), (x, y - 0.2, 2.48), trim)


def farmhouse(tier=1, night=False):
    """The farmhouse as it grows with the farm (same footprint and chimney as tier 0):
    1 repaired cottage (new roof, fresh paint, flower boxes), 2 a porch with
    a railing, shutters and a dormer, 3 grand: green roof, two dormers, a
    golden weathervane, lanterns and flower beds."""
    H = holdout()
    walls = H if night else mat(f"fh{tier}_walls", PAINT_FRESH if tier < 3 else hexrgb("f2e6c8"), noise=0.05,
                                noise_scale=12, lines=("z", 0.2, 0.035, 0.8))
    trim = H if night else mat("fh_trim", TRIM)
    roof_colour = ROOF_GREEN if tier == 3 else hexrgb("b84a34")
    roof = H if night else mat(f"fh{tier}_roof", roof_colour, noise=0.08, noise_scale=8, lines=("y", 0.22, 0.05, 0.72),
                               tiles=("x", "y", 0.2, 0.17, 0.5, (0.0, 0.05), 0.6))
    wood = H if night else mat("fh_wood", WOOD, noise=0.1, lines=("x", 0.25, 0.04, 0.75), grain=0.12)
    door = H if night else mat("fh_door", hexrgb("8a4a32") if tier < 3 else hexrgb("3f6a8a"), lines=("z", 0.2, 0.03, 0.8))
    brick = H if night else mat("fh_brick", STONE, noise=0.18, noise_scale=20, lines=("z", 0.2, 0.05, 0.72),
                                tiles=("x", "z", 0.22, 0.13, 0.5, 0.035, 0.68))
    glass = mat("fh_glow", (0, 0, 0), emit=GLOW) if night else mat("fh_glass", GLASS)
    shutters = None if tier < 2 else (H if night else mat("fh_shutters", SHUTTER_GREEN, lines=("z", 0.1, 0.02, 0.75)))
    gold = H if night else mat("gold", GOLD, noise=0.1, noise_scale=20)

    front = 0.7
    box((4.0, 2.6, 1.6), (0, front + 1.3, 0), walls)
    for x in (-2.0, 2.0):
        box((0.14, 0.12, 1.6), (x, front - 0.04, 0), trim)
    roof_slopes(span=2.6, rise=1.1, length=4.5, eave_z=1.6, centre_y=front + 1.3, material=roof)
    box((0.45, 0.45, 2.1), (1.35, front + 1.75, 1.2), brick)
    box((0.56, 0.56, 0.1), (1.35, front + 1.75, 3.3), brick)
    # Door with a fanlight, a window either side.
    box((0.62, 0.05, 1.1), (0.25, front - 0.02, 0), door)
    box((0.3, 0.05, 0.22), (0.25, front - 0.04, 0.72), glass)
    box((0.76, 0.06, 0.08), (0.25, front - 0.03, 1.1), trim)
    for x in (-1.3, 1.35):
        _window(x, 0.6, front, glass, trim, shutters=shutters)
        _flower_box(x, 0.42, front, wood, night)
    if tier >= 2:
        _dormer(-0.9 if tier == 3 else 0.2, front, roof, walls, glass, trim, night)
    if tier == 3:
        _dormer(0.75, front, roof, walls, glass, trim, night)
        # The weathervane on the ridge.
        stick((-1.2, front + 1.3, 2.7), (-1.2, front + 1.3, 3.25), 0.025, gold, verts=5)
        box((0.4, 0.03, 0.05), (-1.2, front + 1.3, 3.1), gold)
        blob(0.09, (-1.2, front + 1.3, 3.32), gold, squash=(1.5, 0.6, 1), seed=3)
    # Porch: a deck, posts, a straight lean-to roof (a railing from tier 2).
    deck_w = 1.7 if tier == 1 else 2.6
    box((deck_w, 0.6, 0.12), (0.25, front - 0.3, 0), wood)
    posts = (-0.5, 1.0) if tier == 1 else (-0.95, 1.45)
    for x in posts:
        box((0.1, 0.1, 1.15), (x, front - 0.55, 0.12), trim if tier >= 2 else wood)
    box((deck_w + 0.2, 0.55, 0.07), (0.25, front - 0.25, 1.24), roof, rot=(math.radians(10), 0, 0))
    box((0.8, 0.22, 0.06), (0.25, front - 0.72, 0), wood)
    if tier >= 2 and not night:
        for x0, x1 in ((posts[0], -0.15), (0.65, posts[1])):
            box((x1 - x0, 0.05, 0.06), ((x0 + x1) / 2, front - 0.56, 0.5), trim)
            for k in range(int((x1 - x0) / 0.18)):
                box((0.04, 0.04, 0.38), (x0 + 0.12 + k * 0.18, front - 0.56, 0.12), trim)
    if tier == 3:
        lamp = mat("lantern_glow", (0, 0, 0), emit=hexrgb("ffc46a")) if night else mat("lantern", hexrgb("f6d58a"))
        for x in (-0.25, 0.75):
            box((0.12, 0.1, 0.18), (x, front - 0.08, 0.95), lamp)
            if not night:
                box((0.16, 0.12, 0.04), (x, front - 0.08, 1.13), mat("iron", hexrgb("3b3a40")))
        if not night:  # flower beds along the front
            soil = mat("bed_soil", hexrgb("6b4a30"), noise=0.2, noise_scale=20)
            for x in (-1.3, 1.45):
                box((1.1, 0.35, 0.12), (x, front - 0.35, 0), soil)
                for k in range(6):
                    c = FLOWER_COLOURS[(k + int(x * 3)) % len(FLOWER_COLOURS)]
                    blob(0.09, (x - 0.45 + k * 0.18, front - 0.38 + 0.08 * (k % 2), 0.2), mat("flower_" + c, hexrgb(c)), seed=k)


def coop():
    """Chicken coop: a little red hut on legs with a white-trimmed door, a ramp and a nest window."""
    red = mat("coop_red", hexrgb("b8432f"), noise=0.1, noise_scale=16, lines=("z", 0.18, 0.03, 0.75), grain=0.1)
    trim = mat("trim", TRIM)
    roof = mat("coop_roof", ROOF_GREY, noise=0.1, noise_scale=8, lines=("y", 0.18, 0.04, 0.7))
    wood = mat("wood", WOOD, noise=0.1, lines=("x", 0.2, 0.03, 0.75))
    for x in (-0.75, 0.75):
        for y in (0.3, 1.3):
            box((0.1, 0.1, 0.4), (x, y, 0), wood)
    box((1.7, 1.2, 0.95), (0, 0.8, 0.4), red)
    roof_slopes(span=1.2, rise=0.5, length=2.0, eave_z=1.35, centre_y=0.8, material=roof)
    prism(1.7, 1.2, 0.5, (0, 0.8, 1.35), red)
    box((0.42, 0.05, 0.55), (-0.35, 0.18, 0.45), mat("coop_door", hexrgb("4a2a20")))
    for x in (-0.58, -0.12):
        box((0.06, 0.06, 0.6), (x, 0.17, 0.43), trim)
    box((0.52, 0.06, 0.06), (-0.35, 0.17, 1.0), trim)
    box((0.36, 0.05, 0.28), (0.45, 0.18, 0.75), mat("coop_window", GLASS))
    box((0.46, 0.06, 0.05), (0.45, 0.17, 0.72), trim)
    # The ramp, with slats.
    ramp_len = 0.8
    box((0.36, ramp_len, 0.04), (-0.35, -0.2, 0.18), wood, rot=(math.radians(32), 0, 0))
    box((0.4, 0.3, 0.05), (0.45, 0.0, 0.0), mat("straw", HAY, noise=0.3, noise_scale=30))


def storage_shed():
    """A wooden storage shed: board walls, double doors, a shingle roof and crates outside."""
    boards = mat("shed_boards", hexrgb("a8743f"), noise=0.1, noise_scale=12, lines=("x", 0.22, 0.03, 0.72), grain=0.12)
    trim = mat("trim", TRIM)
    roof = mat("shed_roof", ROOF_BROWN, noise=0.1, noise_scale=8, lines=("y", 0.2, 0.05, 0.7),
               tiles=("x", "y", 0.2, 0.17, 0.5, (0.0, 0.05), 0.6))
    box((2.2, 1.6, 1.25), (0, 1.0, 0), boards)
    roof_slopes(span=1.6, rise=0.7, length=2.5, eave_z=1.25, centre_y=1.0, material=roof)
    prism(2.2, 1.6, 0.7, (0, 1.0, 1.25), boards)
    door = mat("shed_door", hexrgb("7a4a2a"), lines=("x", 0.15, 0.025, 0.75))
    box((1.0, 0.05, 1.0), (0, 0.18, 0), door)
    for x in (-0.53, 0, 0.53):
        box((0.07, 0.06, 1.02), (x, 0.16, 0), trim)
    box((1.12, 0.06, 0.07), (0, 0.16, 1.0), trim)
    for angle, cx in ((40, -0.26), (-40, 0.26)):
        box((0.05, 0.04, 1.2), (cx, 0.14, -0.1), trim, rot=(0, math.radians(angle), 0))
    crate_m = mat("crate_wood", WOOD, noise=0.1, lines=("z", 0.15, 0.025, 0.78), grain=0.12)
    box((0.42, 0.4, 0.4), (0.92, -0.05, 0), crate_m)
    box((0.36, 0.34, 0.34), (0.95, -0.02, 0.4), crate_m)
    blob(0.22, (-0.9, -0.05, 0.2), mat("sack", hexrgb("d9c48e"), noise=0.15, noise_scale=12), squash=(1, 0.9, 0.9), seed=4)


def silo():
    """A metal grain silo: ribbed cylinder, conical roof, a ladder up the side."""
    metal = mat("silo_metal", hexrgb("b8bcc2"), noise=0.08, noise_scale=10, lines=("z", 0.22, 0.04, 0.72))
    roof = mat("silo_roof", hexrgb("8a9098"), lines=("z", 0.15, 0.03, 0.75))
    cyl(0.78, 3.0, (0, 0.8, 0), metal, verts=16)
    cyl(0.84, 0.75, (0, 0.8, 3.0), roof, verts=16, radius2=0.08)
    cyl(0.84, 0.08, (0, 0.8, 0), mat("silo_base", STONE), verts=16)
    rail = mat("ladder", hexrgb("6a6e74"))
    for x in (0.38, 0.62):
        box((0.05, 0.05, 2.9), (x, 0.03, 0.1), rail)
    for k in range(13):
        box((0.28, 0.04, 0.035), (0.5, 0.03, 0.25 + k * 0.21), rail)


def _shelter(kind):
    """The animal pens' shelters: low, open or closed sheds of weathered wood."""
    wood = mat("shelter_wood", hexrgb("9a7448"), noise=0.12, noise_scale=12, lines=("x", 0.22, 0.03, 0.72), grain=0.12)
    dark = mat("shelter_dark", hexrgb("3a2a20"))
    straw = mat("straw", HAY, noise=0.3, noise_scale=30)
    roof_c = {"pigsty": "7b5440", "sheep_shelter": "6a6e74", "goat_shed": "b8432f"}[kind]
    roof = mat(f"{kind}_roof", hexrgb(roof_c), noise=0.1, noise_scale=8, lines=("x", 0.2, 0.04, 0.72))
    w, d, h = (2.2, 1.2, 0.95) if kind == "pigsty" else (2.3, 1.3, 1.15)
    back = 0.9
    box((w, 0.12, h), (0, back + d - 0.06, 0), wood)
    for x in (-w / 2, w / 2):
        box((0.12, d, h * 0.85), (x + (0.06 if x < 0 else -0.06), back + d / 2, 0), wood)
    # The roof slopes down to the front.
    angle = math.atan2(0.35, d)
    box((w + 0.3, d + 0.35, 0.08), (0, back + d / 2 - 0.1, h - 0.05), roof, rot=(math.radians(-math.degrees(angle) * -1) * -1, 0, 0))
    for x in (-w / 2 + 0.08, w / 2 - 0.08):
        box((0.1, 0.1, h * 0.75), (x, back + 0.05, 0), wood)
    box((w - 0.2, d - 0.2, 0.02), (0, back + d / 2, 0.01), dark)
    if kind == "pigsty":
        blob(0.85, (0.1, 0.1, -0.02), mat("mud", hexrgb("6a4a2e"), noise=0.25, noise_scale=10), squash=(1.3, 0.7, 0.05), seed=2)
        box((w - 0.4, 0.5, 0.18), (0, back + 0.55, 0), straw)
    elif kind == "sheep_shelter":
        box((w - 0.3, d - 0.3, 0.2), (0, back + d / 2, 0), straw)
    else:  # goat shed: a hay rack on the back wall
        box((1.0, 0.3, 0.5), (0.3, back + d - 0.25, 0.45), wood)
        box((0.9, 0.25, 0.25), (0.3, back + d - 0.25, 0.9), straw)
        box((w - 0.3, 0.6, 0.12), (0, back + 0.5, 0), straw)


# ----------------------------------------------------------------- farm props

def sign(kind="for_sale"):
    """A painted sign on a stake: "for_sale" (white board, red band), "repair" (a hammer on it)."""
    post = mat("sign_post", hexrgb("8a6a48"))
    stick((0, 0, 0), (0, 0, 0.95), 0.04, post, verts=5)
    if kind == "for_sale":
        box((0.62, 0.05, 0.42), (0, -0.05, 0.6), mat("sign_board", hexrgb("f4efe2"), noise=0.08, noise_scale=20))
        box((0.62, 0.055, 0.12), (0, -0.055, 0.86), mat("sign_red", hexrgb("d84a3a")))
        ink = mat("sign_ink", hexrgb("4a3a2a"))
        for k, w in enumerate((0.42, 0.3)):
            box((w, 0.055, 0.04), (0, -0.056, 0.66 + k * 0.1), ink)
    else:
        box((0.55, 0.05, 0.38), (0, -0.05, 0.55), mat("sign_wood", hexrgb("c8a06a"), lines=("z", 0.1, 0.02, 0.8)))
        iron = mat("hammer_head", hexrgb("6a6e74"))
        box((0.06, 0.055, 0.28), (0.02, -0.06, 0.6), mat("hammer_handle", hexrgb("7a4a2a")), rot=(0, math.radians(30), 0))
        box((0.2, 0.055, 0.08), (0.08, -0.065, 0.8), iron, rot=(0, math.radians(30), 0))


def sprinkler(pro=False):
    brass = mat("brass", hexrgb("d8a83a"), noise=0.1, noise_scale=20)
    if not pro:
        blob(0.14, (0, 0.05, 0.0), mat("sprinkler_soil", hexrgb("6b4a30")), squash=(1.4, 1, 0.3), seed=1)
        stick((0, 0, 0), (0, 0, 0.22), 0.04, mat("pipe", hexrgb("6a6e74")), verts=6)
        cyl(0.08, 0.07, (0, 0, 0.22), brass, verts=8)
        box((0.22, 0.03, 0.03), (0, 0, 0.29), brass)
        return
    green = mat("pro_green", hexrgb("3f8a4a"))
    for a in (0.3, 2.4, 4.5):
        stick((0, 0, 0.6), (math.cos(a) * 0.32, math.sin(a) * 0.24, 0), 0.03, green, verts=5)
    cyl(0.07, 0.25, (0, 0, 0.55), green, verts=8)
    stick((-0.3, 0, 0.82), (0.3, 0, 0.82), 0.025, brass, verts=6)
    for x in (-0.3, 0.3):
        cyl(0.05, 0.06, (x, 0, 0.78), brass, verts=6)
    cyl(0.09, 0.08, (0, 0, 0.78), brass, verts=8)


def water_trough(full=True):
    wood = mat("trough_wood", hexrgb("8a6a48"), noise=0.1, lines=("x", 0.2, 0.03, 0.75), grain=0.12)
    box((1.2, 0.5, 0.4), (0, 0.2, 0), wood)
    if full:
        box((1.08, 0.4, 0.02), (0, 0.2, 0.36), mat("trough_water", hexrgb("5aa6d8"), noise=0.15, noise_scale=12))
        box((0.3, 0.1, 0.021), (-0.2, 0.15, 0.37), mat("trough_shine", hexrgb("b8e0f6")))
    else:
        box((1.08, 0.4, 0.02), (0, 0.2, 0.08), mat("trough_dry", hexrgb("6a5038")))
    for x in (-0.55, 0.55):
        box((0.08, 0.54, 0.44), (x, 0.2, 0), mat("trough_band", hexrgb("5a4030")))


def feeder():
    wood = mat("feeder_wood", hexrgb("9a7448"), noise=0.1, lines=("x", 0.2, 0.03, 0.75), grain=0.12)
    for x in (-0.45, 0.45):
        box((0.08, 0.08, 0.7), (x, 0.2, 0), wood)
    box((0.95, 0.4, 0.08), (0, 0.2, 0.25), wood)
    for side in (-1, 1):
        box((0.95, 0.05, 0.4), (0, 0.2 + side * 0.16, 0.32), wood, rot=(math.radians(side * 22), 0, 0))
    box((0.85, 0.3, 0.2), (0, 0.2, 0.42), mat("feeder_hay", HAY, noise=0.3, noise_scale=30), bevel=0.04)


def bench():
    wood = mat("bench_wood", hexrgb("a8743f"), noise=0.1, lines=("x", 0.25, 0.03, 0.78), grain=0.12)
    iron = mat("bench_iron", hexrgb("3b3a40"))
    for x in (-0.5, 0.5):
        box((0.07, 0.36, 0.42), (x, 0.15, 0), iron)
        box((0.07, 0.07, 0.42), (x, 0.32, 0.4), iron)
    for k in range(3):
        box((1.2, 0.1, 0.05), (0, 0.04 + k * 0.11, 0.4), wood)
    for k in range(2):
        box((1.2, 0.05, 0.1), (0, 0.36, 0.55 + k * 0.15), wood, rot=(math.radians(-12), 0, 0))


def signpost():
    post = mat("signpost", hexrgb("8a6a48"), noise=0.1, lines=("z", 0.3, 0.03, 0.8))
    board = mat("signboard", hexrgb("c8a06a"), lines=("x", 0.2, 0.02, 0.85))
    box((0.1, 0.1, 1.55), (0, 0, 0), post)
    for k, (side, z) in enumerate(((1, 1.25), (-1, 0.98))):
        box((0.55, 0.05, 0.18), (side * 0.25, -0.06, z), board)
        tip = prism(0.18, 0.05, 0.12, (0, 0, 0), board, rot=(math.pi / 2, 0, side * math.pi / 2))
        tip.location = (side * 0.52, -0.035, z + 0.09)
    blob(0.06, (0, 0, 1.6), post, seed=1)


def flowers(colour="yellow"):
    petal = {"yellow": "f6d040", "white": "f8f6f0", "purple": "a46ad8"}[colour]
    centre = {"yellow": "e08a24", "white": "f2c43a", "purple": "f2e0a0"}[colour]
    stem = mat("flower_stem", hexrgb("4f9a2e"))
    pm, cm = mat("petal_" + colour, hexrgb(petal)), mat("centre_" + colour, hexrgb(centre))
    rng = np.random.default_rng({"yellow": 1, "white": 2, "purple": 3}[colour])
    for k in range(7):
        x, y = rng.uniform(-0.2, 0.2), rng.uniform(-0.12, 0.12)
        h = rng.uniform(0.12, 0.24)
        stick((x, y, 0), (x, y, h), 0.012, stem, verts=4)
        blob(0.045, (x, y - 0.01, h), pm, squash=(1, 1, 0.6), seed=k)
        blob(0.018, (x, y - 0.035, h + 0.01), cm, seed=k)
    for k in range(4):
        x = rng.uniform(-0.2, 0.2)
        stick((x, 0.05, 0), (x + 0.03, 0.05, 0.12), 0.02, stem, verts=4, tip_radius=0.003)
