"""The village in the new look: shops, houses and their props, plus the
workshops that stand on the farm. Same conventions as models.py (1 unit =
1 tile, foot point at the origin, x east, y north = away from the camera,
z up). Every building with windows also renders a night overlay
(`night=True`): only the glowing glass, the rest cut out."""

import math

import numpy as np

from acres_art import blob, box, cyl, empty, hexrgb, holdout, mat, prism, stick
from models import GLASS, GLOW, HAY, ROOF_GREY, STONE, TRIM, WOOD, WOOD_DARK, roof_slopes


def _m(name, hexc, **kw):
    return mat(name, hexrgb(hexc), **kw)


WALLS = {
    "plaster": lambda c: dict(noise=0.05, noise_scale=10, grain=0.06),
    "boards": lambda c: dict(noise=0.08, noise_scale=12, lines=("z", 0.2, 0.035, 0.8), grain=0.1),
    "brick": lambda c: dict(noise=0.15, noise_scale=20, lines=("z", 0.14, 0.03, 0.75), tiles=("x", "z", 0.26, 0.14, 0.5, 0.03, 0.72)),
    "stone": lambda c: dict(noise=0.15, noise_scale=10, lines=("z", 0.24, 0.04, 0.72), tiles=("x", "z", 0.4, 0.24, 0.5, 0.04, 0.7)),
}


class Kit:
    """Materials for one building, with everything but the glass cut out at night."""

    def __init__(self, name, night, walls, wall_kind="plaster", roof="b84a34", trim="efe6d2", door="7a4a2a"):
        self.night = night
        H = holdout()
        self.walls = H if night else _m(f"{name}_walls", walls, **WALLS[wall_kind](walls))
        self.roof = H if night else _m(f"{name}_roof", roof, noise=0.08, noise_scale=8, lines=("y", 0.2, 0.045, 0.7),
                                       tiles=("x", "y", 0.2, 0.17, 0.5, (0.0, 0.045), 0.6))
        self.trim = H if night else _m(f"{name}_trim", trim)
        self.door = H if night else _m(f"{name}_door", door, lines=("z", 0.2, 0.03, 0.8))
        self.glass = _m("glow", "000000", emit=GLOW) if night else _m("glass", "2d4a63")
        self.dark = H if night else _m("iron", "3b3a40")
        self.H = H

    def solid(self, name, hexc, **kw):
        return self.H if self.night else _m(name, hexc, **kw)


def house_body(k, w, d, h, front=0.5, rise=1.0, ridge="x", overhang=0.22):
    """Walls and a pitched roof. ridge "x": eaves to the front; "y": the gable end faces the front."""
    mid = front + d / 2
    box((w, d, h), (0, mid, 0), k.walls)
    if ridge == "x":
        roof_slopes(span=d, rise=rise, length=w + 0.4, eave_z=h, centre_y=mid, material=k.roof, overhang=overhang)
        for x in (-w / 2, w / 2):
            box((0.12, 0.12, h), (x, front - 0.04, 0), k.trim)
    else:
        prism(d, w, rise, (0, mid, h), k.walls, rot=(0, 0, math.pi / 2))
        roof_slopes(span=w, rise=rise, length=d + 0.35, eave_z=h, centre_y=mid, material=k.roof, along="y", overhang=overhang)
    return mid


def window(k, x, z, front, w=0.6, h=0.62, shutters=None, sill=True, panes=True):
    box((w, 0.05, h), (x, front - 0.02, z), k.glass)
    if k.night:
        return
    box((w + 0.12, 0.07, 0.07), (x, front - 0.04, z + h), k.trim)
    if sill:
        box((w + 0.16, 0.1, 0.06), (x, front - 0.06, z - 0.06), k.trim)
    if panes:
        box((0.05, 0.06, h), (x, front - 0.04, z), k.trim)
        box((w, 0.06, 0.05), (x, front - 0.04, z + h / 2), k.trim)
    if shutters is not None:
        for side in (-1, 1):
            box((0.18, 0.05, h + 0.04), (x + side * (w / 2 + 0.14), front - 0.03, z - 0.02), shutters)


def door(k, x, front, w=0.6, h=1.1, fanlight=False):
    box((w, 0.05, h), (x, front - 0.02, 0), k.door)
    if fanlight:
        box((w * 0.7, 0.05, 0.2), (x, front - 0.04, h - 0.3), k.glass)
    if not k.night:
        box((w + 0.12, 0.07, 0.08), (x, front - 0.04, h), k.trim)
        box((0.05, 0.03, 0.05), (x + w * 0.32, front - 0.06, h * 0.48), _m("knob", "e8b83a"))


def awning(k, x, w, z, front, colours, depth=0.55, drop=0.3):
    """A striped shop awning sloping out over the front."""
    if k.night:
        return
    n = max(4, int(w / 0.22))
    stripe = w / n
    angle = math.atan2(drop, depth)
    for i in range(n):
        m = _m(f"awning_{colours[i % 2]}", colours[i % 2])
        box((stripe + 0.002, math.hypot(depth, drop), 0.05), (x - w / 2 + stripe * (i + 0.5), front - depth / 2, z - drop / 2),
            m, rot=(angle, 0, 0))
        # A scalloped valance along the front edge.
        blob(stripe * 0.5, (x - w / 2 + stripe * (i + 0.5), front - depth - 0.02, z - drop - 0.06), m,
             squash=(1, 0.4, 0.7), seed=i)


def sign_board(k, x, z, front, w, h, board="2f5a3a", ink="f2e6c8", rows=1):
    if k.night:
        return
    box((w, 0.07, h), (x, front - 0.05, z), _m(f"sign_{board}", board))
    box((w + 0.08, 0.06, 0.05), (x, front - 0.04, z + h), k.trim)
    ink_m = _m(f"ink_{ink}", ink)
    for r in range(rows):
        box((w * (0.7 - 0.15 * r), 0.075, h * 0.14), (x, front - 0.055, z + h * (0.55 - 0.3 * r) - h * 0.07 * (rows - 1)), ink_m)


def chimney(k, x, y, z, height=0.9):
    brick = k.solid("chimney_brick", "a24f3a", noise=0.15, noise_scale=20, tiles=("x", "z", 0.2, 0.12, 0.5, 0.03, 0.7))
    box((0.36, 0.36, height), (x, y, z), brick)
    box((0.44, 0.44, 0.08), (x, y, z + height), brick)


# ------------------------------------------------------------- the buildings

def village_house(style="a", night=False):
    """Two-storey village houses: a (cream walls, red roof), b (blue shutters,
    grey roof), c (a cottage with climbing roses)."""
    walls = {"a": "f2e6c8", "b": "e8ecef", "c": "f4ead8"}[style]
    roof = {"a": "b84a34", "b": "6a707a", "c": "8a5a3a"}[style]
    k = Kit(f"house_{style}", night, walls, "plaster" if style != "c" else "boards", roof=roof,
            door={"a": "4f7a4a", "b": "3f6a8a", "c": "a0583a"}[style])
    front = 0.6
    if style == "c":
        mid = house_body(k, 3.0, 2.0, 1.5, front, rise=1.3, ridge="x")
        door(k, -0.55, front)
        for x in (0.55,):
            window(k, x, 0.5, front, w=0.7)
        chimney(k, -0.9, mid + 0.4, 1.6)
        if not night:  # climbing roses round the door and up the wall
            leaf = _m("rose_leaf", "4f8a3a", noise=0.2, noise_scale=20, leaves=12.0)
            rose = _m("rose", "e8607a")
            for k_, (x, z) in enumerate(((-1.1, 0.3), (-1.0, 0.8), (-0.95, 1.2), (-0.15, 1.2), (0.05, 0.9), (1.2, 0.6), (1.25, 1.1))):
                blob(0.2, (x, front - 0.06, z), leaf, squash=(1.2, 0.4, 1), seed=k_)
                blob(0.05, (x + 0.06, front - 0.14, z + 0.05), rose, seed=k_)
                blob(0.04, (x - 0.07, front - 0.13, z - 0.06), rose, seed=k_ + 9)
        return
    mid = house_body(k, 3.2, 2.0, 2.3, front, rise=1.0, ridge="x")
    shutters = k.solid("shutters_b", "3f6a9a", lines=("z", 0.08, 0.02, 0.75)) if style == "b" else None
    door(k, 0.0 if style == "a" else -0.7, front, fanlight=True)
    xs = (-0.95, 0.95) if style == "a" else (0.4, 1.1)
    for x in xs:
        window(k, x, 0.45, front, w=0.55, shutters=shutters)
    for x in (-0.95, 0.0, 0.95):
        window(k, x, 1.45, front, w=0.5, h=0.55, shutters=shutters)
    chimney(k, 1.0, mid + 0.4, 2.4)
    if not night and style == "a":
        flowers = _m("box_flowers", "e8607a", noise=0.3, noise_scale=40)
        for x in (-0.95, 0.95):
            box((0.6, 0.14, 0.12), (x, front - 0.11, 0.3), _m("planter", "a0703f"))
            box((0.55, 0.1, 0.1), (x, front - 0.11, 0.42), flowers)


def seed_shop(night=False):
    k = Kit("seed_shop", night, "f2e6c8", "boards", roof="4f7a4a", door="4f7a4a")
    front = 0.7
    mid = house_body(k, 3.8, 2.2, 1.9, front, rise=1.1, ridge="x")
    door(k, -0.9, front, fanlight=True)
    window(k, 0.65, 0.4, front, w=1.6, h=0.85)
    awning(k, 0.4, 3.4, 1.55, front, ("4f9a4a", "f4f0e0"))
    sign_board(k, 0.0, 1.95, front + 0.4, 1.6, 0.36, board="4f7a4a", rows=1)
    if not night:  # seed racks outside: little shelves of colourful packets
        wood = _m("rack_wood", "a0703f")
        for rx in (-1.6, 1.6):
            box((0.55, 0.25, 0.75), (rx, front - 0.5, 0), wood)
            for row in range(3):
                for j in range(3):
                    c = ["e8607a", "f2c43a", "6cba3c", "e8742e", "8a6ad8"][(row * 3 + j + int(rx)) % 5]
                    box((0.13, 0.04, 0.17), (rx - 0.17 + j * 0.17, front - 0.63, 0.08 + row * 0.24), _m("packet_" + c, c))


def gas_station(night=False):
    """A little old filling station: a white office with a red stripe and a canopy on two posts."""
    k = Kit("gas", night, "f2efe8", "plaster", roof="c8483a", door="3f6a8a")
    front = 0.6
    box((2.4, 2.0, 1.6), (1.4, front + 1.0, 0), k.walls)
    red = k.solid("gas_red", "d8402e")
    box((2.44, 2.04, 0.18), (1.4, front + 1.0, 1.25), red)
    box((2.6, 2.2, 0.12), (1.4, front + 1.0, 1.6), red)
    door(k, 1.0, front)
    window(k, 2.1, 0.45, front, w=0.8, h=0.6)
    sign_board(k, 1.4, 1.75, front, 1.4, 0.4, board="d8402e", ink="f2efe8")
    # The canopy over the pumps.
    for x in (-2.2, -0.4):
        box((0.14, 0.14, 1.75), (x, front - 0.3, 0), k.solid("canopy_post", "e8e4dc"))
    box((2.6, 1.6, 0.2), (-1.3, front + 0.2, 1.75), k.solid("canopy_edge", "f2efe8"))
    box((2.5, 1.5, 0.08), (-1.3, front + 0.2, 1.95), k.solid("canopy_top", "c8483a", lines=("x", 0.3, 0.04, 0.8)))
    box((2.62, 0.05, 0.08), (-1.3, front - 0.61, 1.81), red)
    if night:
        box((2.2, 0.05, 0.06), (-1.3, front - 0.62, 1.72), k.glass)  # the canopy lights


def restaurant(night=False):
    """The Rusty Spoon: a cheerful diner with big windows, a red stripe and a spoon on the roof sign."""
    k = Kit("diner", night, "f2e6c8", "plaster", roof="4fa3a0", door="d8402e")
    front = 0.7
    mid = front + 1.1
    box((3.9, 2.2, 1.7), (0, mid, 0), k.walls)
    box((3.94, 2.24, 0.16), (0, mid, 0.25), k.solid("diner_red", "d8402e"))
    box((4.1, 2.4, 0.16), (0, mid, 1.7), k.roof)
    door(k, -1.2, front)
    for x in (-0.25, 0.65, 1.55):
        window(k, x, 0.55, front, w=0.75, h=0.7, sill=False)
    if not night:
        box((2.0, 0.1, 0.55), (0.3, mid - 0.6, 1.86), _m("diner_sign", "f2e6c8"))
        box((2.1, 0.09, 0.06), (0.3, mid - 0.6, 2.41), _m("diner_sign_edge", "d8402e"))
        box((1.5, 0.11, 0.14), (0.3, mid - 0.61, 2.05), _m("diner_ink", "d8402e"))
        for x in (-0.6, 1.2):
            box((0.08, 0.08, 0.2), (x, mid - 0.55, 1.86), k.dark)
        spoon = _m("spoon", "c8ccd2")
        stick((-1.0, mid - 0.6, 1.95), (-1.0, mid - 0.6, 2.45), 0.035, spoon, verts=5)
        blob(0.13, (-1.0, mid - 0.6, 2.5), spoon, squash=(0.8, 0.3, 1.2), seed=1)
    else:
        box((2.0, 0.1, 0.55), (0.3, mid - 0.6, 1.86), _m("glow_sign", "000000", emit=hexrgb("ff9a6a")))


def bakery(night=False):
    k = Kit("bakery", night, "a24f3a", "brick", roof="6a707a", door="5a3a24")
    front = 0.6
    mid = house_body(k, 3.2, 2.0, 2.2, front, rise=1.0, ridge="x")
    door(k, -0.9, front, fanlight=True)
    window(k, 0.55, 0.35, front, w=1.4, h=0.8)
    awning(k, 0.55, 1.6, 1.4, front, ("d8402e", "f4f0e0"), depth=0.45)
    for x in (-0.9, 0.55):
        window(k, x, 1.5, front, w=0.5, h=0.45)
    chimney(k, -1.0, mid + 0.3, 2.3)
    if not night:  # a hanging bread sign
        box((0.06, 0.4, 0.06), (1.5, front - 0.2, 1.8), k.dark)
        blob(0.22, (1.5, front - 0.4, 1.55), _m("bread_sign", "d8943a", noise=0.15, noise_scale=20, lines=("x", 0.12, 0.03, 0.7)),
             squash=(1.4, 0.5, 0.75), seed=2)
        # Loaves in the window.
        for j in range(4):
            blob(0.1, (0.0 + j * 0.36, front - 0.06, 0.45), _m("loaf", "d8943a"), squash=(1.5, 0.6, 0.8), seed=j)


def bank(night=False):
    """Valley Savings Bank: small and stone, four columns and a pediment."""
    k = Kit("bank", night, "c8c4ba", "stone", roof="6a707a", door="5a3a24")
    front = 0.9
    mid = front + 1.0
    box((3.2, 2.0, 2.0), (0, mid, 0), k.walls)
    box((3.4, 2.2, 0.2), (0, mid, 2.0), k.solid("bank_cornice", "e8e4dc"))
    box((3.3, 2.1, 0.3), (0, mid, 2.2), k.solid("bank_roof", "6a707a", noise=0.1, noise_scale=8, lines=("x", 0.3, 0.04, 0.75)))
    door(k, 0.0, front, w=0.7, h=1.25)
    for x in (-1.05, 1.05):
        window(k, x, 0.6, front, w=0.45, h=0.8, sill=False)
    if not night:
        col = _m("column", "f2efe6", lines=("z", 2.0, 0.0, 1.0))
        box((3.0, 0.7, 0.15), (0, front - 0.35, 0), _m("bank_steps", "b8b4aa"))
        for x in (-1.35, -0.55, 0.55, 1.35):
            cyl(0.12, 1.85, (x, front - 0.4, 0.15), col, verts=10)
        box((3.1, 0.6, 0.18), (0, front - 0.32, 2.0), _m("entablature", "f2efe6"))
        prism(3.1, 0.6, 0.45, (0, front - 0.32, 2.18), _m("pediment", "e8e4dc"))
        blob(0.12, (0, front - 0.64, 2.32), _m("gold", "e8b83a"), squash=(1, 0.4, 1), seed=1)


def town_shop(night=False):
    """Your own shop: a wooden shopfront with a blue awning and a big display window."""
    k = Kit("town_shop", night, "c8a06a", "boards", roof="7b5440", door="3f6a8a")
    front = 0.6
    mid = house_body(k, 3.2, 2.0, 2.1, front, rise=1.1, ridge="y")
    door(k, 0.95, front)
    window(k, -0.35, 0.35, front, w=1.6, h=0.85)
    awning(k, -0.35, 1.9, 1.45, front, ("3f6a9a", "f4f0e0"), depth=0.45)
    window(k, 0.0, 1.6, front, w=0.5, h=0.45)
    sign_board(k, 0.95, 1.35, front, 0.55, 0.3, board="7b5440")


def deli(night=False):
    k = Kit("deli", night, "f2e6c8", "plaster", roof="7b5440", door="4f7a4a")
    front = 0.6
    mid = house_body(k, 3.2, 2.0, 2.2, front, rise=1.0, ridge="x")
    door(k, 1.0, front, fanlight=True)
    window(k, -0.35, 0.35, front, w=1.7, h=0.8)
    awning(k, -0.35, 2.0, 1.4, front, ("3f8a4a", "f4f0e0"), depth=0.45)
    for x in (-0.9, 0.9):
        window(k, x, 1.5, front, w=0.5, h=0.45)
    if not night:  # cheeses and jars in the window
        cheese = _m("cheese", "f2c43a")
        for j, x in enumerate((-0.95, -0.55)):
            cyl(0.16, 0.12, (x, front - 0.08, 0.4), cheese, verts=10)
        for j, (x, c) in enumerate(((-0.1, "d8402e"), (0.15, "8a4ad8"), (0.4, "f2a83a"))):
            cyl(0.07, 0.18, (x, front - 0.08, 0.4), _m("jar_" + c, c), verts=8)


def livestock_market(night=False):
    """A big open red barn with a sign, pens out front and a little auction shed."""
    k = Kit("livestock", night, "b8432f", "boards", roof="5c6370", door="3a2a20")
    front = 1.2
    mid = front + 1.4
    box((4.2, 2.8, 2.0), (-0.6, mid, 0), k.walls)
    roof_slopes(span=2.8, rise=1.2, length=4.6, eave_z=2.0, centre_y=mid, material=k.roof)
    box((1.8, 0.06, 1.6), (-0.6, front - 0.02, 0), k.solid("barn_opening", "3a2a20"))
    for x in (-1.55, 0.35):
        box((0.12, 0.08, 1.7), (x, front - 0.04, 0), k.trim)
    box((2.0, 0.08, 0.12), (-0.6, front - 0.04, 1.6), k.trim)
    sign_board(k, -0.6, 2.2, front + 0.3, 2.0, 0.4, board="f2e6c8", ink="b8432f")
    # The auction shed on the right.
    box((1.6, 1.6, 1.2), (2.4, front + 1.2, 0), k.solid("auction_wood", "a0703f", lines=("z", 0.2, 0.03, 0.8)))
    box((1.9, 1.9, 0.1), (2.4, front + 1.2, 1.2), k.roof, rot=(math.radians(-8), 0, 0))
    window(k, 2.4, 0.5, front + 0.4, w=0.6, h=0.4)
    if not night:  # pens of fence out front, with straw
        fence = _m("pen_fence", "c8a06a")
        for x0, x1 in ((-2.7, -1.5), (0.3, 1.5)):
            for z in (0.25, 0.5):
                box((x1 - x0, 0.06, 0.07), ((x0 + x1) / 2, front - 1.0, z), fence)
            for x in np.linspace(x0, x1, 4):
                box((0.08, 0.08, 0.6), (x, front - 1.0, 0), fence)
            box((x1 - x0 - 0.1, 0.8, 0.04), ((x0 + x1) / 2, front - 0.55, 0), _m("straw", "e5c45b", noise=0.3, noise_scale=30))


def lumber_yard(night=False):
    """North Woods Lumber: a small office and stacks of sawn timber and logs."""
    k = Kit("lumber", night, "8a5a3a", "boards", roof="5c6370", door="4a3020")
    front = 0.8
    box((2.0, 1.8, 1.5), (1.4, front + 0.9, 0), k.walls)
    roof_slopes(span=1.8, rise=0.7, length=2.3, eave_z=1.5, centre_y=front + 0.9, material=k.roof)
    door(k, 1.0, front)
    window(k, 1.9, 0.5, front, w=0.5, h=0.45)
    sign_board(k, 1.4, 1.65, front - 0.05, 1.4, 0.3, board="f2e6c8", ink="5a3a24")
    if night:
        return
    plank = _m("timber", "e2b980", lines=("z", 0.1, 0.02, 0.8))
    for j in range(5):  # a stack of planks
        box((1.8, 0.9, 0.1), (-1.3, front + 0.6, j * 0.11), plank)
    box((0.08, 1.0, 0.6), (-0.4, front + 0.6, 0), _m("stack_post", "6a4a30"))
    bark = _m("bark", "7d5232", noise=0.15, noise_scale=12)
    ends = _m("log_ends", "e2b980")
    for row, xs in enumerate(((-2.2, -1.85, -1.5, -1.15, -0.8), (-2.02, -1.67, -1.32, -0.97), (-1.85, -1.5, -1.15))):
        for x in xs:
            z = 0.17 + row * 0.29
            stick((x, front - 0.3 + 1.2, z), (x, front - 0.3, z), 0.17, bark, verts=8)
            stick((x, front - 0.3, z), (x, front - 0.32, z), 0.14, ends, verts=8)


def market_stall(night=False):
    """A farmers' market stall: a striped awning on four posts over a counter of produce."""
    k = Kit("stall", night, "a0703f", "boards")
    post = k.solid("stall_post", "a0703f")
    for x in (-0.95, 0.95):
        for y in (0.0, 1.0):
            box((0.08, 0.08, 1.5), (x, y, 0), post)
    awning(k, 0.0, 2.1, 1.75, 0.0 + 0.2, ("d8402e", "f4f0e0"), depth=1.3, drop=0.3)
    box((1.9, 0.6, 0.7), (0, 0.3, 0), k.solid("counter", "c8a06a", lines=("x", 0.2, 0.03, 0.75)))
    if not night:
        _produce_crates(0.0, 0.25, 0.7)


def _produce_crates(x, y, z):
    crate = _m("crate_wood", "a0703f", lines=("z", 0.1, 0.02, 0.78))
    for j, (dx, c) in enumerate(((-0.6, "e8742e"), (-0.2, "e0332a"), (0.2, "6cba3c"), (0.6, "f2c43a"))):
        box((0.36, 0.34, 0.14), (x + dx, y, z), crate)
        for t in range(4):
            blob(0.07, (x + dx - 0.09 + (t % 2) * 0.18, y - 0.06 + (t // 2) * 0.1, z + 0.18), _m("produce_" + c, c), seed=j * 4 + t)


# -------------------------------------------------------------------- props

def for_rent_sign():
    post = _m("sign_post", "8a6a48")
    stick((0, 0, 0), (0, 0, 1.0), 0.045, post, verts=5)
    box((0.7, 0.05, 0.4), (0, -0.05, 0.6), _m("rent_board", "c8a06a", lines=("z", 0.1, 0.02, 0.85)))
    ink = _m("rent_ink", "5a3a24")
    for r, w in enumerate((0.5, 0.36)):
        box((w, 0.055, 0.06), (0, -0.055, 0.88 - r * 0.15), ink)


def open_sign():
    """A chalkboard A-frame saying OPEN, with a carrot drawn on it."""
    frame_m = _m("aframe", "a0703f")
    board = _m("chalkboard", "2f3a34")
    for side in (-1, 1):
        box((0.5, 0.04, 0.75), (0, side * 0.12, 0), board, rot=(side * math.radians(14), 0, 0))
    box((0.56, 0.05, 0.05), (0, -0.2, 0.72), frame_m)
    chalk = _m("chalk", "f2efe6")
    box((0.34, 0.045, 0.07), (0, -0.21, 0.55), chalk, rot=(math.radians(14), 0, 0))
    box((0.16, 0.045, 0.05), (-0.03, -0.24, 0.32), _m("chalk_carrot", "f08a3a"), rot=(math.radians(14), 0, math.radians(20)))
    box((0.06, 0.045, 0.06), (0.07, -0.24, 0.36), _m("chalk_leaf", "6cba3c"), rot=(math.radians(14), 0, 0))


def gas_pump():
    red = _m("pump_red", "d8402e")
    box((0.42, 0.32, 1.05), (0, 0.1, 0.05), red, bevel=0.03)
    box((0.5, 0.4, 0.06), (0, 0.1, 0), _m("pump_base", "3b3a40"))
    box((0.3, 0.04, 0.22), (0, -0.07, 0.62), _m("pump_dial", "f2efe6"))
    blob(0.17, (0, 0.1, 1.25), _m("pump_globe", "f2efe6"), squash=(1, 0.8, 1), subdiv=2, seed=1)
    stick((0.21, 0.0, 0.7), (0.32, -0.05, 0.3), 0.03, _m("hose", "2b2a2e"), verts=5)
    box((0.06, 0.08, 0.16), (0.24, -0.05, 0.62), _m("nozzle", "9a9a96"))


def market_goods():
    basket = _m("basket", "c89a5a", lines=("z", 0.05, 0.015, 0.8))
    for j, (x, c) in enumerate(((-0.45, "e0332a"), (0.0, "f2c43a"), (0.45, "6cba3c"))):
        cyl(0.2, 0.22, (x, 0.1, 0), basket, verts=10, radius2=0.24)
        for t in range(5):
            a = t * 1.3
            blob(0.07, (x + math.cos(a) * 0.1, 0.1 + math.sin(a) * 0.06, 0.26), _m("goods_" + c, c), seed=j * 5 + t)
    _produce_crates(0.05, 0.45, 0.0)


# ---------------------------------------------------------------- workshops

def workshop(kind):
    """The workshops standing on the farm (1.1 × 1.4 tiles each)."""
    wood = _m("ws_wood", "a0703f", noise=0.1, lines=("x", 0.2, 0.03, 0.78), grain=0.1)
    dark = _m("ws_dark", "6b4526")
    iron = _m("ws_iron", "6a6e74")
    if kind == "sawhorse":
        for x in (-0.3, 0.3):
            for side in (-1, 1):
                stick((x, side * 0.18, 0), (x, 0, 0.5), 0.035, wood, verts=5)
        stick((-0.42, 0, 0.55), (0.42, 0, 0.55), 0.13, _m("bark", "7d5232", noise=0.15, noise_scale=12), verts=8)
        box((0.5, 0.02, 0.14), (0.15, -0.16, 0.5), _m("saw", "c8ccd2"), rot=(0, math.radians(-30), 0))
        box((0.12, 0.05, 0.1), (0.38, -0.16, 0.66), dark)
        for j in range(3):
            box((0.3, 0.12, 0.04), (-0.2 + j * 0.05, -0.3, j * 0.04), _m("plank", "e2b980"))
    elif kind == "mill":
        box((0.7, 0.5, 0.45), (0, 0.1, 0), wood)
        stone = _m("millstone", "a7a39a", noise=0.2, noise_scale=12)
        cyl(0.3, 0.12, (0, 0.1, 0.45), stone, verts=14)
        cyl(0.3, 0.12, (0, 0.1, 0.58), stone, verts=14)
        stick((0.18, 0.0, 0.7), (0.2, -0.02, 0.92), 0.025, dark, verts=5)
        blob(0.12, (-0.3, -0.18, 0.06), _m("flour_sack", "f2ead8"), squash=(1, 0.9, 1.2), seed=1)
    elif kind == "beehive":
        box((0.5, 0.4, 0.3), (0, 0.1, 0), dark)
        for j, c in enumerate(("f2e6c8", "f2c43a", "f2e6c8")):
            box((0.52, 0.44, 0.24), (0, 0.1, 0.3 + j * 0.25), _m("hive_" + c, c, lines=("z", 0.24, 0.02, 0.8)))
        prism(0.62, 0.52, 0.18, (0, 0.1, 1.05), _m("hive_roof", "b8432f"))
        box((0.2, 0.05, 0.04), (0, -0.13, 0.33), _m("hive_door", "3a2a20"))
        bee = _m("bee", "f2c43a")
        for j, (x, z) in enumerate(((-0.35, 0.9), (0.33, 1.1), (0.4, 0.7))):
            blob(0.035, (x, -0.2, z), bee, seed=j)
    elif kind == "jam_kitchen":
        box((0.75, 0.45, 0.55), (0, 0.15, 0), _m("stove", "3b3a40"))
        box((0.2, 0.05, 0.15), (0, -0.09, 0.12), _m("fire", "f08a3a"))
        cyl(0.22, 0.25, (0, 0.15, 0.55), _m("copper", "c87a3a"), verts=12)
        cyl(0.19, 0.02, (0, 0.15, 0.79), _m("jam", "c8283a"), verts=12)
        stick((0.25, 0.3, 0.55), (0.25, 0.3, 1.1), 0.05, iron, verts=6)
        for j, c in enumerate(("c8283a", "6a3a9a", "f08a3a")):
            cyl(0.06, 0.14, (-0.4 + j * 0.12, -0.25, 0), _m("jar_" + c, c), verts=8)
    elif kind == "drying_rack":
        for x in (-0.38, 0.38):
            box((0.06, 0.06, 1.0), (x, 0.1, 0), wood)
        for z in (0.55, 0.9):
            stick((-0.4, 0.1, z), (0.4, 0.1, z), 0.025, wood, verts=5)
            for j in range(4):
                c = ["6cba3c", "a8c45a", "c89a5a", "8a6a48"][j]
                stick((-0.27 + j * 0.18, 0.08, z), (-0.27 + j * 0.18, 0.06, z - 0.22), 0.05, _m("herb_" + c, c), verts=5, tip_radius=0.02)
    elif kind == "pickling_crock":
        crock = _m("crock", "8a5a3a", noise=0.08, noise_scale=10)
        cyl(0.3, 0.55, (0, 0.1, 0), crock, verts=14, radius2=0.26)
        cyl(0.24, 0.06, (0, 0.1, 0.55), _m("crock_lid", "6b4526"), verts=12)
        blob(0.05, (0, 0.1, 0.66), _m("crock_knob", "6b4526"), seed=1)
        box((0.6, 0.06, 0.08), (0, -0.2, 0.3), _m("crock_band", "f2e6c8"))
        for j, c in enumerate(("c8b46a", "6cba3c")):
            cyl(0.07, 0.18, (0.38, -0.15 + j * 0.15, 0), _m("pickle_" + c, c), verts=8)
    elif kind == "cheese_press":
        box((0.7, 0.45, 0.3), (0, 0.1, 0), wood)
        for x in (-0.3, 0.3):
            box((0.07, 0.07, 1.0), (x, 0.1, 0.3), wood)
        box((0.7, 0.12, 0.1), (0, 0.1, 1.2), wood)
        stick((0, 0.1, 0.65), (0, 0.1, 1.25), 0.035, iron, verts=6)
        box((0.4, 0.05, 0.05), (0, 0.1, 1.33), iron)
        cyl(0.2, 0.18, (0, 0.1, 0.3), _m("cheese", "f2c43a"), verts=12)
        box((0.5, 0.35, 0.06), (0, 0.1, 0.5), wood)
    elif kind == "juice_press":
        barrel = _m("press_barrel", "a0703f", lines=("x", 0.08, 0.02, 0.75))
        cyl(0.28, 0.45, (0, 0.12, 0.1), barrel, verts=14)
        for z in (0.18, 0.45):
            cyl(0.29, 0.04, (0, 0.12, z), iron, verts=14)
        box((0.7, 0.45, 0.1), (0, 0.12, 0), wood)
        stick((0, 0.12, 0.55), (0, 0.12, 1.1), 0.04, iron, verts=6)
        stick((-0.3, 0.12, 1.0), (0.3, 0.12, 1.0), 0.03, dark, verts=5)
        cyl(0.11, 0.16, (0.38, -0.12, 0), _m("juice_bucket", "c87a3a"), verts=10)
        cyl(0.09, 0.01, (0.38, -0.12, 0.155), _m("juice", "f28a2a"), verts=10)
    elif kind == "oil_press":
        box((0.65, 0.45, 0.35), (0, 0.1, 0), iron)
        box((0.07, 0.07, 0.75), (-0.27, 0.1, 0.35), iron)
        box((0.07, 0.07, 0.75), (0.27, 0.1, 0.35), iron)
        box((0.65, 0.12, 0.1), (0, 0.1, 1.1), iron)
        stick((0, 0.1, 0.45), (0, 0.1, 1.2), 0.04, _m("screw", "c8ccd2"), verts=6)
        stick((-0.28, 0.1, 1.25), (0.28, 0.1, 1.25), 0.03, dark, verts=5)
        cyl(0.08, 0.2, (0.38, -0.15, 0), _m("oil_jug", "f2c43a"), verts=10, radius2=0.05)
        blob(0.12, (-0.35, -0.15, 0.08), _m("sunflower_seeds", "4a4038"), squash=(1.2, 1, 0.6), seed=2)
    elif kind == "loom":
        for x in (-0.42, 0.42):
            box((0.07, 0.4, 1.05), (x, 0.1, 0), wood)
        for z in (0.35, 1.0):
            stick((-0.45, 0.1, z), (0.45, 0.1, z), 0.03, wood, verts=5)
        box((0.74, 0.03, 0.6), (0, 0.08, 0.38), _m("cloth", "e8607a", lines=("z", 0.06, 0.02, 0.75)))
        box((0.8, 0.12, 0.06), (0, -0.05, 0.4), dark)
        blob(0.1, (0.35, -0.2, 0.08), _m("yarn", "f2ead8"), seed=3)
    elif kind == "smokehouse":
        shed = _m("smoke_wood", "6b4526", noise=0.1, lines=("x", 0.15, 0.03, 0.75))
        box((0.75, 0.6, 0.85), (0, 0.15, 0), shed)
        prism(0.85, 0.7, 0.3, (0, 0.15, 0.85), _m("smoke_roof", "5c6370"))
        box((0.12, 0.12, 0.35), (0.22, 0.3, 0.95), _m("smoke_pipe", "3b3a40"))
        box((0.4, 0.04, 0.5), (-0.1, -0.16, 0.05), _m("smoke_door", "3a2a20"))
        fish = _m("smoked_fish", "c87a3a")
        for j in range(2):
            blob(0.06, (0.27, -0.2, 0.5 - j * 0.16), fish, squash=(0.6, 0.4, 1.4), seed=j)


WORKSHOPS = ["sawhorse", "mill", "beehive", "jam_kitchen", "drying_rack", "pickling_crock", "cheese_press", "juice_press",
             "oil_press", "loom", "smokehouse"]


def reeds(seed=41):
    """A clump of reeds and bulrushes for the water's edge."""
    rng = np.random.default_rng(seed)
    blades = [_m("reed", "6a9a3a"), _m("reed_l", "8ab84a")]
    head = _m("bulrush", "6b4526")
    for k in range(11):
        x, y = rng.uniform(-0.28, 0.28), rng.uniform(-0.12, 0.12)
        h = rng.uniform(0.55, 1.0)
        lean = rng.uniform(-0.12, 0.12)
        stick((x, y, 0), (x + lean, y, h), 0.022, blades[k % 2], verts=4, tip_radius=0.004)
        if k % 4 == 0:
            cyl(0.035, 0.16, (x + lean * 0.8, y, h * 0.8), head, verts=6)
