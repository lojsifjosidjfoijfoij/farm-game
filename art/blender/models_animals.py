"""Farm animals in the new look: one adjustable four-legged (or two-legged)
body per species, posed per frame (idle, two walk steps, eating, asleep).
Each faces left (-x); the game mirrors it to face right. Same conventions as
models.py (1 unit = 1 tile, foot point at the origin, z up)."""

import math

from acres_art import blob, box, cyl, hexrgb, mat, stick


def _m(name, hexc, **kw):
    return mat(name, hexrgb(hexc), **kw)


# Body sizes in tiles; colours as hex.
SPECIES = {
    "cow": dict(length=1.25, depth=0.6, height=0.58, body_z=0.72, leg=0.5, leg_r=0.08, head_r=0.25, neck=0.3,
                body="f4f0e8", patch="7a4a2e", legs="f4f0e8", hoof="3a2a24", muzzle="e8a8a0", horns="efe6d2",
                ears=True, tail=True),
    "calf": dict(length=0.8, depth=0.4, height=0.4, body_z=0.5, leg=0.36, leg_r=0.06, head_r=0.2, neck=0.18,
                 body="c88a5a", patch="f4f0e8", legs="c88a5a", hoof="3a2a24", muzzle="f0b8b0", ears=True, tail=True),
    "sheep": dict(length=0.85, depth=0.55, height=0.52, body_z=0.55, leg=0.34, leg_r=0.05, head_r=0.17, neck=0.18,
                  body="f2ead8", wool=True, legs="3a3230", hoof="2a2220", face="3a3230", ears=True, tail=False),
    "lamb": dict(length=0.55, depth=0.38, height=0.36, body_z=0.4, leg=0.26, leg_r=0.04, head_r=0.14, neck=0.12,
                 body="f8f2e6", wool=True, legs="4a4240", hoof="2a2220", face="4a4240", ears=True, tail=False),
    "pig": dict(length=0.9, depth=0.55, height=0.48, body_z=0.42, leg=0.22, leg_r=0.06, head_r=0.22, neck=0.05,
                body="f2a8a8", legs="f2a8a8", hoof="b86a6a", snout="e88a8a", mud="8a6448", ears=True, curly=True),
    "piglet": dict(length=0.48, depth=0.3, height=0.26, body_z=0.24, leg=0.13, leg_r=0.035, head_r=0.13, neck=0.03,
                   body="f6b8b8", legs="f6b8b8", hoof="c87a7a", snout="ec9a9a", ears=True, curly=True),
    "goat": dict(length=0.8, depth=0.42, height=0.42, body_z=0.6, leg=0.42, leg_r=0.045, head_r=0.17, neck=0.25,
                 body="f6f2ea", legs="f6f2ea", hoof="5a4a40", horns="b8a890", beard=True, ears=True, tail=True),
    "goat_kid": dict(length=0.5, depth=0.28, height=0.28, body_z=0.42, leg=0.3, leg_r=0.035, head_r=0.13, neck=0.15,
                     body="e8dcc8", legs="e8dcc8", hoof="5a4a40", ears=True, tail=True),
}


def animal(kind, pose="idle"):
    if kind in ("chicken", "chick"):
        return _bird(kind, pose)
    S = SPECIES[kind]
    body_m = _m(f"{kind}_body", S["body"], noise=0.08 if not S.get("wool") else 0.2, noise_scale=14,
                **({"leaves": 9.0} if S.get("wool") else {}))
    legs_m = _m(f"{kind}_legs", S["legs"])
    hoof_m = _m(f"{kind}_hoof", S["hoof"])
    eye = _m("eye", "1e1814")
    L, D, Hh = S["length"], S["depth"], S["height"]
    asleep = pose == "sleep"
    body_z = S["leg_r"] * 1.5 + Hh / 2 if asleep else S["body_z"]
    cx = 0.08 * L  # the body sits a little behind the foot point, the head in front
    # Legs: front pair at -x, back pair at +x; a walk swings opposite corners together.
    if not asleep:
        swing = {"walk1": (20, -20), "walk2": (-20, 20)}.get(pose, (0, 0))
        for k, (lx, ly) in enumerate(((-L * 0.32, -D * 0.22), (L * 0.32, -D * 0.22), (-L * 0.32, D * 0.22), (L * 0.32, D * 0.22))):
            a = math.radians(swing[0] if k in (0, 3) else swing[1])
            top = (cx + lx, ly, body_z - Hh * 0.3)
            foot = (top[0] - math.sin(a) * S["leg"], ly, 0.04)
            stick(top, foot, S["leg_r"], legs_m, verts=6)
            cyl(S["leg_r"] * 1.15, 0.06, (foot[0], foot[1], 0), hoof_m, verts=6)
    # Body.
    if S.get("wool"):
        blob(Hh * 0.55, (cx, 0, body_z), body_m, squash=(L / Hh * 0.95, D / Hh, 1.0), subdiv=2, seed=1, jitter=0.06)
        for k in range(7):
            a = k * 2 * math.pi / 7
            blob(Hh * 0.3, (cx + math.cos(a) * L * 0.38, math.sin(a) * D * 0.3 - 0.03, body_z + Hh * 0.2 + 0.03 * (k % 2)),
                 body_m, subdiv=2, seed=k + 2, jitter=0.12)
    else:
        blob(Hh * 0.55, (cx, 0, body_z), body_m, squash=(L / Hh * 0.95, D / Hh, 1.0), subdiv=2, seed=1, jitter=0.03)
    if S.get("patch"):
        patch = _m(f"{kind}_patch", S["patch"])
        for k, (px, pz, r) in enumerate(((0.15, 0.12, 0.2), (-0.2, 0.0, 0.16), (0.35, -0.05, 0.13))):
            blob(r * L, (cx + px * L, -D * 0.42, body_z + pz * Hh), patch, squash=(1.2, 0.5, 1), seed=k + 4)
    if S.get("mud"):
        blob(Hh * 0.35, (cx + 0.05, -D * 0.38, body_z - Hh * 0.28), _m("mud", S["mud"], noise=0.3, noise_scale=20),
             squash=(1.6, 0.5, 0.7), seed=3)
    # Tail.
    tail_base = (cx + L * 0.5, 0, body_z + Hh * 0.15)
    if S.get("tail"):
        stick(tail_base, (tail_base[0] + 0.12, 0.02, body_z - Hh * 0.35), 0.025, legs_m, verts=4)
    if S.get("curly"):
        cyl(0.05, 0.03, (tail_base[0] + 0.03, 0, tail_base[2]), legs_m, verts=8, rot=(0, math.radians(90), 0))
    # Head: up, or down to the grass when eating, or resting low when asleep.
    head_r = S["head_r"]
    neck_base = (cx - L * 0.42, 0, body_z + Hh * 0.15)
    if pose == "eat":
        head = (neck_base[0] - S["neck"] * 0.6 - head_r * 0.4, -0.04, head_r * 0.9)
    elif asleep:
        head = (neck_base[0] - head_r * 0.6, -0.04, body_z - Hh * 0.05)
    else:
        head = (neck_base[0] - S["neck"] * 0.55 - head_r * 0.3, -0.03, body_z + Hh * 0.35 + S["neck"] * 0.7)
    face_m = _m(f"{kind}_face", S.get("face", S["body"]))
    stick(neck_base, head, head_r * 0.6, body_m if not S.get("wool") else face_m, verts=6)
    blob(head_r, head, face_m, squash=(1.15, 0.85, 0.95), subdiv=2, seed=7, jitter=0.02)
    hx, hy, hz = head
    if S.get("muzzle"):
        blob(head_r * 0.62, (hx - head_r * 0.8, hy - 0.02, hz - head_r * 0.25), _m(f"{kind}_muzzle", S["muzzle"]),
             squash=(1, 0.9, 0.85), seed=8)
    if S.get("snout"):
        cyl(head_r * 0.45, head_r * 0.5, (hx - head_r * 0.85, hy - 0.02, hz - head_r * 0.15), _m(f"{kind}_snout", S["snout"]),
            verts=10, rot=(0, math.radians(-90), 0))
    if not asleep:
        box((0.045, 0.03, 0.045), (hx - head_r * 0.35, hy - head_r * 0.82, hz + head_r * 0.15), eye)
    else:
        box((0.06, 0.03, 0.015), (hx - head_r * 0.35, hy - head_r * 0.82, hz + head_r * 0.12), eye)
    if S.get("ears"):
        ear = _m(f"{kind}_ear", S.get("face", S["legs"]))
        for side in (-1, 1):
            e = blob(head_r * 0.35, (hx + head_r * 0.3, hy + side * head_r * 0.7, hz + head_r * 0.55), ear,
                     squash=(0.6, 1.4, 0.5), seed=9)
            e.rotation_euler = (side * 0.5, 0, 0)
    if S.get("horns"):
        horn = _m(f"{kind}_horn", S["horns"])
        for side in (-1, 1):
            stick((hx + head_r * 0.1, hy + side * head_r * 0.35, hz + head_r * 0.8),
                  (hx + head_r * 0.45, hy + side * head_r * 0.5, hz + head_r * 1.35), 0.03, horn, verts=4, tip_radius=0.01)
    if S.get("beard"):
        stick((hx - head_r * 0.7, hy, hz - head_r * 0.6), (hx - head_r * 0.6, hy, hz - head_r * 1.3), 0.035,
              _m("goat_beard", "e8e0d0"), verts=4, tip_radius=0.01)


def _bird(kind, pose):
    """The hen (brown, a red comb and wattle) and her chick (a yellow fluffball)."""
    hen = kind == "chicken"
    s = 1.0 if hen else 0.55
    body_m = _m(f"{kind}_body", "b0703a" if hen else "f6d84a", noise=0.15, noise_scale=20, **({"leaves": 14.0} if hen else {}))
    leg_m = _m("bird_leg", "e8a83a")
    beak_m = _m("beak", "f2b23a")
    asleep = pose == "sleep"
    body_z = (0.12 if asleep else 0.27) * s
    if not asleep:
        swing = {"walk1": (25, -25), "walk2": (-25, 25)}.get(pose, (0, 0))
        for side, sw in zip((-1, 1), swing):
            a = math.radians(sw)
            stick((0.02 * s, side * 0.05 * s, body_z - 0.08 * s), (0.02 * s - math.sin(a) * 0.15 * s, side * 0.05 * s, 0.01),
                  0.018 * s, leg_m, verts=4)
    blob(0.17 * s, (0.03 * s, 0, body_z + 0.05 * s), body_m, squash=(1.25, 0.95, 0.95), subdiv=2, seed=1, jitter=0.05)
    if hen:  # tail feathers up at the back, a darker wing
        blob(0.1, (0.2, 0, body_z + 0.18), _m("hen_tail", "7a4428"), squash=(0.7, 0.6, 1.3), seed=2)
        blob(0.1, (0.06, -0.12, body_z + 0.06), _m("hen_wing", "8a5430", leaves=10.0), squash=(1.4, 0.4, 0.9), seed=3)
    eating = pose == "eat"
    if eating:
        head = (-0.18 * s, -0.02, 0.07 * s)
    elif asleep:
        head = (-0.1 * s, -0.03, body_z + 0.08 * s)
    else:
        head = (-0.15 * s, -0.02, body_z + 0.2 * s)
    blob(0.09 * s, head, body_m, subdiv=2, seed=4, jitter=0.02)
    hx, hy, hz = head
    cyl(0.03 * s, 0.07 * s, (hx - 0.08 * s, hy, hz - 0.01 * s), beak_m, verts=6, radius2=0.0, rot=(0, math.radians(-90), 0))
    if hen:
        red = _m("comb", "e0302a")
        blob(0.04, (hx + 0.01, hy, hz + 0.09), red, squash=(1.4, 0.6, 1), seed=5)
        blob(0.025, (hx - 0.07, hy, hz - 0.06), red, seed=6)
    eye = _m("eye", "1e1814")
    if asleep:
        box((0.04 * s, 0.02, 0.012), (hx - 0.02 * s, hy - 0.085 * s, hz + 0.02 * s), eye)
    else:
        box((0.03 * s, 0.02, 0.03 * s), (hx - 0.02 * s, hy - 0.085 * s, hz + 0.01 * s), eye)


ANIMALS = ["chicken", "chick", "cow", "calf", "sheep", "lamb", "pig", "piglet", "goat", "goat_kid"]
POSES = ["idle", "walk1", "walk2", "eat", "sleep"]
