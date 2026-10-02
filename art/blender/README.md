# Blender art

The game's real sprites are modelled in Blender, from Python, and rendered straight into the
asset catalog (`Acres/Resources/Assets.xcassets/Art/`). There's nothing to open in Blender by hand:
each sprite is a small function in `models.py`, and `render.py` turns it into pixel art.

## Re-rendering

You need Python 3.11 and Blender's Python module (no Blender app needed):

```sh
pip install "bpy==4.5.*" pillow numpy
python3 art/blender/render.py                         # everything
python3 art/blender/render.py building_barn_old       # one sprite
python3 art/blender/render.py vehicle_truck_old       # every name starting with this
```

With [uv](https://docs.astral.sh/uv/) there's nothing to install by hand (bpy 4.5 needs Python 3.11):

```sh
uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy python art/blender/render.py
```

It takes about 20 seconds for the lot, on the CPU. The PNGs go into the catalog (each with its
`Contents.json`), and a copy of each goes into `art/blender/.renders/preview/` (git-ignored).

To see them together (these two need only Pillow and NumPy, not Blender):

```sh
uv run --with pillow --with numpy python art/blender/mockup.py first_screen.png   # a hand-placed farm yard, shown 4×
uv run --with pillow --with numpy python art/blender/preview.py sheet.png prop_well prop_crate   # a contact sheet
```

## Working live in the Blender app

With the [MCP for Blender](https://github.com/ahujasid/blender-mcp) add-on connected (its
sidebar tab says "Connected on port 9876") and `claude mcp add blender uvx mcp-for-blender` done,
a Claude session on the same Mac can load any model into the open Blender window to look at
together, in a new empty file (it clears the scene):

```python
import sys; sys.path.insert(0, "/path/to/farm-game/art/blender")
import live; live.show("building_barn_old")
```

This works in Blender 4.5 and 5.x. Rendering the sprites always uses Blender 4.5 (the `uv`
command above, separate from the app), because the compositor's Python API changed in 5.0.
`live.show` looks through the game's camera with flat material colours; orbit with the middle mouse
button (or two fingers on a trackpad) to look around, and press numpad 0 to get back to the
camera. Change the model in `models.py`, call `live.show` again, and when it's right, write the
sprite with `render.py` from the command line as above. Leave the add-on's asset libraries and
AI model generation off: those bring in other people's models, in other styles.

## How a sprite is made

- **Size and anchor** come from `docs/ASSETS.md` (generated from `AssetManifest`), so a render
  always fits the slot the game gives it: 32 pixels per tile, the anchor on the foot point.
- **Camera:** orthographic, looking down at 40°, the same for every sprite. 1 Blender unit is one
  tile; x is east, y is north (away from the camera), z is up, and the foot point is the origin.
  Only the south faces show, so the depth of a thing shows at sin 40°.
- **Light:** a sun from the upper left (west faces bright, south faces a step darker, east faces
  darkest), plus a little sky light. The compositor squeezes it into three flat bands, so shading
  is toon-like rather than smooth.
- **Pixel pass** (`acres_art.pixelize`): rendered 4× too big, shrunk by averaging, hard-edged
  alpha, the same saturation/contrast punch as the game's drawn art (`PixelArt.swift`), 16 steps
  per colour channel, and a dark one-pixel outline.
- **Overlays** (night lights, the truck's loads) are rendered with everything else in the scene
  turned into a holdout, so the overlay lines up with the sprite and is hidden where the sprite
  is in front of it.

## Adding a sprite

1. Make sure the name is in `AssetManifest` (and so in `docs/ASSETS.md`).
2. Write a model function out of the helpers in `acres_art.py` (`box`, `cyl`, `stick`, `blob`,
   `prism`, `mat`): `models.py` has the first batch (farmhouse, barn, oak, pine, props, truck),
   `models_farm.py` the crops (one function per crop, stages 0–4), the other trees (all seasons,
   young, saplings, fruit overlays), the farmhouse tiers, farm buildings and props, and
   `models_people.py` one adjustable figure for the farmer, farmhands and villagers (`LOOKS`
   for clothes and hair, `POSES` for hands and feet per frame, built facing the camera and
   turned for "up" and "side"), `models_animals.py` one adjustable animal body (idle, walk,
   eat, asleep, facing left) and `models_village.py` the village buildings (with their night
   windows), village props, the farm's workshops and the village projects (the windmill's
   sails render as six overlay frames, 15° apart, with the mill cut out). Flat water (the pond, Willow Lake, lily
   pads) is drawn as pixel art by `art/terrain/make_water.py` instead.
4. Item icons and Arne's portrait come from `icons.py` (run it like `render.py`): small models
   framed to fill a 20 × 20 icon (26 × 26 for the portrait), rendered through the same toon
   pass. The small world effects (puffs, sparkles, drops, the tile ring, bubbles) are drawn by
   `art/fx/make_fx.py`.
3. Register it in `ASSETS` in `render.py`, render it, and look at it with `preview.py` and
   `mockup.py`.

The game picks the PNG up by name instead of the placeholder; no code changes. If a sprite has
something the game points at (the farmhouse chimney's smoke), the point is in
`WorldObjectFactory.swift`, worked out with `acres_art.screen_point`.

## Done so far

Batch 1, the first screen: the run-down farmhouse (and its night lights), the old barn, oaks in
four seasons, young oak and birch, bushes, rocks, stump, grass tufts, wheat in all five stages,
well, hay bale, crate, log pile, mailbox, the wooden fence and the truck
in 16 directions with both loads.

## The look (v2)

Renders are the v2 look by default: 32 px per tile, light bands tinted from cool shadow to warm
light, boards and shingles in varied tones, grain, leafy clusters, and a crisp shrink (each pixel
the most common colour of its samples, from a palette picked per sprite). `ACRES_ART_STYLE=v1`
gives the older, flatter 16 px look for comparison (write it somewhere else with
`ACRES_ART_CATALOG`). The mock screen it was agreed on is in
[`art/style_test/README.md`](../style_test/README.md).
