"""Renders Acres art from the Blender models into the app's asset catalog.

    python3 art/blender/render.py               # everything
    python3 art/blender/render.py building_barn_old   # just these (asset names or prefixes)

Previews (the bare sprites) also go to art/blender/.renders/preview/.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import re  # noqa: E402

import acres_art as art  # noqa: E402
import models  # noqa: E402

PREVIEW = os.path.join(os.path.dirname(__file__), ".renders", "preview")



def frame(name):
    """(tiles_w, tiles_h, anchor_y) of a sprite, from docs/ASSETS.md (made from
    the game's asset manifest), so renders always match what the game expects."""
    doc = os.path.join(art.REPO, "docs", "ASSETS.md")
    family = re.sub(r"_dir\d\d$", "_dir00", name)  # direction sets are one row
    with open(doc) as f:
        for line in f:
            m = re.match(r"\| `%s`[^|]*\| [^|]+ \| ([\d.]+) × ([\d.]+) \| ([\d.]+|—) \|" % re.escape(family), line)
            if m:
                anchor = 0.5 if m.group(3) == "—" else float(m.group(3))
                return float(m.group(1)), float(m.group(2)), anchor
    raise KeyError(f"{name} is not in docs/ASSETS.md")


FLAT = {"outline": False, "top_down": True}
GLOW = {"outline": False, "soft": True}

# name → (builder, render options).
ASSETS = {
    "building_farmhouse_t0": (models.farmhouse_t0, {}),
    "building_farmhouse_t0_lights": (lambda: models.farmhouse_t0(night=True), GLOW),
    "building_barn_old": (models.barn_old, {}),
    **{f"tree_oak_{season}": ((lambda s=season: models.oak(s)), {}) for season in ("spring", "summer", "autumn", "winter")},
    "tree_oak_young": (lambda: models.young_tree("oak"), {}),
    "tree_birch_young": (lambda: models.young_tree("birch"), {}),
    "nature_bush_a": (lambda: models.bush(wide=False), {}),
    "nature_bush_b": (lambda: models.bush(wide=True), {}),
    "nature_rock_small": (lambda: models.rock(large=False), {}),
    "nature_rock_large": (lambda: models.rock(large=True), {}),
    "tree_stump": (models.stump, {}),
    "nature_grass_tuft_a": (lambda: models.grass_tuft(False), {"outline": False}),
    "nature_grass_tuft_b": (lambda: models.grass_tuft(True), {"outline": False}),
    **{f"crop_wheat_stage{k}": ((lambda k=k: models.wheat(k)), {} if k else {"outline": False}) for k in range(5)},
    "field_soil_plowed": (lambda: models.soil(False), FLAT),
    "field_soil_watered": (lambda: models.soil(True), FLAT),
    "prop_well": (models.well, {}),
    "prop_hay_bale": (models.hay_bale, {}),
    "prop_crate": (models.crate, {}),
    "prop_log_pile": (models.log_pile, {}),
    "prop_mailbox": (models.mailbox, {}),
    "prop_fence_wood_h": (lambda: models.fence("h"), {}),
    "prop_fence_wood_h_broken": (lambda: models.fence("broken"), {}),
    "prop_fence_wood_v": (lambda: models.fence("v"), {}),
    "prop_fence_wood_post": (lambda: models.fence("post"), {}),
    **{f"vehicle_truck_old_dir{d:02d}": ((lambda d=d: models.truck(d)), {}) for d in range(16)},
    **{f"vehicle_truck_old_load{n}_dir{d:02d}": ((lambda d=d, n=n: models.truck(d, load=n, overlay=True)), {})
       for n in (1, 2) for d in range(16)},
}


def main(selected):
    names = [n for n in ASSETS if not selected or any(n == s or n.startswith(s) for s in selected)]
    for name in names:
        build, options = ASSETS[name]
        art.reset()
        build()
        art.render(name, frame(name), preview_dir=PREVIEW, **options)
        print("rendered", name)


if __name__ == "__main__":
    main(sys.argv[1:])
