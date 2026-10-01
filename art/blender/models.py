"""The models, one function per asset (1 unit = 1 tile, foot point at the origin,
x east, y north = away from the camera, z up). Kept deliberately low-poly:
at 32 px per tile a whole house is about 160 pixels wide."""

import math

import bmesh
import bpy

from acres_art import blob, box, cyl, empty, hexrgb, holdout, mat, prism, stick

# A small shared palette: saturated, warm.
RED = hexrgb("b8432f")
RED_DARK = hexrgb("8a2e22")
WOOD = hexrgb("a0703f")
WOOD_DARK = hexrgb("6b4526")
WOOD_GREY = hexrgb("9a8f7c")
TRIM = hexrgb("efe6d2")
ROOF_GREY = hexrgb("5c6370")
ROOF_BROWN = hexrgb("7b5440")
SHINGLE = hexrgb("c25b3f")
STONE = hexrgb("a7a39a")
STONE_DARK = hexrgb("77736c")
BRICK = hexrgb("a24f3a")
GLASS = hexrgb("2d4a63")
GLOW = hexrgb("ffc766")
PAINT_BLUE = hexrgb("88b7d8")
HAY = hexrgb("e5c45b")
LEAF = hexrgb("4f9a2e")
LEAF_DARK = hexrgb("2f6e22")
BARK = hexrgb("7d5232")


def roof_slopes(span, rise, length, eave_z, centre_y, material, overhang=0.22, thick=0.1, along="x"):
    """Two roof slabs meeting at a ridge. `along` = the ridge direction ("x":
    ridge runs east-west, slopes face south and north; "y": ridge runs
    north-south, slopes face east and west)."""
    half = span / 2
    phi = math.atan2(rise, half)
    slope_len = math.hypot(half, rise) + overhang
    for side in (-1, 1):
        # Centre of the slab: halfway up the slope, nudged down by the overhang.
        down = overhang / 2
        offset = half / 2 + math.cos(phi) * down
        z = eave_z + rise / 2 - math.sin(phi) * down + thick / 2
        if along == "x":
            box((length, slope_len, thick), (0, centre_y + side * offset, z - thick / 2), material,
                rot=(-side * phi, 0, 0))
        else:
            box((slope_len, length, thick), (side * offset, centre_y, z - thick / 2), material,
                rot=(0, side * phi, 0))


def gambrel_segments(width, knee_x, knee_z, rise, eave_z, overhang=0.22):
    """The two pitches of a gambrel roof on the +x side, as (angle, centre x,
    centre z, length): a steep one from the eave up to the knee, then a shallow
    one up to the ridge. Mirror in x for the other side. Each piece is grown a
    little at both ends so the eave overhangs and the joins have no seam."""
    half = width / 2
    out = []
    for (x0, z0), (x1, z1), grow, inner in (
        ((half, 0.0), (knee_x, knee_z), overhang, 0.05),
        ((knee_x, knee_z), (0.0, rise), 0.0, 0.06),
    ):
        phi = math.atan2(z1 - z0, x0 - x1)
        run = math.hypot(x0 - x1, z1 - z0) + grow + inner
        shift = (grow - inner) / 2          # net push towards the lower end
        cx = (x0 + x1) / 2 + math.cos(phi) * shift
        cz = eave_z + (z0 + z1) / 2 - math.sin(phi) * shift
        out.append((phi, cx, cz, run))
    return out


def gambrel_gable(width, depth, knee_x, knee_z, rise, at, material):
    """The end wall under a gambrel roof: a five-sided prism running north-south
    (bottom centre at `at`), its section going eave, knee, ridge, knee, eave."""
    half = width / 2
    section = [(-half, 0.0), (half, 0.0), (knee_x, knee_z), (0.0, rise), (-knee_x, knee_z)]
    d = depth / 2
    verts = []
    for x, z in section:
        verts += [(x, -d, z), (x, d, z)]
    n = len(section)
    faces = [(i * 2, ((i + 1) % n) * 2, ((i + 1) % n) * 2 + 1, i * 2 + 1) for i in range(n)]
    faces.append(tuple(i * 2 for i in range(n)))
    faces.append(tuple(i * 2 + 1 for i in range(n - 1, -1, -1)))

    mesh = bpy.data.meshes.new("gambrel")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new("gambrel", mesh)
    obj.location = at
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.append(material)
    return obj


def gambrel_slopes(width, knee_x, knee_z, rise, length, eave_z, centre_y, material,
                   overhang=0.22, thick=0.1):
    """The four roof slabs of a gambrel roof whose ridge runs north-south."""
    for phi, cx, cz, run in gambrel_segments(width, knee_x, knee_z, rise, eave_z, overhang):
        for side in (-1, 1):
            box((run, length, thick), (side * cx, centre_y, cz), material, rot=(0, side * phi, 0))


def farmhouse_t0(night=False):
    """Small run-down wooden house: pale blue siding, a shingle roof with a
    patch, one boarded window, a little sagging porch and a brick chimney."""
    H = holdout()
    walls = H if night else mat("fh_walls", PAINT_BLUE, noise=0.06, noise_scale=12, lines=("z", 0.2, 0.035, 0.78))
    trim = H if night else mat("fh_trim", TRIM)
    roof = H if night else mat("fh_roof", SHINGLE, noise=0.1, noise_scale=8, lines=("y", 0.22, 0.05, 0.7), tiles=("x", "y", 0.2, 0.17, 0.5, (0.0, 0.05), 0.58))
    patch = H if night else mat("fh_patch", ROOF_GREY, lines=("y", 0.22, 0.05, 0.7))
    wood = H if night else mat("fh_wood", WOOD, noise=0.1, lines=("x", 0.25, 0.04, 0.75), grain=0.12)
    plank = H if night else mat("fh_plank", WOOD_DARK)
    brick = H if night else mat("fh_brick", STONE, noise=0.18, noise_scale=20, lines=("z", 0.2, 0.05, 0.72), tiles=("x", "z", 0.22, 0.13, 0.5, 0.035, 0.68))
    window = mat("fh_glow", (0, 0, 0), emit=GLOW) if night else mat("fh_glass", GLASS)
    flowers = H if night else mat("fh_flowers", hexrgb("e8607a"), noise=0.3, noise_scale=40)

    front = 0.7
    box((4.0, 2.6, 1.6), (0, front + 1.3, 0), walls)
    for x in (-2.0, 2.0):
        box((0.14, 0.12, 1.6), (x, front - 0.04, 0), trim)
    roof_slopes(span=2.6 + 0.0, rise=1.1, length=4.5, eave_z=1.6, centre_y=front + 1.3, material=roof)
    # A patch of grey shingles on the front slope.
    box((0.95, 0.5, 0.04), (-1.1, front + 0.5, 2.1), patch, rot=(math.atan2(1.1, 1.3), 0, 0))
    # Chimney through the back of the roof.
    box((0.45, 0.45, 2.1), (1.35, front + 1.75, 1.2), brick)
    box((0.56, 0.56, 0.1), (1.35, front + 1.75, 3.3), brick)
    # Door with a little window, and two windows either side.
    box((0.62, 0.05, 1.1), (0.25, front - 0.02, 0), plank)
    box((0.3, 0.05, 0.22), (0.25, front - 0.04, 0.72), window)
    box((0.76, 0.06, 0.08), (0.25, front - 0.03, 1.1), trim)
    for x in (-1.3, 1.35):
        box((0.68, 0.05, 0.55), (x, front - 0.02, 0.6), window)
        box((0.82, 0.07, 0.08), (x, front - 0.04, 0.53), trim)
        box((0.82, 0.07, 0.08), (x, front - 0.04, 1.15), trim)
        box((0.07, 0.07, 0.62), (x, front - 0.04, 0.53), trim)
    if not night:
        # The boarded window: two planks nailed across the left one.
        box((0.9, 0.05, 0.11), (-1.3, front - 0.07, 0.72), wood, rot=(0, math.radians(14), 0))
        box((0.9, 0.05, 0.11), (-1.3, front - 0.07, 0.9), wood, rot=(0, math.radians(-9), 0))
        # A flower box under the right window.
        box((0.8, 0.16, 0.14), (1.35, front - 0.12, 0.42), wood)
        box((0.72, 0.12, 0.12), (1.35, front - 0.12, 0.55), flowers)
    # Porch: a deck in front of the door, two posts, a sagging lean-to roof.
    box((1.7, 0.6, 0.12), (0.25, front - 0.3, 0), wood)
    for x in (-0.5, 1.0):
        box((0.1, 0.1, 1.15), (x, front - 0.55, 0.12), wood)
    box((1.9, 0.7, 0.07), (0.25, front - 0.3, 1.22), roof, rot=(math.radians(12), math.radians(-4), 0))
    box((0.8, 0.22, 0.06), (0.25, front - 0.72, 0), plank)


FARMHOUSE_CHIMNEY_TOP = (1.35, 0.7 + 1.75, 3.4)


def barn_old():
    """Old weathered red barn, gambrel roof with its end to the front: big
    white-framed double doors with X braces, a wide hayloft door with hay
    poking out, white trim down the roof edges and a small window."""
    red = mat("barn_red", RED, noise=0.1, noise_scale=16, lines=("x", 0.3, 0.04, 0.72), grain=0.1)
    trim = mat("barn_trim", TRIM)
    roof = mat("barn_roof", ROOF_GREY, noise=0.1, noise_scale=8, lines=("x", 0.24, 0.05, 0.72),
               tiles=("x", "y", 0.24, 1000.0, 0.0, 0.05, 0.62), grain=0.1)
    door = mat("barn_door", RED_DARK, noise=0.06, noise_scale=16, lines=("x", 0.2, 0.03, 0.75))
    hay = mat("barn_hay", HAY, noise=0.25, noise_scale=30)
    glass = mat("barn_glass", GLASS)

    width = 3.6
    front = 0.4
    depth = 2.4          # shallow, so the roof takes up little of the sprite
    wall = 1.5
    knee_x, knee_z, rise = 1.15, 0.78, 1.3      # where the roof bends, and the ridge
    mid = front + depth / 2

    box((width, depth, wall), (0, mid, 0), red)
    gambrel_gable(width, depth, knee_x, knee_z, rise, (0, mid, wall), red)
    gambrel_slopes(width, knee_x, knee_z, rise, depth + 0.3, wall, mid, roof)
    for x in (-1.8, 1.8):
        box((0.12, 0.1, wall), (x, front - 0.04, 0), trim)
    # White trim down both roof edges on the front, following the bend.
    for phi, cx, cz, run in gambrel_segments(width, knee_x, knee_z, rise, wall, overhang=0.26):
        for side in (-1, 1):
            box((run, 0.08, 0.1), (side * cx, front - 0.05, cz), trim, rot=(0, side * phi, 0))
    # Double doors: a white frame all round, a centre post and X braces.
    box((1.6, 0.05, 1.2), (0, front - 0.02, 0), door)
    box((1.78, 0.06, 0.1), (0, front - 0.04, 1.2), trim)
    for x in (-0.84, 0, 0.84):
        box((0.1, 0.06, 1.2), (x, front - 0.04, 0), trim)
    for cx in (-0.41, 0.41):
        for angle in (34, -34):
            box((0.07, 0.04, 1.38), (cx, front - 0.06, -0.09), trim, rot=(0, math.radians(angle), 0))
    # Hayloft door, wide and white-framed, with hay spilling out.
    loft_w, loft_h, loft_z = 0.94, 0.8, 1.6
    box((loft_w, 0.05, loft_h), (0, front - 0.02, loft_z), door)
    for z in (loft_z - 0.07, loft_z + loft_h):
        box((loft_w + 0.18, 0.06, 0.07), (0, front - 0.04, z), trim)
    for x in (-(loft_w + 0.09) / 2, (loft_w + 0.09) / 2):
        box((0.09, 0.06, loft_h + 0.07), (x, front - 0.04, loft_z - 0.07), trim)
    box((0.66, 0.2, 0.12), (0, front - 0.1, loft_z + 0.06), hay)
    # A small window on the right, framed to match.
    win_x, win_w, win_h, win_z = 1.3, 0.6, 0.38, 0.78
    box((win_w, 0.04, win_h), (win_x, front - 0.02, win_z), glass)
    box((0.06, 0.05, win_h), (win_x, front - 0.04, win_z), trim)
    for z in (win_z - 0.06, win_z + win_h):
        box((win_w + 0.12, 0.05, 0.06), (win_x, front - 0.04, z), trim)
    for x in (win_x - (win_w + 0.06) / 2, win_x + (win_w + 0.06) / 2):
        box((0.06, 0.05, win_h + 0.06), (x, front - 0.04, win_z - 0.06), trim)


# ----------------------------------------------------------------------- nature

FENCE_WOOD = hexrgb("9c7d5a")
SOIL = hexrgb("8f5a34")
SOIL_WET = hexrgb("6a4024")
GRASS_GREEN = hexrgb("5fae34")
SNOW = hexrgb("f2f6fb")
LEAVES = {
    "summer": [hexrgb("4f9a2e"), hexrgb("3e8526"), hexrgb("62b23a")],
    "spring": [hexrgb("7cc548"), hexrgb("93d65a"), hexrgb("6ab63c")],
    "autumn": [hexrgb("e08a2c"), hexrgb("cf5a2a"), hexrgb("eab83c")],
}

# The camera looks down at 40°, so ground depth shows at sin(40°): things that
# must span a whole tile north-south on screen are modelled this much longer.
DEPTH_STRETCH = 1 / math.sin(math.radians(40))


def _canopy(centre, radius, colours, seed, lumps=9, squash=0.85):
    """A round leafy crown: a big faceted ball with lumps over its top and
    sides, like a cauliflower, so the outline stays round."""
    cx, cy, cz = centre
    leaves = [mat(f"leaf{i}", c, noise=0.16, noise_scale=7, leaves=6.5) for i, c in enumerate(colours)]
    blob(radius * 0.9, (cx, cy, cz), leaves[0], squash=(1.1, 0.9, squash), subdiv=2, seed=seed, jitter=0.08)
    for k in range(lumps):
        theta = math.acos(1 - 1.25 * (k + 0.5) / lumps)       # from the top down to just below the middle
        phi = k * 2.39996 + seed
        x = cx + radius * 0.62 * math.sin(theta) * math.cos(phi) * 1.15
        y = cy + radius * 0.5 * math.sin(theta) * math.sin(phi)
        z = cz + radius * 0.62 * math.cos(theta) * squash
        blob(radius * 0.5, (x, y, z), leaves[(k + 1) % len(leaves)], squash=(1, 0.9, 0.9), subdiv=2,
             seed=seed + k + 1, jitter=0.1)


def oak(season="summer", s=1.0, seed=3):
    """Broad round oak, thick trunk, layered canopy (bare with snow in winter)."""
    bark = mat("bark", BARK, noise=0.15, noise_scale=12, lines=("z", 0.3, 0.04, 0.8), grain=0.15)
    stick((0, 0, 0), (0, 0, 1.55 * s), 0.22 * s, bark, verts=8, tip_radius=0.13 * s)
    for side in (-1, 1):  # roots
        stick((0, 0, 0.12), (side * 0.35 * s, -0.05, 0.0), 0.08 * s, bark, verts=5, tip_radius=0.03)
    if season == "winter":
        snow = mat("snow", SNOW)
        twig = mat("twig", hexrgb("6a4630"))
        # Limbs fan out from the top of the trunk and fork twice, filling
        # roughly the same round crown as the leafy seasons.
        def limb(base, angle, length, radius, depth, k):
            a = math.radians(angle)
            tip = (base[0] + math.sin(a) * length, base[1] + 0.04 * ((k % 3) - 1), base[2] + math.cos(a) * length)
            stick(base, tip, radius, bark if depth == 0 else twig, verts=5, tip_radius=radius * 0.6)
            if depth < 2:
                fork = tuple(b + (t - b) * 0.7 for b, t in zip(base, tip))
                for j, turn in enumerate((-18, 20)):
                    limb(fork if depth == 0 else tip, angle + turn, length * (0.62 if depth == 0 else 0.5),
                         radius * 0.62, depth + 1, k * 3 + j)
            elif abs(angle) > 30 and k % 2 == 0:
                # Snow lies along the flatter twigs.
                blob(0.075 * s, (tip[0], tip[1], tip[2] + 0.03), snow, squash=(1.8, 1, 0.45), seed=seed + k)
        for k, angle in enumerate((-46, -24, -6, 10, 28, 48)):
            limb((0, 0, 1.4 * s), angle, 1.05 * s, 0.1 * s, 0, k)
        blob(0.22 * s, (0, 0.02, 1.5 * s), snow, squash=(1.5, 1.1, 0.35), seed=seed)
        return
    _canopy((0, 0.1, 2.1 * s), 1.15 * s, LEAVES[season], seed)


PINE = {
    "summer": [hexrgb("2e7a4c"), hexrgb("256a42"), hexrgb("3a8c58")],
    "spring": [hexrgb("3f9455"), hexrgb("348548"), hexrgb("4ea862")],
}


def pine(season="summer", seed=7):
    """Tall pine: stacked tiers, each with a ragged lower edge of branch tips."""
    import bpy
    import numpy as np

    bark = mat("bark", BARK, noise=0.15, noise_scale=12, lines=("z", 0.3, 0.04, 0.8), grain=0.15)
    stick((0, 0, 0), (0, 0, 1.0), 0.13, bark, verts=7, tip_radius=0.1)
    colours = PINE.get(season, PINE["summer"])
    needles = [mat(f"needles{i}", c, noise=0.12, noise_scale=8, leaves=9.0) for i, c in enumerate(colours)]
    snow = mat("snow", SNOW) if season == "winter" else None
    rng = np.random.default_rng(seed)
    tiers = [(0.5, 0.95, 1.3), (1.2, 0.8, 1.2), (1.9, 0.64, 1.1), (2.6, 0.46, 1.0), (3.25, 0.28, 1.05)]
    for k, (z, r, h) in enumerate(tiers):
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r, radius2=0.0, depth=h, location=(0, 0, z + h / 2))
        cone = bpy.context.object
        for i, v in enumerate(cone.data.vertices):
            if v.co.z < -h / 2 + 1e-4 and (v.co.x or v.co.y):   # the rim: alternate tips down and in
                tip = i % 2 == 0
                v.co.z -= (0.16 if tip else 0.0) + rng.uniform(0, 0.05)
                v.co.x *= (1.0 if tip else 0.86) + rng.uniform(-0.05, 0.05)
                v.co.y *= (1.0 if tip else 0.86) + rng.uniform(-0.05, 0.05)
        cone.data.materials.append(needles[k % len(needles)])
        if snow is not None:
            blob(r * 0.55, (0, 0, z + h * 0.42), snow, squash=(1.2, 1.0, 0.35), seed=seed + k)


def young_tree(kind="oak", seed=5):
    if kind == "birch":
        bark = mat("birch_bark", hexrgb("efeae0"), lines=("z", 0.2, 0.05, 0.25))
        stick((0, 0, 0), (0, 0, 1.25), 0.075, bark, verts=6, tip_radius=0.04)
        _canopy((0, 0.05, 1.45), 0.48, [hexrgb("86cc52"), hexrgb("6fb840"), hexrgb("9ad866")], seed, lumps=7, squash=1.3)
    else:
        bark = mat("bark", BARK, noise=0.15, noise_scale=12)
        stick((0, 0, 0), (0, 0, 1.0), 0.11, bark, verts=6, tip_radius=0.07)
        _canopy((0, 0.05, 1.35), 0.66, LEAVES["summer"], seed, lumps=7)


def bush(wide=False, seed=11):
    colours = [hexrgb("3f8a2a"), hexrgb("357a24"), hexrgb("4f9c32")] if wide else [hexrgb("4f9e30"), hexrgb("438c2a"), hexrgb("62b03c")]
    leaves = [mat(f"bush{i}", c, noise=0.2, noise_scale=8, leaves=8.0) for i, c in enumerate(colours)]
    if wide:
        for k, (x, z, r) in enumerate([(-0.3, 0.22, 0.3), (0.3, 0.22, 0.3), (0, 0.3, 0.36)]):
            blob(r, (x, 0.05, z), leaves[k % 3], squash=(1.2, 1, 0.75), seed=seed + k)
    else:
        for k, (x, z, r) in enumerate([(-0.22, 0.3, 0.3), (0.22, 0.3, 0.3), (0, 0.45, 0.36)]):
            blob(r, (x, 0.05, z), leaves[k % 3], squash=(1, 1, 0.9), seed=seed + k)


def rock(large=False, seed=21):
    stone = mat("stone", STONE, noise=0.2, noise_scale=6, grain=0.15)
    if large:
        blob(0.68, (0, 0.25, 0.42), stone, squash=(1.15, 0.9, 0.72), seed=seed, jitter=0.18)
        blob(0.38, (-0.15, 0.2, 0.8), mat("moss", hexrgb("6f9a3a"), noise=0.25, noise_scale=12),
             squash=(1.3, 1, 0.45), seed=seed + 1)
    else:
        blob(0.3, (0, 0.08, 0.17), stone, squash=(1.25, 1, 0.65), seed=seed, jitter=0.18)


def stump():
    bark = mat("bark", BARK, noise=0.15, noise_scale=12, lines=("z", 0.12, 0.03, 0.8))
    cyl(0.32, 0.34, (0, 0.15, 0), bark, verts=9, radius2=0.28)
    cyl(0.27, 0.03, (0, 0.15, 0.34), mat("rings", hexrgb("d8b27a"), lines=("x", 0.09, 0.025, 0.75)), verts=9)
    blob(0.1, (-0.28, 0.0, 0.08), mat("moss", hexrgb("6f9a3a")), squash=(1.4, 1, 0.6), seed=2)


def grass_tuft(seed_head=False, seed=31):
    blades = [mat("blade0", hexrgb("6ab83c")), mat("blade1", hexrgb("4f9a2e"))]
    for k in range(7):
        a = k * 2.4
        x, y = math.cos(a) * 0.09 * (k % 3), math.sin(a) * 0.05 * (k % 3)
        lean = math.radians(18) * (1 if k % 2 else -1)
        cyl(0.035, 0.32 + 0.06 * (k % 3), (x, y, 0), blades[k % 2], verts=4, radius2=0.002, rot=(0, lean, 0))
    if seed_head:
        cyl(0.012, 0.45, (0.06, 0, 0), blades[0], verts=4, rot=(0, math.radians(10), 0))
        blob(0.05, (0.14, 0, 0.45), mat("seedhead", hexrgb("e2c25a")), squash=(0.7, 0.7, 1.4), seed=1)


def wheat(stage):
    """Wheat on one soil tile: 0 seeds, 1 sprouts, 2 blades, 3 green ears, 4 golden ears."""
    green = mat("wheat_green", hexrgb("6cba3c"))
    gold = mat("wheat_gold", hexrgb("efc04a"), noise=0.12, noise_scale=20)
    ear_green = mat("wheat_ear_green", hexrgb("9bcb52"))
    seed_mat = mat("wheat_seed", hexrgb("f0cf72"))
    spots = [(x * 0.27, y * 0.22) for y in (1, 0, -1) for x in (-1, 0, 1)]
    for k, (x, y) in enumerate(spots):
        x += 0.03 * ((k * 5) % 3 - 1)
        if stage == 0:
            box((0.07, 0.07, 0.03), (x, y, 0), seed_mat)
        elif stage == 1:
            stick((x, y, 0), (x, y, 0.17), 0.04, green, verts=4, tip_radius=0.005)
        elif stage == 2:
            # A fanned tuft, rows staggered so neighbours don't line up into letters.
            if k // 3 == 1:
                x += 0.13
            light = mat("wheat_light", hexrgb("8fd24e"))
            tall = 0.3 + 0.06 * ((k * 7) % 3)
            for lean, h, m in ((-0.17, 0.62, green), (-0.07, 0.9, light), (0.03, 1.0, light), (0.15, 0.7, green)):
                stick((x, y, 0), (x + lean, y - 0.03, tall * h), 0.032, m, verts=4, tip_radius=0.004)
        else:
            stalk = green if stage == 3 else gold
            ear = ear_green if stage == 3 else gold
            height = 0.6 if stage == 3 else 0.7
            for dx in (-0.05, 0.05):
                lean = dx * 1.2 + (0.0 if stage == 3 else 0.12)  # ripe ears nod to the right
                tip = (x + dx + lean, y, height)
                stick((x + dx, y, 0), tip, 0.022, stalk, verts=4)
                blob(0.065, (tip[0], y, height + 0.02), ear, squash=(0.75, 0.75, 1.7), seed=k)


def soil(wet=False):
    colour = SOIL_WET if wet else SOIL
    box((1.0, 1.0, 0.02), (0, 0, 0), mat("soil", colour, noise=0.12, noise_scale=10, lines=("y", 0.2, 0.07, 0.62)))


# ------------------------------------------------------------------------ props

def well():
    stone = mat("well_stone", STONE, noise=0.15, noise_scale=10, lines=("z", 0.16, 0.04, 0.72), tiles=("x", "z", 0.3, 0.16, 0.5, 0.04, 0.65))
    wood = mat("well_wood", WOOD, noise=0.1)
    cyl(0.6, 0.55, (0, 0.35, 0), stone, verts=12)
    cyl(0.45, 0.02, (0, 0.35, 0.55), mat("well_water", hexrgb("27465e")), verts=12)
    for x in (-0.55, 0.55):
        box((0.1, 0.1, 1.35), (x, 0.35, 0.3), wood)
    prism(1.45, 0.9, 0.45, (0, 0.35, 1.62), mat("well_roof", SHINGLE, lines=("y", 0.15, 0.04, 0.7), tiles=("x", "y", 0.18, 0.15, 0.5, (0.0, 0.045), 0.58)))
    cyl(0.03, 1.1, (-0.55, 0.35, 1.25), wood, verts=6, rot=(0, math.radians(90), 0))
    cyl(0.13, 0.2, (0.1, 0.35, 0.75), mat("bucket", hexrgb("8a6a4a"), lines=("z", 0.07, 0.02, 0.7)), verts=8)


def hay_bale():
    hay = mat("hay", HAY, noise=0.2, noise_scale=25, lines=("x", 0.08, 0.02, 0.82))
    box((0.95, 0.6, 0.5), (0, 0.25, 0), hay)
    for x in (-0.25, 0.25):
        box((0.06, 0.62, 0.52), (x, 0.25, -0.005), mat("twine", hexrgb("a37a3a")))


def crate():
    wood = mat("crate_wood", WOOD, noise=0.1, lines=("z", 0.15, 0.025, 0.78), grain=0.12)
    frame = mat("crate_frame", WOOD_DARK)
    box((0.58, 0.5, 0.55), (0, 0.22, 0), wood)
    for z in (0.0, 0.49):
        box((0.6, 0.04, 0.06), (0, -0.04, z), frame)
    for x in (-0.27, 0.27):
        box((0.06, 0.04, 0.55), (x, -0.04, 0), frame)


def log_pile():
    bark = mat("bark", BARK, noise=0.15, noise_scale=12)
    ends = mat("log_ends", hexrgb("e2b980"), noise=0.08)
    rows = [(-0.46, 0), (0, 0), (0.46, 0), (-0.23, 1), (0.23, 1), (0, 2)]
    for x, row in rows:
        z = 0.15 + row * 0.25
        stick((x, 0.5, z), (x, 0.0, z), 0.15, bark, verts=8)
        stick((x, 0.0, z), (x, -0.015, z), 0.12, ends, verts=8)


def lamp_post(night=False):
    """An old iron street lamp: a square lantern on a post (the glass glows at night)."""
    H = holdout()
    iron = H if night else mat("iron", hexrgb("3b3a40"), noise=0.1, noise_scale=20)
    glass = mat("lamp_glow", (0, 0, 0), emit=hexrgb("ffc46a")) if night else mat("lamp_glass", hexrgb("f6d58a"))
    box((0.12, 0.12, 2.5), (0, 0, 0), iron)
    box((0.22, 0.22, 0.08), (0, 0, 0), iron)
    box((0.26, 0.26, 0.05), (0, 0, 2.5), iron)
    box((0.2, 0.2, 0.3), (0, 0, 2.55), glass)
    for x in (-0.1, 0.1):
        for y in (-0.1, 0.1):
            box((0.03, 0.03, 0.3), (x, y, 2.55), iron)
    prism(0.3, 0.3, 0.14, (0, 0, 2.85), iron)


def mailbox():
    wood = mat("post", FENCE_WOOD)
    box((0.08, 0.08, 0.8), (0, 0, 0), wood)
    rust = mat("mailbox", hexrgb("b9573d"), noise=0.25, noise_scale=14)
    box((0.26, 0.42, 0.2), (0, 0.0, 0.8), rust)
    cyl(0.13, 0.42, (0, 0.21, 1.0), rust, verts=10, rot=(math.radians(90), 0, 0))
    box((0.03, 0.12, 0.2), (0.15, 0.05, 0.9), mat("flag", hexrgb("e8402e")))


def fence(kind="h"):
    """Weathered wooden fence: "h" (one tile left-right, post on the left end),
    "broken" (a rail hanging), "v" (one tile running away from the camera),
    "post" (just the post)."""
    wood = mat("fence", FENCE_WOOD, noise=0.15, noise_scale=10, lines=("x", 0.35, 0.03, 0.8), grain=0.12)
    post = mat("fence_post", hexrgb("7d6146"))
    if kind == "post":
        box((0.11, 0.11, 0.78), (0, 0, 0), post)
        return
    if kind == "v":
        length = DEPTH_STRETCH
        box((0.11, 0.11, 0.78), (0, 0, 0), post)
        for z in (0.3, 0.58):
            box((0.06, length, 0.08), (0, length / 2, z), wood)
        return
    box((0.11, 0.11, 0.78), (-0.5, 0, 0), post)
    box((1.05, 0.06, 0.08), (0, 0, 0.58), wood)
    if kind == "broken":
        box((0.6, 0.06, 0.08), (-0.2, 0, 0.3), wood, rot=(0, math.radians(-28), 0))
    else:
        box((1.05, 0.06, 0.08), (0, 0, 0.3), wood)


# ------------------------------------------------------------------------ truck

TEAL = hexrgb("4fa3a0")


def truck(direction=0, load=0, overlay=False):
    """The beat-up pickup: faded teal with rust, open bed, facing east at
    direction 0 and turning anticlockwise in 22.5° steps. `load` 1–2 puts
    crates and sacks in the bed; `overlay` renders only the load (the truck
    cuts it out where it's in front), for the game's load overlay sprites."""
    H = holdout()
    body = H if overlay else mat("teal", TEAL, noise=0.22, noise_scale=9)
    rust = H if overlay else mat("rust", hexrgb("a8603a"), noise=0.2, noise_scale=20)
    dark = H if overlay else mat("tyre", hexrgb("2b2a2e"))
    hub = H if overlay else mat("hub", hexrgb("b8b8b0"))
    glass = H if overlay else mat("windscreen", hexrgb("9cc8e0"), noise=0.1)
    chrome = H if overlay else mat("bumper", hexrgb("9a9a96"))
    lamp = H if overlay else mat("lamp", hexrgb("ffe08a"))
    tail = H if overlay else mat("tail", hexrgb("d8402e"))
    bed_floor = H if overlay else mat("bed", hexrgb("6b4a30"), lines=("x", 0.18, 0.03, 0.7))

    root = empty("truck")
    root.rotation_euler = (0, 0, math.radians(22.5 * direction))
    parts = []

    def add(obj):
        obj.parent = root
        parts.append(obj)
        return obj

    # Chassis and bed (rear), cab and hood (front = +x).
    add(box((1.9, 0.92, 0.18), (0, 0, 0.22), body))
    add(box((0.85, 0.92, 0.04), (-0.5, 0, 0.4), bed_floor))
    for y in (-0.44, 0.44):
        add(box((0.9, 0.05, 0.32), (-0.5, y, 0.4), body))
    add(box((0.05, 0.92, 0.32), (-0.95, 0, 0.4), body))
    add(box((0.75, 0.92, 0.3), (0.55, 0, 0.4), body))          # hood
    add(box((0.62, 0.9, 0.56), (0.15, 0, 0.4), body))          # cab
    add(box((0.66, 0.94, 0.06), (0.15, 0, 0.96), body))        # cab roof
    add(box((0.04, 0.8, 0.36), (0.47, 0, 0.58), glass, rot=(0, math.radians(-18), 0)))  # windscreen
    for y in (-0.455, 0.455):
        add(box((0.4, 0.02, 0.3), (0.13, y, 0.6), glass))      # side windows
    add(box((0.3, 0.02, 0.14), (0.75, 0.465, 0.42), rust))     # rust patch
    add(box((0.25, 0.02, 0.12), (-0.6, -0.475, 0.5), rust))
    # Bumpers and lights.
    add(box((0.06, 0.98, 0.1), (0.95, 0, 0.22), chrome))
    add(box((0.06, 0.98, 0.1), (-0.97, 0, 0.22), chrome))
    for y in (-0.33, 0.33):
        add(box((0.03, 0.14, 0.09), (0.93, y, 0.5), lamp))
        add(box((0.03, 0.12, 0.08), (-0.975, y, 0.5), tail))
    # Wheels.
    for x in (-0.6, 0.6):
        for y in (-0.47, 0.47):
            add(stick((x, y - 0.07, 0.2), (x, y + 0.07, 0.2), 0.2, dark, verts=10))
            add(stick((x, y + (0.075 if y > 0 else -0.075), 0.2), (x, y + (0.08 if y > 0 else -0.08), 0.2), 0.1, hub, verts=8))

    if load:
        crate_wood = mat("cargo_crate", WOOD, noise=0.1, lines=("z", 0.12, 0.02, 0.75))
        sack = mat("cargo_sack", hexrgb("d9c48e"), noise=0.15, noise_scale=12)
        produce = mat("cargo_produce", hexrgb("e8742e"), noise=0.2, noise_scale=20)
        items = [("crate", -0.72, -0.2, 0.44), ("sack", -0.35, 0.2, 0.44)]
        if load >= 2:
            items += [("crate", -0.72, 0.22, 0.44), ("crate", -0.3, -0.22, 0.44), ("sack", -0.72, 0.0, 0.76),
                      ("crate", -0.38, 0.12, 0.76), ("produce", -0.32, -0.2, 0.74)]
        for kind, x, y, z in items:
            if kind == "crate":
                add(box((0.34, 0.34, 0.3), (x, y, z), crate_wood))
            elif kind == "sack":
                add(blob(0.2, (x, y, z + 0.16), sack, squash=(1.1, 0.9, 0.85), seed=int(x * 10)))
            else:
                add(blob(0.15, (x, y, z + 0.1), produce, squash=(1.2, 1, 0.6), seed=3))
    return root
