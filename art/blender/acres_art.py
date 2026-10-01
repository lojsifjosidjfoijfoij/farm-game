"""Shared Blender pipeline for Acres art.

Every asset is a small Python function that builds a low-poly model (1 Blender
unit = 1 game tile, x east, y north, z up, the object's foot point at the
origin). This module renders it from the game's camera straight into the frame
the game expects (size and anchor from docs/ASSETS.md), with flat "toon" light
bands, then turns the render into pixel art: 16 px per tile, hard edges, a
limited palette and a dark one-pixel outline. The result is written into the
app's asset catalog, where the game picks it up by name.

Needs Blender as a Python module:  pip install "bpy==4.5.*"  (and Pillow)
The models also load in the Blender app itself, for looking at live: see live.py.
"""

import json
import math
import os

import bpy
import numpy as np
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# "v2" is the richer look being tried out (32 px per tile, cool shadows, warm
# light); its renders go to a separate folder until it's chosen.
STYLE = os.environ.get("ACRES_ART_STYLE", "v1")
CATALOG = os.environ.get("ACRES_ART_CATALOG") or os.path.join(REPO, "Acres", "Resources", "Assets.xcassets", "Art")

PX_PER_TILE = int(os.environ.get("ACRES_PX_PER_TILE") or (32 if STYLE == "v2" else 16))
# The game's 3/4 view: looking down this far from the horizon. Ground depth
# shows at sin(PITCH), heights at cos(PITCH).
PITCH = math.radians(40)
# Light from the upper left, a little in front: west faces bright, fronts
# medium, east faces dark; shadows fall back and to the right.
TO_LIGHT = Vector((-0.6, -0.4, 0.75)).normalized()
SUPERSAMPLE = 4
LEVELS = 16          # steps per colour channel
OUTLINE_SHADE = 0.3  # outline colour = this × the colour it wraps
# v2 light bands (linear multipliers), darkest first.
V2_BANDS = [(0.30, 0.33, 0.52), (0.50, 0.53, 0.72), (0.80, 0.80, 0.88), (1.0, 0.96, 0.86)]
SATURATION = 1.15 if STYLE == "v2" else 1.35    # v1: the same punch as the game's drawn art (PixelArt.swift)
CONTRAST = 1.05 if STYLE == "v2" else 1.08


# --------------------------------------------------------------------------- scene

def reset(samples=24):
    _empty_scene()
    _materials.clear()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 2
    scene.render.film_transparent = True
    scene.render.filter_size = 1.0
    scene.view_settings.view_transform = "Standard"  # colours exactly as picked
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"

    world = bpy.data.worlds.new("sky")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.85, 0.9, 1.0, 1)
    bg.inputs[1].default_value = 0.3

    sun_data = bpy.data.lights.new("sun", "SUN")
    # Cycles lights a surface facing the sun with energy / π, so π gives 1.0.
    sun_data.energy = math.pi
    sun_data.angle = math.radians(2)
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (-TO_LIGHT).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(sun)
    if bpy.app.background:  # rendering; the Blender app (live) only looks at the model
        _toon_compositor(scene)
    return scene


def _empty_scene():
    """Headless: a factory-fresh empty file. In the Blender app (driven live),
    only the scene's contents go: a factory reset there would also switch off
    the add-on that connects Claude to Blender."""
    if bpy.app.background:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        return
    for data in (bpy.data.objects, bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                 bpy.data.lights, bpy.data.cameras, bpy.data.worlds):
        for block in list(data):
            data.remove(block)


def _toon_compositor(scene, bands=3, floor=0.35):
    """Light in a few flat bands: albedo × quantized(direct + indirect light),
    squeezed into [floor, 1] so shadow sides stay colourful, not muddy."""
    if bpy.app.version >= (5, 0, 0):
        raise RuntimeError("Sprites are rendered with Blender 4.5 (its compositor API changed in 5.0): "
                           'uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy python art/blender/render.py')
    layer = scene.view_layers[0]
    layer.use_pass_diffuse_color = True
    layer.use_pass_diffuse_direct = True
    layer.use_pass_diffuse_indirect = True
    layer.use_pass_emit = True
    scene.use_nodes = True
    tree = scene.node_tree
    tree.nodes.clear()
    rl = tree.nodes.new("CompositorNodeRLayers")

    def math_node(op, value=None):
        node = tree.nodes.new("CompositorNodeMath")
        node.operation = op
        if value is not None:
            node.inputs[1].default_value = value
        return node

    light = tree.nodes.new("CompositorNodeMixRGB")
    light.blend_type = "ADD"
    light.inputs[0].default_value = 1
    tree.links.new(rl.outputs["DiffDir"], light.inputs[1])
    tree.links.new(rl.outputs["DiffInd"], light.inputs[2])
    bw = tree.nodes.new("CompositorNodeRGBToBW")
    tree.links.new(light.outputs[0], bw.inputs[0])
    scale = math_node("MULTIPLY", bands)
    snap = math_node("ROUND")
    back = math_node("DIVIDE", bands)
    high = math_node("MINIMUM", 1.0)
    squeeze = math_node("MULTIPLY", 1 - floor)
    lift = math_node("ADD", floor)
    tree.links.new(bw.outputs[0], scale.inputs[0])
    tree.links.new(scale.outputs[0], snap.inputs[0])
    tree.links.new(snap.outputs[0], back.inputs[0])
    tree.links.new(back.outputs[0], high.inputs[0])
    tree.links.new(high.outputs[0], squeeze.inputs[0])
    tree.links.new(squeeze.outputs[0], lift.inputs[0])

    shade = tree.nodes.new("CompositorNodeMixRGB")
    shade.blend_type = "MULTIPLY"
    shade.inputs[0].default_value = 1
    tree.links.new(rl.outputs["DiffCol"], shade.inputs[1])
    if STYLE == "v2":
        # Each band its own tint, the way pixel artists shade: shadows cool
        # and bluish, lit faces warm.
        ramp = tree.nodes.new("CompositorNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        els = ramp.color_ramp.elements
        els[0].position, els[0].color = 0.0, (*V2_BANDS[0], 1)
        els[1].position, els[1].color = 0.84, (*V2_BANDS[3], 1)
        for position, colour in ((0.17, V2_BANDS[1]), (0.5, V2_BANDS[2])):
            els.new(position).color = (*colour, 1)
        tree.links.new(high.outputs[0], ramp.inputs[0])
        tree.links.new(ramp.outputs[0], shade.inputs[2])
    else:
        tree.links.new(lift.outputs[0], shade.inputs[2])
    glow = tree.nodes.new("CompositorNodeMixRGB")
    glow.blend_type = "ADD"
    glow.inputs[0].default_value = 1
    tree.links.new(shade.outputs[0], glow.inputs[1])
    tree.links.new(rl.outputs["Emit"], glow.inputs[2])
    alpha = tree.nodes.new("CompositorNodeSetAlpha")
    alpha.mode = "REPLACE_ALPHA"
    tree.links.new(glow.outputs[0], alpha.inputs["Image"])
    tree.links.new(rl.outputs["Alpha"], alpha.inputs["Alpha"])
    out = tree.nodes.new("CompositorNodeComposite")
    tree.links.new(alpha.outputs[0], out.inputs["Image"])


# ----------------------------------------------------------------------- materials

_materials = {}


def mat(name, rgb, noise=0.0, emit=None, noise_scale=6.0, lines=None, tiles=None, leaves=None, grain=None):
    """A flat diffuse colour (sRGB 0…1), optionally speckled, optionally with
    crisp dark lines (boards, shingles: `lines` = (axis, period, width, shade)
    in object units), optionally glowing.

    The v2 look adds texture a pixel artist would draw: every board or tile a
    slightly different tone, flecks of grain, and leafy clusters.
    `tiles` = (u_axis, v_axis, width, height, stagger, gap, shade) lays out
    staggered tiles (shingles, stones; gap may be (between tiles, between rows)); `leaves` = clusters per tile;
    `grain` = how much fleck. In v1 these are ignored."""
    key = (name, tuple(rgb), noise, emit, lines, tiles, leaves, grain)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    linear = tuple(_to_linear(c) for c in rgb)
    m.diffuse_color = (*linear, 1)  # what the app's solid view shows
    v2 = STYLE == "v2"
    g = _Nodes(nodes, links)
    colour = None  # output socket of the base colour, if not a constant
    if noise > 0:
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 1.0
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * (1 - noise) for c in linear], 1)
        ramp.color_ramp.elements[1].color = (*[min(1, c * (1 + noise)) for c in linear], 1)
        links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        colour = ramp.outputs["Color"]
    base = colour if colour is not None else g.rgb(linear)
    if v2 and leaves:
        colour = g.leaves(base, leaves)
    elif v2 and (lines is not None or tiles is not None):
        if tiles is not None:
            u, v, w, h, stagger, gap, shade = tiles
        else:  # boards along one axis, unbroken the other way
            axis, period, width, shade = lines
            u, v, w, h, stagger, gap = axis, ("z" if axis != "z" else "x"), period, 1000.0, 0.0, width
        is_gap, rnd = g.cells(u, v, w, h, stagger, gap)
        toned = g.scale(base, g.math("ADD", 0.9, g.math("MULTIPLY", rnd, 0.2)))
        colour = g.mix(is_gap, toned, g.rgb([c * shade for c in linear]))
    elif lines is not None:
        axis, period, width, shade = lines
        coords = nodes.new("ShaderNodeTexCoord")
        split = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["Object"], split.inputs[0])
        div = nodes.new("ShaderNodeMath")
        div.operation = "DIVIDE"
        div.inputs[1].default_value = period
        links.new(split.outputs["XYZ".index(axis.upper())], div.inputs[0])
        frac = nodes.new("ShaderNodeMath")
        frac.operation = "FRACT"
        links.new(div.outputs[0], frac.inputs[0])
        edge = nodes.new("ShaderNodeMath")
        edge.operation = "GREATER_THAN"
        edge.inputs[1].default_value = 1 - width / period
        links.new(frac.outputs[0], edge.inputs[0])
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MIX"
        links.new(edge.outputs[0], mix.inputs["Fac"])
        if colour is not None:
            links.new(colour, mix.inputs["Color1"])
        else:
            mix.inputs["Color1"].default_value = (*linear, 1)
        mix.inputs["Color2"].default_value = (*[c * shade for c in linear], 1)
        colour = mix.outputs["Color"]
    if v2 and grain:
        colour = g.grain(colour if colour is not None else base, grain)
    if colour is not None:
        links.new(colour, bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*linear, 1)
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*[_to_linear(c) for c in emit], 1)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    _materials[key] = m
    return m


class _Nodes:
    """Small helpers for wiring shader nodes."""

    def __init__(self, nodes, links):
        self.nodes, self.links = nodes, links
        self._split = None

    def _feed(self, socket, value):
        if isinstance(value, (int, float)):
            socket.default_value = value
        else:
            self.links.new(value, socket)

    def math(self, op, a, b=None):
        n = self.nodes.new("ShaderNodeMath")
        n.operation = op
        self._feed(n.inputs[0], a)
        if b is not None:
            self._feed(n.inputs[1], b)
        return n.outputs[0]

    def rgb(self, linear):
        n = self.nodes.new("ShaderNodeRGB")
        n.outputs[0].default_value = (*linear, 1)
        return n.outputs[0]

    def axis(self, name):
        if self._split is None:
            coords = self.nodes.new("ShaderNodeTexCoord")
            self._split = self.nodes.new("ShaderNodeSeparateXYZ")
            self.links.new(coords.outputs["Object"], self._split.inputs[0])
        return self._split.outputs["XYZ".index(name.upper())]

    def scale(self, colour, factor):
        n = self.nodes.new("ShaderNodeVectorMath")
        n.operation = "SCALE"
        self.links.new(colour, n.inputs[0])
        self._feed(n.inputs["Scale"], factor)
        return n.outputs["Vector"]

    def mix(self, fac, a, b):
        n = self.nodes.new("ShaderNodeMixRGB")
        n.blend_type = "MIX"
        self._feed(n.inputs["Fac"], fac)
        self.links.new(a, n.inputs["Color1"])
        self.links.new(b, n.inputs["Color2"])
        return n.outputs["Color"]

    def random(self, a, b, seed=0.0):
        vec = self.nodes.new("ShaderNodeCombineXYZ")
        self._feed(vec.inputs[0], a)
        self._feed(vec.inputs[1], b)
        vec.inputs[2].default_value = seed
        noise = self.nodes.new("ShaderNodeTexWhiteNoise")
        noise.noise_dimensions = "3D"
        self.links.new(vec.outputs[0], noise.inputs["Vector"])
        return noise.outputs["Value"]

    def cells(self, u, v, w, h, stagger, gap):
        """(is it a gap?, a random 0…1 per cell) for tiles w × h on axes u, v."""
        vv = self.math("DIVIDE", self.axis(v), h)
        row = self.math("FLOOR", vv)
        shift = self.math("MULTIPLY", self.math("FLOORED_MODULO", row, 2.0), stagger)
        uu = self.math("ADD", self.math("DIVIDE", self.axis(u), w), shift)
        col = self.math("FLOOR", uu)
        gap_side, gap_row = gap if isinstance(gap, tuple) else (gap, gap)
        gap_u = self.math("LESS_THAN", self.math("FRACT", uu), gap_side / w)
        gap_v = self.math("LESS_THAN", self.math("FRACT", vv), gap_row / h)
        return self.math("MAXIMUM", gap_u, gap_v), self.random(col, row)

    def leaves(self, base, per_tile):
        """Leafy clusters: each a lit centre fading to a dark gap, in a few flat steps."""
        vor = self.nodes.new("ShaderNodeTexVoronoi")
        vor.voronoi_dimensions = "3D"
        vor.inputs["Scale"].default_value = per_tile
        coords = self.nodes.new("ShaderNodeTexCoord")
        self.links.new(coords.outputs["Object"], vor.inputs["Vector"])
        ramp = self.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        els = ramp.color_ramp.elements
        els[0].position, els[0].color = 0.0, (1.0, 1.0, 1.0, 1)
        els[1].position, els[1].color = 0.62, (0.46, 0.46, 0.46, 1)
        els.new(0.32).color = (0.8, 0.8, 0.8, 1)
        self.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
        shaded = self.nodes.new("ShaderNodeMixRGB")
        shaded.blend_type = "MULTIPLY"
        shaded.inputs["Fac"].default_value = 1.0
        self.links.new(base, shaded.inputs["Color1"])
        self.links.new(ramp.outputs["Color"], shaded.inputs["Color2"])
        # Each cluster a touch lighter or darker than its neighbours.
        tone = self.math("ADD", 1.08, self.math("MULTIPLY", self._voronoi_random(vor), 0.22))
        return self.scale(shaded.outputs["Color"], tone)

    def _voronoi_random(self, vor):
        bw = self.nodes.new("ShaderNodeRGBToBW")
        self.links.new(vor.outputs["Color"], bw.inputs[0])
        return bw.outputs[0]

    def grain(self, colour, amount):
        """Scattered one-pixel flecks, a little darker."""
        noise = self.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 70.0
        noise.inputs["Detail"].default_value = 0.0
        fleck = self.math("GREATER_THAN", noise.outputs["Fac"], 0.62)
        return self.scale(colour, self.math("SUBTRACT", 1.0, self.math("MULTIPLY", fleck, amount)))


def holdout():
    """Cuts a hole: for night-light overlays, everything but the glow."""
    if "holdout" in bpy.data.materials:
        return bpy.data.materials["holdout"]
    m = bpy.data.materials.new("holdout")
    m.use_nodes = True
    nodes = m.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    hold = nodes.new("ShaderNodeHoldout")
    m.node_tree.links.new(hold.outputs[0], out.inputs["Surface"])
    return m


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# -------------------------------------------------------------------------- shapes

def _finish(obj, material, parent):
    if material is not None:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    if parent is not None:
        obj.parent = parent
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def box(size, at, material, rot=(0, 0, 0), parent=None, bevel=0.0):
    """A box `size` (x, y, z) whose *bottom centre* sits at `at`."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(at[0], at[1], at[2] + size[2] / 2))
    o = bpy.context.object
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return _finish(o, material, parent)


def cyl(radius, depth, at, material, verts=10, rot=(0, 0, 0), parent=None, radius2=None):
    """A cylinder (or cone, with `radius2`) whose bottom centre sits at `at` (before rotation)."""
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                            location=(at[0], at[1], at[2] + depth / 2), rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth,
                                        location=(at[0], at[1], at[2] + depth / 2), rotation=rot)
    return _finish(bpy.context.object, material, parent)


def stick(base, tip, radius, material, verts=6, tip_radius=None, parent=None):
    """A (tapered) cylinder from `base` to `tip`: branches, stalks, logs."""
    base, tip = Vector(base), Vector(tip)
    d = tip - base
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius,
                                    radius2=radius if tip_radius is None else tip_radius,
                                    depth=d.length, location=(base + tip) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return _finish(o, material, parent)


def blob(radius, at, material, squash=(1, 1, 1), subdiv=1, seed=0, jitter=0.12, parent=None):
    """A lumpy faceted ball (leaves, bushes, rocks) centred at `at`."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=at)
    o = bpy.context.object
    rng = np.random.default_rng(abs(int(seed)))
    for v in o.data.vertices:
        v.co *= 1 + rng.uniform(-jitter, jitter)
    o.scale = squash
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, material, parent)


def prism(width, depth, height, at, material, parent=None, rot=(0, 0, 0)):
    """A gable: triangular prism running along x, ridge on top, bottom centre at `at`."""
    mesh = bpy.data.meshes.new("gable")
    w, d, h = width / 2, depth / 2, height
    verts = [(-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0), (-w, 0, h), (w, 0, h)]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("gable", mesh)
    o.location = at
    o.rotation_euler = rot
    bpy.context.scene.collection.objects.link(o)
    return _finish(o, material, parent)


def empty(name="root", at=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    o.location = at
    bpy.context.scene.collection.objects.link(o)
    return o


# -------------------------------------------------------------------------- render

def frame_camera(tiles_w, tiles_h, anchor_y, top_down=False):
    """An orthographic camera framing exactly the asset's sprite: `tiles_w` ×
    `tiles_h` tiles, the foot point (origin) at `anchor_y` of the height."""
    scene = bpy.context.scene
    res_x = max(1, round(tiles_w * PX_PER_TILE))
    res_y = max(1, round(tiles_h * PX_PER_TILE))
    scene.render.resolution_x = res_x * SUPERSAMPLE
    scene.render.resolution_y = res_y * SUPERSAMPLE
    scene.render.resolution_percentage = 100
    data = bpy.data.cameras.new("cam")
    data.type = "ORTHO"
    data.sensor_fit = "HORIZONTAL"
    data.ortho_scale = res_x / PX_PER_TILE
    data.clip_start = 0.1
    data.clip_end = 400
    cam = bpy.data.objects.new("cam", data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    height = res_y / PX_PER_TILE
    centre = (0.5 - anchor_y) * height  # screen units above the foot point
    if top_down:
        cam.rotation_euler = (0, 0, 0)
        cam.location = (0, centre, 100)
    else:
        d = Vector((0, math.cos(PITCH), -math.sin(PITCH)))
        u = Vector((0, math.sin(PITCH), math.cos(PITCH)))
        cam.location = centre * u - 100 * d
        cam.rotation_euler = (math.pi / 2 - PITCH, 0, 0)
    return res_x, res_y


def screen_point(p, tiles_w, tiles_h, anchor_y):
    """Where a 3D point lands in the sprite, as unit coordinates (x right, y up from the bottom)."""
    res_x = round(tiles_w * PX_PER_TILE)
    res_y = round(tiles_h * PX_PER_TILE)
    w, h = res_x / PX_PER_TILE, res_y / PX_PER_TILE
    sy = p[1] * math.sin(PITCH) + p[2] * math.cos(PITCH)
    return ((p[0] + w / 2) / w, (sy + anchor_y * h) / h)


def render(name, size, outline=True, soft=False, top_down=False, preview_dir=None):
    """Renders the scene into the sprite `name` of `size` = (tiles_w, tiles_h, anchor_y)."""
    tiles_w, tiles_h, anchor_y = size
    res_x, res_y = frame_camera(tiles_w, tiles_h, anchor_y, top_down=top_down)
    scene = bpy.context.scene
    raw = os.path.join(_tmp_dir(), name + "_raw.png")
    scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    img = pixelize(raw, (res_x, res_y), outline=outline, soft=soft)
    write_imageset(name, img)
    if preview_dir:
        os.makedirs(preview_dir, exist_ok=True)
        img.save(os.path.join(preview_dir, name + ".png"))
    return img


def pixelize(path, size, outline=True, soft=False):
    """Supersampled render → pixel art: box-shrink, hard alpha, palette, outline."""
    from PIL import Image  # not in the Blender app's own Python; only needed here

    big = Image.open(path).convert("RGBA")
    arr = np.asarray(big).astype(np.float32) / 255.0
    # Average colour weighted by coverage, per output pixel.
    h, w = size[1], size[0]
    s = SUPERSAMPLE
    arr = arr[: h * s, : w * s].reshape(h, s, w, s, 4)
    alpha = arr[..., 3].mean(axis=(1, 3))
    rgb_premult = (arr[..., :3] * arr[..., 3:4]).sum(axis=(1, 3))
    weight = arr[..., 3].sum(axis=(1, 3))[..., None]
    rgb = np.where(weight > 0, rgb_premult / np.maximum(weight, 1e-6), 0)
    if STYLE == "v2" and not soft:
        rgb = _crisp(arr, h, w)
    else:
        rgb = punch(rgb)
        rgb = np.round(np.clip(rgb, 0, 1) * LEVELS) / LEVELS
    if soft:
        a = np.round(alpha * 4) / 4
    else:
        a = (alpha >= 0.5).astype(np.float32)
    out = np.concatenate([rgb, a[..., None]], axis=-1)
    if outline and not soft:
        out = _outline(out)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def _crisp(arr, h, w, colours=48):
    """v2: no averaging. Each pixel takes the most common colour among its
    samples, from a small palette picked for the sprite, so edges stay hard
    and there are no in-between colours (averaging is what blurs)."""
    from PIL import Image

    s = SUPERSAMPLE
    samples = arr.reshape(h * s, w * s, 4)
    opaque = samples[..., 3] > 0.5
    rgb8 = (np.clip(punch(samples[..., :3]), 0, 1) * 255 + 0.5).astype(np.uint8)
    pts = rgb8[opaque]
    if len(pts) == 0:
        return np.zeros((h, w, 3), np.float32)
    # Octree keeps small but distinct colours (a flower box, glass, hay)
    # that a population-based palette would merge away.
    fit = Image.fromarray(pts.reshape(1, -1, 3), "RGB").quantize(
        colors=colours, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    palette = np.array(fit.getpalette()[: colours * 3], np.float32).reshape(-1, 3) / 255
    n = len(palette)
    idx = np.asarray(Image.fromarray(rgb8, "RGB").quantize(palette=fit, dither=Image.Dither.NONE)).astype(np.int64)
    idx = np.where(opaque, np.minimum(idx, n - 1), n)  # transparent samples get their own bin
    blocks = idx.reshape(h, s, w, s).transpose(0, 2, 1, 3).reshape(h, w, s * s)
    counts = np.zeros((h, w, n + 1), np.int32)
    for k in range(s * s):
        counts += np.eye(n + 1, dtype=np.int32)[blocks[..., k]]
    return palette[np.argmax(counts[..., :n], axis=-1)]


def punch(rgb):
    """The same saturation and contrast boost the game gives its drawn art
    (PixelArt.swift), so rendered and drawn sprites sit together."""
    luma = (rgb * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=-1, keepdims=True)
    rgb = luma + (rgb - luma) * SATURATION
    return (rgb - 0.5) * CONTRAST + 0.5


def _outline(px):
    solid = px[..., 3] > 0.5
    out = px.copy()
    h, w = solid.shape
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        shifted = np.zeros_like(solid)
        src = np.zeros_like(px)
        ys = slice(max(0, dy), h + min(0, dy))
        yd = slice(max(0, -dy), h + min(0, -dy))
        xs = slice(max(0, dx), w + min(0, dx))
        xd = slice(max(0, -dx), w + min(0, -dx))
        shifted[yd, xd] = solid[ys, xs]
        src[yd, xd] = px[ys, xs]
        edge = shifted & ~solid & (out[..., 3] < 0.5)
        out[edge, :3] = src[edge, :3] * OUTLINE_SHADE
        out[edge, 3] = 1.0
    return out


def write_imageset(name, img):
    folder = os.path.join(CATALOG, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))
    contents = {
        "images": [
            {"filename": name + ".png", "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def _tmp_dir():
    d = os.environ.get("ACRES_ART_TMP") or os.path.join(REPO, "art", "blender", ".renders")
    os.makedirs(d, exist_ok=True)
    return d
