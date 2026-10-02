"""People in the new look: the farmer, the farmhands and the villagers, one
adjustable figure posed per frame. Same conventions as models.py (1 unit =
1 tile, foot point at the origin, x east, y north = away from the camera,
z up). The figure is built facing the camera (-y) and turned for "up"
(seen from behind) and "side" (facing left; the game mirrors it for right).

Sprites are 0.9 × 1.5 tiles (29 × 48 px), so everything is chunky on
purpose: a big head, short limbs, and tools that stay within ±0.42 of the
centre (the side view would cut off anything longer)."""

import math

from acres_art import blob, box, cyl, empty, hexrgb, mat, stick

SKIN = "f2c6a0"
LOOKS = {
    "farmer": dict(hat="straw", hair="6a4228", shirt="c8483a", check=True, pants="3e64a8", bib=True, boots="5a3a24"),
    "worker1": dict(hat="cap", cap="3f8a4a", hair="4a3020", shirt="c8483a", pants="7a5232", bib=True, boots="4a3024"),
    "worker2": dict(hat=None, hair="e8c060", ponytail=True, shirt="4a7ac8", pants="4f8a4a", bib=True, boots="5a3a24"),
    "worker3": dict(hat="straw", hair="7a4a2a", beard=True, shirt="f2efe6", pants="3e5a8a", bib=True, boots="4a3024"),
    "villager1": dict(hat=None, hair="3a2a24", long_hair=True, shirt="3f9a9a", pants="7a5232", boots="3a2a24"),
    "villager2": dict(hat="cap", cap="c8483a", hair="5a3a24", shirt="d8a83a", pants="3e5a8a", boots="3a2a24"),
    "arne": dict(hat="straw", hair="d8d8d4", beard=True, shirt="4f8a4a", pants="3e64a8", bib=True, boots="5a3a24",
                 skin="eebc96"),
    "villager3": dict(hat=None, hair="ecebf0", bun=True, shirt="a890d0", skirt="8a8a90", boots="5a4a4a", skin="f0c8b0"),
}

# Hands and feet per pose, in the figure's own frame (facing -y): x to the
# figure's left (screen right when facing the camera), y forward is negative.
# "feet": forward swing of the (left, right) leg in degrees.
POSES = {
    "idle": dict(feet=(0, 0), hands=((0.27, 0.0, 0.5), (-0.27, 0.0, 0.5))),
    "walk1": dict(feet=(24, -24), hands=((0.26, 0.12, 0.52), (-0.26, -0.13, 0.54))),
    "walk2": dict(feet=(-24, 24), hands=((0.26, -0.13, 0.54), (-0.26, 0.12, 0.52))),
    "hoe1": dict(feet=(12, -8), hands=((0.08, -0.2, 1.0), (-0.06, -0.18, 0.82)), tool=("hoe", "up")),
    "hoe2": dict(feet=(12, -8), hands=((0.08, -0.3, 0.62), (-0.04, -0.24, 0.74)), tool=("hoe", "down"), lean=12),
    "can1": dict(feet=(6, -6), hands=((0.2, -0.26, 0.6), (-0.27, 0.0, 0.5)), tool=("can", "hold")),
    "can2": dict(feet=(6, -6), hands=((0.2, -0.3, 0.66), (-0.27, 0.0, 0.5)), tool=("can", "pour")),
    "hands1": dict(feet=(10, -10), hands=((0.14, -0.3, 0.34), (-0.14, -0.3, 0.38)), lean=12, crouch=0.1),
    "hands2": dict(feet=(10, -10), hands=((0.08, -0.34, 0.22), (-0.1, -0.3, 0.28)), lean=16, crouch=0.14),
    "axe1": dict(feet=(14, -10), hands=((0.12, 0.02, 1.08), (0.04, 0.04, 0.96)), tool=("axe", "up")),
    "axe2": dict(feet=(14, -10), hands=((0.05, -0.32, 0.72), (-0.03, -0.26, 0.72)), tool=("axe", "swing"), lean=10),
    "rod1": dict(feet=(8, -8), hands=((0.12, -0.24, 0.72), (0.02, -0.18, 0.62)), tool=("rod", "cast")),
    "rod2": dict(feet=(8, -8), hands=((0.12, -0.16, 0.86), (0.02, -0.12, 0.76)), tool=("rod", "pull"), lean=-8),
}

FACING = {"down": 0.0, "up": 180.0, "side": -90.0}


def _m(name, hexc, **kw):
    return mat(name, hexrgb(hexc), **kw)


def person(look="farmer", facing="down", pose="idle"):
    L = LOOKS[look]
    P = POSES[pose]
    skin = _m("skin_" + L.get("skin", SKIN), L.get("skin", SKIN))
    shirt = _m(f"shirt_{look}", L["shirt"], **({"lines": ("z", 0.07, 0.025, 0.72)} if L.get("check") else {}))
    pants = _m(f"pants_{look}", L.get("pants") or L["skirt"], noise=0.06, noise_scale=20)
    boots = _m(f"boots_{look}", L["boots"])
    hair = _m(f"hair_{look}", L["hair"], noise=0.1, noise_scale=30)
    eye = _m("eye", "2a1e18")
    root = empty("person")
    root.rotation_euler = (0, 0, math.radians(FACING[facing]))
    parts = []

    def add(obj):
        obj.parent = root
        parts.append(obj)
        return obj

    crouch = P.get("crouch", 0.0)
    lean = math.radians(P.get("lean", 0))
    hip_z = 0.46 - crouch
    # Legs and boots: each leg swings about the hip (forward = -y).
    for side, swing in zip((1, -1), P["feet"]):
        a = math.radians(swing)
        foot = (side * 0.1, -math.sin(a) * 0.4, max(0.08, hip_z - math.cos(a) * 0.4))
        if L.get("skirt"):
            add(stick((side * 0.08, 0, hip_z), foot, 0.045, skin, verts=6))
        else:
            add(stick((side * 0.1, 0, hip_z), foot, 0.08, pants, verts=6))
        add(box((0.14, 0.2, 0.11), (foot[0], foot[1] - 0.03, foot[2] - 0.08), boots))
    # Body, leaning forward from the hips for some poses.
    body = empty("body", (0, 0, hip_z))
    body.parent = root
    body.rotation_euler = (lean, 0, 0)

    def addb(obj):
        obj.parent = body
        parts.append(obj)
        return obj

    # (Positions below are relative to the hips.)
    if L.get("skirt"):
        addb(cyl(0.24, 0.32, (0, 0, -0.14), pants, verts=10, radius2=0.18))
    else:
        addb(box((0.38, 0.24, 0.16), (0, 0, -0.04), pants))  # seat of the trousers
    addb(box((0.4, 0.26, 0.4), (0, 0, 0.08), shirt, bevel=0.03))
    if L.get("bib"):
        addb(box((0.26, 0.03, 0.22), (0, -0.13, 0.1), pants))
        for x in (-0.11, 0.11):
            addb(box((0.05, 0.03, 0.2), (x, -0.135, 0.3), pants))
            addb(box((0.05, 0.03, 0.2), (x, 0.135, 0.28), pants))
    # Head.
    head_z = 0.66
    addb(blob(0.21, (0, 0, head_z), skin, squash=(1, 0.95, 1), subdiv=2, seed=1, jitter=0.0))
    for x in (-0.075, 0.075):
        addb(box((0.045, 0.02, 0.06), (x, -0.2, head_z - 0.03), eye))
    addb(box((0.05, 0.03, 0.02), (0, -0.205, head_z - 0.11), _m("mouth", "b85a4a")))
    # Hair: a cap of hair over the top and back, longer for some looks.
    addb(blob(0.215, (0, 0.04, head_z + 0.05), hair, squash=(1.04, 1.0, 0.92), subdiv=2, seed=2, jitter=0.02))
    if L.get("long_hair"):
        addb(box((0.4, 0.14, 0.38), (0, 0.11, head_z - 0.32), hair, bevel=0.04))
    if L.get("ponytail"):
        addb(stick((0, 0.2, head_z + 0.05), (0, 0.32, head_z - 0.2), 0.07, hair, verts=6, tip_radius=0.04))
    if L.get("bun"):
        addb(blob(0.1, (0, 0.14, head_z + 0.18), hair, seed=3))
    if L.get("beard"):
        addb(blob(0.14, (0, -0.12, head_z - 0.12), hair, squash=(1.2, 0.7, 0.9), seed=4))
    hat = L.get("hat")
    if hat == "straw":
        # Worn tipped back, so the face shows under the brim from the game's high camera.
        straw = _m("straw_hat", "e8c45a", noise=0.15, noise_scale=40)
        brim = empty("hat", (0, 0.05, head_z + 0.13))
        brim.parent = body
        brim.rotation_euler = (math.radians(-28), 0, 0)
        parts.append(cyl(0.29, 0.035, (0, 0, 0), straw, verts=14, parent=brim))
        parts.append(cyl(0.17, 0.14, (0, 0.02, 0.02), straw, verts=12, radius2=0.14, parent=brim))
        parts.append(cyl(0.175, 0.04, (0, 0.02, 0.03), _m("hat_band", "c8483a"), verts=12, parent=brim))
    elif hat == "cap":
        cap = _m("cap_" + look, L["cap"])
        addb(blob(0.22, (0, 0.03, head_z + 0.11), cap, squash=(1.0, 1.0, 0.6), subdiv=2, seed=5, jitter=0.0))
        visor = addb(box((0.24, 0.13, 0.03), (0, -0.19, head_z + 0.12), cap))
        visor.rotation_euler = (math.radians(-18), 0, 0)
    # Arms: shoulder to hand, with a hand at the end.
    for side, hand in zip((1, -1), P["hands"]):
        shoulder = (side * 0.23, 0, 0.42)
        h = (hand[0], hand[1], hand[2] - hip_z)
        # Hands given in the figure's frame; undo the lean so they land where asked.
        hy = h[1] * math.cos(lean) + h[2] * math.sin(lean)
        hz = -h[1] * math.sin(lean) + h[2] * math.cos(lean)
        h = (h[0], hy, hz)
        elbow = ((shoulder[0] + h[0]) / 2 + side * 0.03, (shoulder[1] + h[1]) / 2, (shoulder[2] + h[2]) / 2)
        addb(stick(shoulder, elbow, 0.065, shirt, verts=6))
        addb(stick(elbow, h, 0.055, shirt if L.get("long_sleeves", True) else skin, verts=6))
        addb(blob(0.06, h, skin, subdiv=1, seed=6))
    tool = P.get("tool")
    if tool:
        _tool(tool, P["hands"][0], add)
    return root


def _tool(tool, hand, add):
    """Tools held in the first hand, in the figure's frame (facing -y)."""
    kind, phase = tool
    wood = _m("tool_wood", "a07a4a")
    iron = _m("tool_iron", "8a9098")
    hx, hy, hz = hand
    if kind == "hoe":
        if phase == "up":
            top = (hx + 0.02, hy + 0.1, hz + 0.45)
            add(stick((hx, hy + 0.05, hz - 0.25), top, 0.025, wood, verts=5))
            add(box((0.06, 0.2, 0.06), (top[0], top[1] - 0.08, top[2] - 0.03), iron))
        else:
            tip = (hx, -0.42, 0.06)
            add(stick((hx, hy + 0.12, hz + 0.18), tip, 0.025, wood, verts=5))
            add(box((0.07, 0.06, 0.18), (tip[0], tip[1] - 0.02, 0.0), iron))
    elif kind == "can":
        green = _m("can_green", "4a8ac8", noise=0.08, noise_scale=20)
        pour = phase == "pour"
        at = (hx + 0.02, hy - 0.08, hz - 0.18)
        can = add(cyl(0.11, 0.2, at, green, verts=10))
        spout = add(stick((at[0], at[1] - 0.08, at[2] + 0.12), (at[0], at[1] - 0.28, at[2] + (0.04 if pour else 0.24)), 0.025,
                          green, verts=5))
        if pour:
            can.rotation_euler = (math.radians(28), 0, 0)
            water = _m("water_drop", "8ccaf0")
            for k, (dy, dz) in enumerate(((-0.34, 0.0), (-0.36, -0.1), (-0.33, -0.2), (-0.38, -0.28))):
                add(blob(0.025, (at[0] + 0.02 * (k % 2), at[1] + dy, at[2] + dz), water, seed=k))
    elif kind == "axe":
        if phase == "up":
            head = (hx + 0.08, hy + 0.2, hz + 0.4)
            add(stick((hx, hy - 0.02, hz - 0.12), head, 0.028, wood, verts=5))
            add(box((0.05, 0.18, 0.13), (head[0], head[1] + 0.02, head[2] - 0.05), iron))
        else:
            head = (hx + 0.06, -0.42, hz - 0.04)
            add(stick((hx, hy + 0.1, hz), head, 0.028, wood, verts=5))
            add(box((0.06, 0.12, 0.16), (head[0], head[1] - 0.03, head[2] - 0.08), iron))
    elif kind == "rod":
        rod = _m("rod_bamboo", "d8b46a")
        line = _m("rod_line", "f2efe6")
        if phase == "cast":
            tip = (hx + 0.06, -0.42, 1.5)
            add(stick((hx, hy + 0.08, hz - 0.08), tip, 0.02, rod, verts=4, tip_radius=0.01))
            add(stick(tip, (tip[0], tip[1] - 0.02, 0.6), 0.006, line, verts=3))
        else:
            tip = (hx + 0.04, -0.3, 1.45)
            mid = (hx + 0.03, -0.22, 1.22)
            add(stick((hx, hy + 0.08, hz - 0.08), mid, 0.02, rod, verts=4, tip_radius=0.015))
            add(stick(mid, tip, 0.015, rod, verts=4, tip_radius=0.01))
            add(stick(tip, (tip[0], -0.42, 0.7), 0.006, line, verts=3))
            add(blob(0.05, (tip[0], -0.42, 0.66), _m("fish_catch", "7ab0d8"), squash=(0.6, 0.6, 1.4), seed=1))


FARMER_POSES = ["idle", "walk1", "walk2", "hoe1", "hoe2", "can1", "can2", "hands1", "hands2", "axe1", "axe2", "rod1", "rod2"]
WORKER_POSES = ["idle", "walk1", "walk2", "can1", "can2", "hands1", "hands2"]
VILLAGER_POSES = ["idle", "walk1", "walk2"]
