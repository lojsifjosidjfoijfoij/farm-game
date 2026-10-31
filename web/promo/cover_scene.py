"""Renders the art for the game's portal covers from the sprites' own 3D models.

The sprites turn these models into pixel art. Portals reject pixelated covers,
so here they're lit and rendered at full size instead, with no pixel pass.

    uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy \\
        python web/promo/cover_scene.py landscape out.png --samples 64

Formats are landscape (1920×1080), portrait (800×1200) and square (800×800).
The title goes on afterwards, in make-promo.mjs.
"""

import argparse
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "blender"))

import acres_art as art  # noqa: E402
import bpy  # noqa: E402
import models  # noqa: E402
import models_farm as farm  # noqa: E402
import models_people as people  # noqa: E402
import models_village as village  # noqa: E402
from mathutils import Vector  # noqa: E402

FORMATS = {
    # size, camera position, point looked at, lens
    "landscape": ((1920, 1080), (0.0, -11.5, 2.4), (0.0, 6.0, 2.9), 30),
    "portrait": ((800, 1200), (0.2, -12.5, 3.0), (0.2, 6.0, 6.2), 20),
    "square": ((800, 800), (0.0, -12.5, 2.8), (0.0, 6.0, 4.0), 30),
}

# Where the hero stands, so each crop of the picture keeps them in frame.
HERO_AT = {"landscape": (-3.4, -4.2), "portrait": (-1.2, -5.4), "square": (-2.5, -4.4)}
PRIZE_AT = {"landscape": (3.4, -3.5), "portrait": (1.5, -4.2), "square": (2.3, -3.8)}


def proto(name, build):
    """Builds a model once, kept out of the scene, so it can be placed many times cheaply."""
    before = set(bpy.data.objects)
    build()
    collection = bpy.data.collections.new(name)
    for obj in [o for o in bpy.data.objects if o not in before]:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        collection.objects.link(obj)
    return collection


def put(collection, x, y, z=0.0, turn=0.0, scale=1.0):
    obj = bpy.data.objects.new(collection.name, None)
    obj.instance_type = "COLLECTION"
    obj.instance_collection = collection
    obj.location = (x, y, z)
    obj.rotation_euler = (0, 0, turn)
    obj.scale = (scale, scale, scale)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def shiny(name, rgb, glow=0.0, roughness=0.3):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = roughness
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = glow
    return material


def drop_holdouts(collection):
    """The sprite pipeline cuts holes with these. In a full render they'd come out black."""
    for obj in list(collection.objects):
        if obj.type == "MESH" and any(m and m.name.startswith("holdout") for m in obj.data.materials):
            bpy.data.objects.remove(obj)


def recolor(collection, material):
    for obj in collection.objects:
        if obj.type == "MESH":
            obj.data = obj.data.copy()
            obj.data.materials.clear()
            obj.data.materials.append(material)


def sky(scene):
    world = bpy.data.worlds.new("golden hour")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    background = nodes["Background"]
    coords = nodes.new("ShaderNodeTexCoord")
    split = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    links.new(coords.outputs["Generated"], split.inputs[0])
    links.new(split.outputs["Z"], ramp.inputs["Fac"])
    stops = ramp.color_ramp.elements
    stops[0].position, stops[0].color = 0.0, (1.0, 0.62, 0.28, 1)
    stops[1].position, stops[1].color = 0.62, (0.10, 0.36, 0.86, 1)
    stops.new(0.1).color = (1.0, 0.74, 0.42, 1)
    stops.new(0.28).color = (0.46, 0.68, 0.95, 1)
    links.new(ramp.outputs["Color"], background.inputs["Color"])
    background.inputs["Strength"].default_value = 1.0


def sunlight(scene):
    for obj in list(bpy.data.objects):
        if obj.type == "LIGHT":
            bpy.data.objects.remove(obj)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.2
    sun.data.color = (1.0, 0.86, 0.62)
    sun.data.angle = math.radians(6)
    sun.rotation_euler = Vector((0.62, 0.62, -0.5)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(sun)


def glow_light(scene, at, colour, power):
    light = bpy.data.objects.new("glow", bpy.data.lights.new("glow", "POINT"))
    light.data.energy = power
    light.data.color = colour
    light.data.shadow_soft_size = 0.5
    light.location = at
    scene.collection.objects.link(light)


def ground():
    grass = art.mat("grass", art.hexrgb("6fb33e"), noise=0.3, noise_scale=0.9)
    art.box((300, 300, 0.5), (0, 40, -0.5), grass)
    soil = art.mat("soil", art.hexrgb("6a4426"), noise=0.25, noise_scale=3.0)
    ridge = art.mat("ridge", art.hexrgb("7d5230"), noise=0.25, noise_scale=3.0)
    for field_x, width in ((-9.5, 8), (0.0, 8), (9.5, 8)):
        art.box((width, 11, 0.06), (field_x, 2, 0), soil)
        rows = 8
        for row in range(rows):
            x = field_x - width / 2 + (row + 0.5) * width / rows
            art.box((0.56, 11, 0.2), (x, 2, 0), ridge, bevel=0.07)


def field(rows, random_state):
    """Crops down each ridge, thinning as they go back."""
    for field_x, kind in rows:
        for row in range(8):
            x = field_x - 4 + (row + 0.5)
            y = -3.2
            while y < 7.2:
                turn = random_state.uniform(-0.25, 0.25)
                put(kind, x + random_state.uniform(-0.06, 0.06), y, 0.14, turn, 1.1)
                y += 1.0


def coins(collection, centre, count, random_state):
    """A fountain of coins bursting up out of the prize."""
    for _ in range(count):
        rise = random_state.uniform(1.6, 7.0)
        spread = 0.2 + rise * 0.42
        coin = put(collection, centre[0] + random_state.uniform(-spread, spread),
                   centre[1] + random_state.uniform(0.0, 3.0), rise,
                   scale=random_state.uniform(0.5, 0.8))
        coin.rotation_euler = tuple(random_state.uniform(0, math.tau) for _ in range(3))


def make_coin():
    gold = bpy.data.materials.get("gold") or shiny("gold", (1.0, 0.68, 0.14), glow=0.12, roughness=0.28)
    art.cyl(0.3, 0.07, (0, 0, 0), gold, verts=28)
    art.cyl(0.21, 0.1, (0, 0, -0.015), gold, verts=24)


def clouds(random_state):
    white = art.mat("cloud", (1.0, 0.96, 0.9))
    for cx, cz, s in ((-30, 21, 4.0), (-11, 27, 3.0), (18, 23, 4.4), (36, 28, 3.2), (2, 34, 3.4), (-38, 34, 3.0)):
        for i in range(9):
            art.blob(s * random_state.uniform(0.6, 1.1),
                     (cx + i * s * 0.62 - 2.5 * s, 62, cz + random_state.uniform(-0.5, 0.5) * s), white,
                     squash=(1.25, 1, 0.68), subdiv=3, seed=i + int(cx * 7) + 100, jitter=0.06)


def build(fmt):
    scene = art.reset()
    random_state = random.Random(11)
    ground()

    wheat = proto("wheat", lambda: models.wheat(4))
    pumpkin = proto("pumpkin", lambda: farm.crop("pumpkin", 4))
    sunflower = proto("sunflower", lambda: farm.crop("sunflower", 4))
    corn = proto("corn", lambda: farm.crop("corn", 4))
    field(((-9.5, corn), (0.0, wheat), (9.5, sunflower)), random_state)

    pine = proto("pine", lambda: models.pine("summer"))
    oak = proto("oak", lambda: models.oak("summer"))
    bush = proto("bush", lambda: models.bush(wide=True))
    for i in range(70):
        put(pine, -60 + i * 1.75 + random_state.uniform(-0.8, 0.8), random_state.uniform(25, 38),
            scale=random_state.uniform(2.2, 3.4), turn=random_state.uniform(0, 6))
    for x, y, s in ((-23, 13, 1.7), (-18, 19, 1.5), (21, 12, 1.7), (26, 18, 1.6), (-13, 21, 1.2), (14, 21, 1.2)):
        put(oak, x, y, scale=s)
    for _ in range(26):
        put(bush, random_state.uniform(-30, 30), random_state.uniform(8.5, 20), scale=1.4)

    house = proto("house", lambda: farm.farmhouse(3))
    mill = proto("mill", village.windmill)
    sails = proto("sails", lambda: village.windmill(sails=1))
    drop_holdouts(mill)
    drop_holdouts(sails)
    silo = proto("silo", farm.silo)
    truck = proto("truck", lambda: models.truck(0))
    put(house, -8.0, 12.5, scale=1.9)
    put(mill, 9.2, 13.5, scale=2.1)
    put(sails, 9.2, 13.5, scale=2.1)
    put(silo, 2.0, 15, scale=1.7)
    put(silo, -0.6, 16.5, scale=1.7)
    put(truck, 15.5, 8.8, scale=1.6)

    tuft = proto("tuft", lambda: models.grass_tuft(True))
    hay = proto("hay", models.hay_bale)
    for _ in range(90):
        put(tuft, random_state.uniform(-9, 9), random_state.uniform(-11, -3.6), scale=random_state.uniform(1.4, 2.4),
            turn=random_state.uniform(0, 6))
    put(hay, -6.2, -3.8, scale=1.6)

    hero = proto("hero", lambda: people.person("farmer", "down", "idle"))
    x, y = HERO_AT[fmt]
    put(hero, x, y, 0.1, scale=2.15)

    prize = proto("prize", lambda: farm.crop("pumpkin", 4))
    gold = shiny("prize gold", (1.0, 0.55, 0.04), glow=0.25, roughness=0.45)
    gold.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.35
    recolor(prize, gold)
    px, py = PRIZE_AT[fmt]
    put(prize, px, py, 0.1, scale=2.4)
    glow_light(scene, (px, py - 1.6, 2.2), (1.0, 0.76, 0.35), 40)

    coin = proto("coin", make_coin)
    coins(coin, (px, py + 0.5), 60, random_state)
    clouds(random_state)
    sky(scene)
    sunlight(scene)
    return scene


def camera(scene, fmt):
    (width, height), at, look, lens = FORMATS[fmt]
    data = bpy.data.cameras.new("cover")
    data.lens = lens
    data.sensor_fit = "HORIZONTAL" if width >= height else "VERTICAL"
    data.clip_end = 500
    cam = bpy.data.objects.new("cover", data)
    scene.collection.objects.link(cam)
    cam.location = at
    cam.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100


def render(scene, out, samples, percent):
    scene.use_nodes = False
    scene.render.film_transparent = False
    scene.render.resolution_percentage = percent
    scene.render.filter_size = 1.5
    scene.view_settings.view_transform = "Standard"
    scene.cycles.samples = samples
    scene.cycles.max_bounces = 4
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.filepath = os.path.abspath(out)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("format", choices=FORMATS)
    parser.add_argument("out")
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--percent", type=int, default=100)
    args = parser.parse_args()
    scene = build(args.format)
    camera(scene, args.format)
    render(scene, args.out, args.samples, args.percent)


if __name__ == "__main__":
    main()
