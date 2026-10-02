"""Item icons in the new look: small models rendered through the same toon
pipeline as the world sprites, framed to fill a 20 × 20 pixel icon (the
game shows most at 40 points: 2 points per art pixel, like the HUD's).

    uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy python art/blender/icons.py [names…]

Models are about one unit across; the camera fits whatever was built.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))

import acres_art as art  # noqa: E402
from acres_art import blob, box, cyl, hexrgb, mat, stick  # noqa: E402
import models_farm as farm  # noqa: E402
import models_people as people  # noqa: E402
import models_village as village  # noqa: E402

SIZE = 20
PREVIEW = os.environ.get("ACRES_ART_PREVIEW") or os.path.join(os.path.dirname(__file__), ".renders", "preview")


def _m(name, hexc, **kw):
    return mat(name, hexrgb(hexc), **kw)


# ------------------------------------------------------------------ framing

def render_icon(name, pitch=None, size=SIZE):
    """Frames everything built so far into a size × size icon and writes it to the catalog."""
    scene = bpy.context.scene
    P = art.PITCH if pitch is None else pitch
    u = Vector((0, math.sin(P), math.cos(P)))
    d = Vector((0, math.cos(P), -math.sin(P)))
    xs, ys = [], []
    bpy.context.view_layer.update()
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            xs.append(w.x)
            ys.append(w.dot(u))
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    span = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.14
    scene.render.resolution_x = scene.render.resolution_y = size * art.SUPERSAMPLE
    data = bpy.data.cameras.new("cam")
    data.type = "ORTHO"
    data.ortho_scale = span
    data.clip_start, data.clip_end = 0.1, 400
    cam = bpy.data.objects.new("cam", data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = Vector((cx, 0, 0)) + cy * u - 100 * d
    cam.rotation_euler = (math.pi / 2 - P, 0, 0)
    raw = os.path.join(art._tmp_dir(), name + "_raw.png")
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    img = art.pixelize(raw, (size, size), outline=True)
    art.write_imageset(name, img)
    os.makedirs(PREVIEW, exist_ok=True)
    img.save(os.path.join(PREVIEW, name + ".png"))


# ------------------------------------------------------------------ produce

CROP_COLOUR = {"wheat": "efc04a", "carrot": "f27a1e", "potato": "c8a05a", "strawberry": "ec3a3a", "corn": "f2c43a",
               "pumpkin": "f08a24", "lettuce": "8fd24e", "onion": "e0a648", "kale": "5e9a72", "tomato": "e8402e",
               "garlic": "f2ece0", "sunflower": "f6c22a", "blueberry": "3a48b0", "cabbage": "b8e0a0", "melon": "4f9a3a"}
LEAF = "5aa83a"


def produce(kind):
    c = _m(f"p_{kind}", CROP_COLOUR[kind], noise=0.1, noise_scale=30)
    leaf = _m("p_leaf", LEAF)
    if kind == "wheat":
        # A sheaf: stalks gathered at a twine tie, splaying a little, heavy ears on top.
        for k in range(7):
            spread = (k - 3) * 0.07
            top = (spread * 2.2, 0.02 * (k % 2), 1.0 - abs(k - 3) * 0.04)
            stick((spread * 0.8, 0, 0.0), (spread * 0.3, 0, 0.4), 0.03, c, verts=4)
            stick((spread * 0.3, 0, 0.4), top, 0.03, c, verts=4)
            blob(0.075, (top[0], top[1], top[2] + 0.1), c, squash=(0.65, 0.65, 1.7), seed=k)
        cyl(0.13, 0.08, (0, 0, 0.36), _m("twine", "a37a3a"), verts=8)
    elif kind == "carrot":
        for k, x in enumerate((-0.15, 0.15)):
            stick((x, 0, 0.7), (x + 0.05 * (k * 2 - 1), 0, 0.0), 0.16, c, verts=8, tip_radius=0.02)
            for j in range(3):
                stick((x, 0, 0.7), (x + (j - 1) * 0.12, 0, 1.0), 0.03, leaf, verts=4)
    elif kind == "potato":
        for k, (x, z) in enumerate(((-0.3, 0.15), (0.3, 0.15), (0.0, 0.4))):
            blob(0.24, (x, 0, z), c, squash=(1.3, 1, 0.9), seed=k)
    elif kind in ("strawberry", "tomato"):
        for k, x in enumerate((-0.22, 0.24)):
            blob(0.27 if kind == "tomato" else 0.24, (x, 0, 0.3), c, squash=(1, 1, 1.15 if kind == "strawberry" else 0.9),
                 subdiv=2, seed=k)
            blob(0.1, (x, 0, 0.55), leaf, squash=(1.6, 1.6, 0.4), seed=k)
    elif kind == "corn":
        stick((-0.35, 0, 0.1), (0.35, 0, 0.6), 0.18, c, verts=8, tip_radius=0.1)
        for side in (-1, 1):
            stick((-0.4, 0, 0.05), (0.1, side * 0.2, 0.25), 0.1, _m("husk", "8cc048"), verts=6, tip_radius=0.03)
    elif kind in ("pumpkin", "melon", "cabbage", "lettuce"):
        r = 0.45
        extra = {"melon": {"lines": ("x", 0.12, 0.045, 0.65)}, "cabbage": {"lines": ("z", 0.1, 0.02, 0.85)}}.get(kind, {})
        body = _m(f"pb_{kind}", CROP_COLOUR[kind], noise=0.08, noise_scale=12, **extra)
        if kind == "pumpkin":
            for k in range(7):
                a = k * 2 * math.pi / 7
                blob(0.28, (math.cos(a) * 0.2, math.sin(a) * 0.15, 0.32), body, subdiv=2, seed=k, jitter=0.03)
            stick((0, 0, 0.6), (0.05, 0, 0.8), 0.05, _m("stem", "6b7a2e"), verts=5)
        elif kind == "melon":
            blob(r, (0, 0.05, r * 0.8), body, squash=(1.25, 1, 0.85), subdiv=2, seed=1, jitter=0.02)
            box((0.4, 0.08, 0.3), (0.32, -0.42, 0.0), _m("melon_flesh", "f26a5a"), rot=(0, 0, 0.2))
        else:
            blob(r, (0, 0, r * 0.85), body, subdiv=2, seed=1, jitter=0.12 if kind == "lettuce" else 0.04)
            for k in range(5):
                a = k * 2 * math.pi / 5
                blob(0.22, (math.cos(a) * 0.38, math.sin(a) * 0.3, 0.25), _m(f"pl_{kind}", "6cba3c" if kind == "lettuce" else "78b088"),
                     squash=(1.2, 1, 0.6), seed=k)
    elif kind in ("onion", "garlic"):
        for k, x in enumerate((-0.22, 0.24) if kind == "onion" else (0.0,)):
            r = 0.27 if kind == "onion" else 0.34
            blob(r, (x, 0, r), c, squash=(1, 1, 0.95), subdiv=2, seed=k, jitter=0.03)
            stick((x, 0, r * 1.8), (x + 0.03, 0, r * 2.6), 0.04, _m("p_dry", "c8b46a"), verts=4)
    elif kind == "kale":
        stick((0, 0, 0), (0, 0, 0.35), 0.06, _m("kale_stem", "a8c8a0"), verts=6)
        for k in range(6):
            a = k * 1.05
            blob(0.2, (math.cos(a) * 0.22, math.sin(a) * 0.1, 0.45 + 0.08 * (k % 2)), c, subdiv=1, seed=k, jitter=0.25)
    elif kind == "sunflower":
        for k in range(12):
            a = k * 2 * math.pi / 12
            p = blob(0.15, (math.cos(a) * 0.36, 0, 0.5 + math.sin(a) * 0.36), c, squash=(1.4, 0.4, 0.6), seed=k)
            p.rotation_euler = (0, -a, 0)
        cyl(0.24, 0.1, (0, -0.06, 0.5), _m("sun_disc", "6a4224", noise=0.3, noise_scale=40), verts=12,
            rot=(math.radians(90), 0, 0))
    elif kind == "blueberry":
        for k, (x, z) in enumerate(((-0.2, 0.2), (0.2, 0.2), (0.0, 0.42), (-0.32, 0.45), (0.3, 0.45), (0.0, 0.0))):
            blob(0.17, (x, 0, z), c, subdiv=2, seed=k, jitter=0.02)
        blob(0.08, (-0.05, -0.15, 0.5), _m("blue_dust", "8a9ae0"), seed=9)


def packet(kind):
    """A paper seed packet: a picture of the crop on the front, a coloured band at the top."""
    paper = _m("packet_paper", "f2e6c8", noise=0.08, noise_scale=20)
    box((0.7, 0.1, 0.95), (0, 0, 0), paper)
    box((0.72, 0.11, 0.18), (0, 0, 0.8), _m(f"band_{kind}", CROP_COLOUR[kind]))
    c = _m(f"pic_{kind}", CROP_COLOUR[kind])
    for k, (x, z) in enumerate(((-0.14, 0.3), (0.14, 0.32), (0.0, 0.52))):
        blob(0.13, (x, -0.07, z), c, squash=(1, 0.4, 1), seed=k)
    blob(0.07, (0.05, -0.08, 0.65), _m("p_leaf", LEAF), squash=(1.4, 0.4, 0.8), seed=4)


# ------------------------------------------------------------- containers

def jar(liquid, contents=None, lid="d8402e"):
    # What's inside shows through: the jar is its contents, with a glass rim and a glint.
    cyl(0.32, 0.6, (0, 0, 0), _m(f"jar_{liquid}", liquid, noise=0.1, noise_scale=20), verts=12)
    cyl(0.3, 0.06, (0, 0, 0.58), _m("jar_glass", "d8eef4"), verts=12)
    box((0.05, 0.02, 0.42), (-0.17, -0.3, 0.08), _m("glint", "f4fbfd"))
    cyl(0.34, 0.14, (0, 0, 0.64), _m(f"lid_{lid}", lid, lines=("x", 0.08, 0.02, 0.8) if lid == "d8402e" else None), verts=12)
    box((0.38, 0.05, 0.22), (0, -0.31, 0.2), _m("label", "f4efe2"))
    if contents:
        for k, (x, z) in enumerate(((-0.12, 0.15), (0.12, 0.22), (0.0, 0.4))):
            blob(0.1, (x, -0.24, z), _m(f"jar_bits_{contents}", contents), seed=k)


def bottle(liquid, cap="d8402e", tall=True):
    glass = _m(f"bottle_{liquid}", liquid, noise=0.05, noise_scale=20)
    h = 0.75 if tall else 0.5
    cyl(0.25, h, (0, 0, 0), glass, verts=12)
    cyl(0.25, 0.15, (0, 0, h), glass, verts=12, radius2=0.1)
    cyl(0.1, 0.18, (0, 0, h + 0.15), _m("bottle_neck", "e8f0f2"), verts=8)
    cyl(0.12, 0.08, (0, 0, h + 0.33), _m(f"cap_{cap}", cap), verts=8)
    box((0.36, 0.05, 0.25), (0, -0.24, h * 0.3), _m("label", "f4efe2"))
    box((0.04, 0.02, 0.4), (-0.12, -0.25, h * 0.35), _m("glint", "f4fbfd"))


def sack(colour, band="a37a3a", spill=None):
    cloth = _m(f"sack_{colour}", colour, noise=0.15, noise_scale=14)
    blob(0.4, (0, 0, 0.42), cloth, squash=(1, 0.85, 1.1), subdiv=2, seed=1, jitter=0.06)
    cyl(0.18, 0.2, (0, 0, 0.82), cloth, verts=10, radius2=0.12)
    cyl(0.16, 0.06, (0, 0, 0.82), _m(f"tie_{band}", band), verts=10)
    if spill:
        blob(0.17, (0.0, -0.32, 0.12), _m(f"spill_{spill}", spill, noise=0.3, noise_scale=40), squash=(1.2, 1, 0.5), seed=2)


# --------------------------------------------------------------------- fish

FISH = {  # body, belly/fin accent, shape: (length, height, tail), extras
    "sunfish": ("f0a83a", "3a8ac8", (0.75, 0.55, 0.3), {}),
    "carp": ("c89a4a", "a8682a", (0.95, 0.42, 0.32), {"scales": True}),
    "perch": ("9ab84a", "f08a3a", (0.85, 0.36, 0.3), {"stripes": "3f6a2e"}),
    "catfish": ("6a6a5a", "c8c4a8", (1.0, 0.34, 0.28), {"whiskers": True}),
    "golden_koi": ("f2c43a", "f4f0e0", (0.95, 0.4, 0.34), {"spots": "f08a24"}),
    "trout": ("8aa8a0", "e88a8a", (0.95, 0.34, 0.3), {"spots": "3a4a3a", "stripe": "e8908a"}),
    "bass": ("6a9a4a", "e8e0b8", (0.9, 0.42, 0.3), {"stripe": "2f5a2e"}),
    "whitefish": ("d8dce0", "f4f6f8", (0.9, 0.34, 0.28), {}),
    "pike": ("6a8a4a", "e8e0b8", (1.15, 0.26, 0.24), {"spots": "c8d890"}),
    "salmon": ("a8b8c8", "f28a6a", (1.05, 0.36, 0.3), {"stripe": "f2a08a"}),
    "eel": ("4a5a3a", "8a9a6a", (1.2, 0.14, 0.1), {"eel": True}),
    "sturgeon": ("7a8a98", "d8dce0", (1.2, 0.3, 0.28), {"plates": True}),
}


def fish(kind, smoked=False):
    body_c, accent_c, (L, H, T), extra = FISH[kind]
    if smoked:
        body_c, accent_c = "c87a3a", "e8a85a"
    body = _m(f"fish_{kind}{smoked}", body_c, noise=0.08, noise_scale=20)
    accent = _m(f"fish_acc_{kind}{smoked}", accent_c)
    if extra.get("eel"):
        for k in range(6):
            x = -0.6 + k * 0.24
            blob(0.12, (x, 0, 0.3 + math.sin(k * 1.2) * 0.12), body, squash=(1.4, 0.8, 1), seed=k)
        blob(0.08, (-0.62, -0.06, 0.32), _m("eye", "1e1814"), seed=9) if not smoked else None
        return
    blob(H / 2, (0, 0, 0.4), body, squash=(L / H, 0.5, 1), subdiv=2, seed=1, jitter=0.02)
    blob(H / 2 * 0.7, (0.05, -0.03, 0.4 - H * 0.18), accent, squash=(L / H * 0.8, 0.5, 0.6), subdiv=2, seed=2, jitter=0.02)
    tail = blob(T, (L / 2 + T * 0.5, 0, 0.4), accent if kind in ("sunfish", "golden_koi") else body,
                squash=(0.6, 0.25, 1.1), seed=3)
    tail.rotation_euler = (0, 0, 0)
    blob(H * 0.25, (-0.02, 0, 0.4 + H * 0.5), accent, squash=(1.6, 0.3, 0.8), seed=4)  # dorsal fin
    if not smoked:
        box((0.06, 0.03, 0.06), (-L / 2 + 0.12, -H / 4 - 0.02, 0.43), _m("eye", "1e1814"))
    if extra.get("stripes"):
        for k in range(3):
            box((0.05, 0.03, H * 0.7), (-0.15 + k * 0.17, -H / 4 - 0.01, 0.4 - H * 0.35), _m("stripe_" + kind, extra["stripes"]))
    if extra.get("stripe"):
        box((L * 0.7, 0.03, 0.05), (0, -H / 4 - 0.01, 0.4), _m("lstripe_" + kind, extra["stripe"]))
    if extra.get("spots"):
        for k, (x, z) in enumerate(((-0.1, 0.48), (0.12, 0.44), (0.25, 0.5), (0.0, 0.36))):
            blob(0.04, (x, -H / 4 - 0.02, z), _m("spot_" + kind, extra["spots"]), seed=k)
    if extra.get("whiskers"):
        for z in (0.36, 0.42):
            stick((-L / 2 + 0.02, -0.05, z), (-L / 2 - 0.15, -0.06, z - 0.08), 0.012, accent, verts=3)
    if extra.get("plates"):
        for k in range(4):
            blob(0.05, (-0.3 + k * 0.2, -0.02, 0.4 + H * 0.45), accent, seed=k)


# ---------------------------------------------------------------- wild finds

def wild(kind):
    leaf = _m("w_leaf", "4f9a2e")
    if kind == "wild_garlic":
        for k in range(3):
            l = blob(0.12, ((k - 1) * 0.18, 0, 0.35), leaf, squash=(0.8, 0.4, 3.0), seed=k)
            l.rotation_euler = (0, (k - 1) * 0.3, 0)
        for k in range(4):
            blob(0.07, (-0.1 + k * 0.08, -0.08, 0.75 + 0.04 * (k % 2)), _m("w_white", "f4f6f8"), seed=k)
    elif kind in ("daffodil", "snowdrop"):
        stem = stick((0, 0, 0), (0, 0, 0.75), 0.03, leaf, verts=4)
        petals = _m(f"w_{kind}", "f6d040" if kind == "daffodil" else "f6f8fa")
        if kind == "daffodil":
            for k in range(6):
                a = k * math.pi / 3
                blob(0.12, (math.cos(a) * 0.15, -0.05, 0.75 + math.sin(a) * 0.15), petals, squash=(1, 0.4, 1), seed=k)
            cyl(0.09, 0.15, (0, -0.1, 0.75), _m("w_trumpet", "f29a2a"), verts=8, rot=(math.radians(90), 0, 0))
        else:
            stick((0, 0, 0.75), (0.18, 0, 0.7), 0.025, leaf, verts=4)
            blob(0.11, (0.2, -0.02, 0.56), petals, squash=(0.9, 0.9, 1.4), seed=1)
        stick((0.05, 0, 0), (0.18, 0, 0.45), 0.04, leaf, verts=4, tip_radius=0.01)
    elif kind in ("morel", "chanterelle"):
        stem_c = "e8dcc0"
        if kind == "morel":
            cyl(0.08, 0.3, (0, 0, 0), _m("w_stem", stem_c), verts=8)
            blob(0.2, (0, 0, 0.5), _m("w_morel", "8a6a48", lines=("z", 0.07, 0.025, 0.6), noise=0.3, noise_scale=40),
                 squash=(1, 1, 1.5), subdiv=2, seed=1)
        else:
            for k, x in enumerate((-0.2, 0.18)):
                cyl(0.07, 0.3, (x, 0, 0), _m("w_ch_stem", "f2b23a"), verts=8, radius2=0.12)
                cyl(0.24, 0.1, (x, 0, 0.3), _m("w_chanterelle", "f2a82a", lines=("x", 0.06, 0.015, 0.8)), verts=10, radius2=0.18)
    elif kind == "blackberry":
        for k, (x, z) in enumerate(((-0.18, 0.25), (0.18, 0.3), (0.0, 0.5))):
            for j in range(5):
                a = j * 1.26
                blob(0.07, (x + math.cos(a) * 0.08, -0.03, z + math.sin(a) * 0.08), _m("w_bb", "3a2240"), seed=k * 5 + j)
        blob(0.15, (0.0, 0.05, 0.7), leaf, squash=(1.5, 0.5, 0.8), seed=9)
    elif kind in ("chamomile", "elderflower"):
        stick((0, 0, 0), (0, 0, 0.5), 0.03, leaf, verts=4)
        if kind == "chamomile":
            for k, (x, z) in enumerate(((-0.2, 0.55), (0.15, 0.65), (0.0, 0.45))):
                stick((0, 0, 0.3), (x, 0, z), 0.02, leaf, verts=4)
                cyl(0.11, 0.03, (x, -0.02, z), _m("w_cham", "f6f8fa"), verts=10, rot=(math.radians(80), 0, 0))
                blob(0.05, (x, -0.06, z), _m("w_cham_c", "f2c43a"), seed=k)
        else:
            for k in range(14):
                a = k * 2.4
                r = 0.08 * math.sqrt(k)
                blob(0.06, (math.cos(a) * r * 1.2, -0.04, 0.6 + math.sin(a) * r * 0.6), _m("w_elder", "f6f2d8"), seed=k)
    elif kind == "hazelnut":
        for k, x in enumerate((-0.2, 0.2)):
            blob(0.22, (x, 0, 0.22), _m("w_hazel", "a8703a", noise=0.15, noise_scale=30), squash=(1, 1, 1.1), seed=k)
            cyl(0.14, 0.08, (x, 0, 0.4), _m("w_hazel_cap", "c8b46a"), verts=8)
    elif kind == "holly":
        for k, a in enumerate((-0.6, 0.6)):
            l = blob(0.18, (math.sin(a) * 0.25, 0, 0.35), _m("w_holly", "2f6e3a"), squash=(0.7, 0.3, 1.6), seed=k, jitter=0.25)
            l.rotation_euler = (0, a, 0)
        for k, (x, z) in enumerate(((-0.05, 0.22), (0.07, 0.25), (0.0, 0.33))):
            blob(0.07, (x, -0.1, z), _m("w_holly_berry", "d8282a"), seed=k)
    elif kind == "pinecone":
        cone = _m("w_cone", "8a5a32", noise=0.2, noise_scale=30)
        for k in range(5):
            z = 0.12 + k * 0.15
            r = 0.26 - abs(k - 1.5) * 0.06
            cyl(r, 0.12, (0, 0, z), cone if k % 2 == 0 else _m("w_cone_l", "a8743f"), verts=8, radius2=r * 0.7)


def sapling_pot(kind):
    cyl(0.3, 0.38, (0, 0, 0), _m("pot", "c8683a", lines=("z", 0.3, 0.03, 0.8)), verts=12, radius2=0.36)
    cyl(0.33, 0.04, (0, 0, 0.38), _m("pot_soil", "5e4128"), verts=12)
    stem = _m("sp_stem", "7a5232" if kind != "birch" else "e8e2d6")
    stick((0, 0, 0.4), (0, 0, 0.95), 0.03, stem, verts=5)
    if kind == "pine":
        for z, r in ((0.6, 0.26), (0.78, 0.2), (0.94, 0.12)):
            cyl(r, 0.24, (0, 0, z), _m("sp_needles", "2e7a4c"), verts=10, radius2=0.0)
        return
    colour = {"oak": "5fae34", "birch": "8fd24e", "maple": "4f9c32", "apple": "6ab63c", "cherry": "f6bccb"}[kind]
    for k, (x, z) in enumerate(((-0.15, 0.8), (0.15, 0.85), (0.0, 1.0), (-0.08, 0.95), (0.1, 0.7))):
        blob(0.12, (x, -0.02, z), _m("sp_leaf_" + kind, colour), squash=(1.3, 1, 0.8), seed=k)


def misc(kind):
    if kind == "egg":
        blob(0.32, (0, 0, 0.4), _m("egg", "e8c8a0", noise=0.1, noise_scale=30), squash=(0.85, 0.85, 1.1), subdiv=2, seed=1, jitter=0)
    elif kind == "milk":
        bottle("f6f6f2", cap="4a8ac8")
    elif kind == "goat_milk":
        cyl(0.3, 0.55, (0, 0, 0), _m("jug", "c8a07a", lines=("z", 0.2, 0.03, 0.85)), verts=12, radius2=0.22)
        cyl(0.18, 0.1, (0, 0, 0.55), _m("jug_milk", "f6f6f2"), verts=10)
        stick((0.3, 0, 0.45), (0.38, 0, 0.2), 0.05, _m("jug", "c8a07a"), verts=5)
    elif kind == "wool":
        blob(0.4, (0, 0, 0.4), _m("wool", "f2ead8", lines=("x", 0.07, 0.02, 0.85), noise=0.2, noise_scale=30), subdiv=2, seed=1)
        stick((0.3, 0, 0.2), (0.55, -0.05, 0.05), 0.03, _m("wool", "f2ead8"), verts=4)
    elif kind == "truffle":
        blob(0.32, (0, 0, 0.32), _m("truffle", "3a2a24", noise=0.4, noise_scale=40), subdiv=2, seed=3, jitter=0.18)
    elif kind == "honey":
        jar("f2b23a", lid="e8d8a8")
    elif kind in ("log", "log_maple"):
        bark = _m(f"bark_{kind}", "7d5232" if kind == "log" else "8a3a2a", noise=0.15, noise_scale=12, lines=("x", 0.2, 0.04, 0.8))
        stick((0.45, 0.1, 0.3), (-0.45, -0.1, 0.3), 0.28, bark, verts=10)
        stick((-0.45, -0.1, 0.3), (-0.47, -0.11, 0.3), 0.24, _m(f"ends_{kind}", "e2b980" if kind == "log" else "e2a080"), verts=10)
    elif kind == "plank":
        for k in range(3):
            box((1.0, 0.35, 0.12), (0.03 * k, 0, k * 0.13), _m("plank", "e2b980", lines=("x", 0.25, 0.02, 0.8)), rot=(0, 0, 0.05 * k))
    elif kind == "flour":
        sack("f2ead8", spill="fbf8f2")
    elif kind == "cornmeal":
        sack("e8d8a0", spill="f2c43a")
    elif kind == "fertilizer":
        sack("6a8a4a", band="3a4a2a", spill="5e4128")
    elif kind == "animal_feed":
        sack("c8a46a", spill="e5c45b")
    elif kind == "cheese":
        cyl(0.42, 0.32, (0, 0, 0), _m("cheese", "f2c43a"), verts=14)
        box((0.25, 0.3, 0.33), (0.25, -0.3, 0.0), _m("cheese_cut", "f8d860"), rot=(0, 0, 0.6))
    elif kind == "goat_cheese":
        cyl(0.36, 0.25, (0, 0, 0), _m("goat_cheese", "f6f2ea", noise=0.1, noise_scale=30), verts=14)
        blob(0.08, (0.1, -0.3, 0.27), _m("herb", "6cba3c"), seed=1)
    elif kind == "cloth":
        for k, c in enumerate(("e8607a", "f2c43a")):
            box((0.9, 0.6, 0.12), (0, 0, k * 0.14), _m(f"cloth_{c}", c, lines=("x", 0.1, 0.03, 0.75)), bevel=0.04)
    elif kind == "dried_mushrooms":
        stick((0, 0, 0.9), (0, 0, 0.2), 0.02, _m("string", "c8b46a"), verts=4)
        for k, z in enumerate((0.25, 0.45, 0.65)):
            blob(0.16, (0, 0, z), _m("dried_mush", "a8743f", noise=0.2, noise_scale=30), squash=(1.3, 1, 0.6), seed=k)
    elif kind == "sprinkler":
        farm.sprinkler()
    elif kind == "sprinkler_pro":
        farm.sprinkler(pro=True)
    elif kind in ("apple", "cherry"):
        c = _m(f"fruit_{kind}", "e0332a" if kind == "apple" else "a8142a")
        if kind == "apple":
            blob(0.38, (0, 0, 0.38), c, squash=(1.05, 1, 0.95), subdiv=2, seed=1, jitter=0)
            stick((0, 0, 0.7), (0.05, 0, 0.88), 0.03, _m("stem", "6b4526"), verts=4)
            blob(0.1, (0.15, 0, 0.82), _m("p_leaf", LEAF), squash=(1.6, 0.6, 0.8), seed=2)
            blob(0.08, (-0.15, -0.3, 0.5), _m("shine", "ff8a70"), seed=3)
        else:
            for k, x in enumerate((-0.2, 0.2)):
                blob(0.22, (x, 0, 0.22), c, subdiv=2, seed=k, jitter=0)
                stick((x, 0, 0.4), (0.0, 0, 0.9), 0.025, _m("stem_g", "5a8a3a"), verts=4)


JAMS = {"strawberry_jam": ("d8283a", "e8505a"), "blueberry_jam": ("3a2a7a", "5a4ab0"),
        "blackberry_jam": ("3a1a3a", "5a2a5a"), "pickled_onions": ("e8e0a8", "f6f6f0"), "sauerkraut": ("e0d890", "f0ecc0"),
        "tomato_sauce": ("c8281a", None)}
BOTTLES = {"juice": "f28a2a", "apple_juice": "f2c43a", "carrot_juice": "f27a1e", "cherry_juice": "a8142a",
           "elderflower_cordial": "e8e8b0", "sunflower_oil": "f2c02a"}


def item(name):
    """Builds the model for `item_<name>`."""
    if name.startswith("seeds_"):
        return packet(name[len("seeds_"):])
    if name.startswith("sapling_"):
        return sapling_pot(name[len("sapling_"):])
    if name.startswith("smoked_"):
        return fish(name[len("smoked_"):], smoked=True)
    if name in CROP_COLOUR:
        return produce(name)
    if name in FISH:
        return fish(name)
    if name in JAMS:
        liquid, bits = JAMS[name]
        return jar(liquid, contents=bits, lid="d8402e" if name != "tomato_sauce" else "f2e6c8")
    if name in BOTTLES:
        return bottle(BOTTLES[name], cap="f2e6c8" if name == "elderflower_cordial" else "d8402e")
    if name == "chamomile_tea":
        box((0.6, 0.45, 0.6), (0, 0, 0), _m("tea_tin", "f2c43a", lines=("z", 0.3, 0.03, 0.8)))
        cyl(0.11, 0.03, (0, -0.24, 0.32), _m("w_cham", "f6f8fa"), verts=10, rot=(math.radians(80), 0, 0))
        return
    if name in village.WORKSHOPS:
        return village.workshop(name)
    if name in ("wild_garlic", "daffodil", "morel", "blackberry", "chamomile", "elderflower", "chanterelle", "hazelnut",
                "holly", "pinecone", "snowdrop"):
        return wild(name)
    return misc(name)


def all_items():
    doc = os.path.join(art.REPO, "docs", "ASSETS.md")
    import re
    with open(doc) as f:
        return [m.group(1) for m in re.finditer(r"^\| `item_([a-z0-9_]+)`", f.read(), re.M)]


def pitch_for(name):
    """Fish and the wheat sheaf read best from the side; the rest from a little above."""
    if name in FISH or name.startswith("smoked_"):
        return math.radians(6)
    if name == "wheat":
        return math.radians(12)
    return math.radians(28)


def portrait():
    """Arne, head and shoulders, for his speech bubble (26 px: 52 points at 2 points per pixel)."""
    art.reset()
    people.person("arne", "down", "idle")
    bpy.context.view_layer.update()
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and max((obj.matrix_world @ v.co).z for v in obj.data.vertices) < 0.78:
            bpy.data.objects.remove(obj)
    render_icon("ui_portrait_mentor", pitch=math.radians(14), size=26)


def main(selected):
    if not selected or "ui_portrait_mentor" in selected:
        portrait()
        print("rendered ui_portrait_mentor")
    names = [n for n in all_items() if not selected or any(("item_" + n).startswith(s) for s in selected)]
    for n in names:
        art.reset()
        item(n)
        render_icon("item_" + n, pitch=pitch_for(n))
        print("rendered item_" + n)


if __name__ == "__main__":
    main(sys.argv[1:])
