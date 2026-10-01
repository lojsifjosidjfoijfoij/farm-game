# Style test: the richer look (v2)

A mock of one screen, the farm yard by day and by night, in the look we're
aiming for: 32 pixels per tile, textured ground full of tufts and flowers,
leafy trees, cool shadows and warm light, light pools and fireflies at night,
and a wood-and-paper HUD. It's a picture, not the game: nothing here is wired
into the app yet.

```sh
# 1. Render the Blender models in the v2 look into this folder (not the app):
ACRES_ART_STYLE=v2 ACRES_ART_CATALOG=art/style_test/.catalog \
ACRES_ART_PREVIEW=art/style_test/.catalog/preview \
  uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy python art/blender/render.py

# 2. The HUD font (Fredoka, SIL Open Font License), optional:
mkdir -p art/style_test/fonts && curl -L -o art/style_test/fonts/Fredoka.ttf \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth,wght%5D.ttf"

# 3. Compose the day and night screens (and, given a reference screenshot, a comparison):
uv run --with pillow --with numpy python art/style_test/final.py [reference.png]
```

The pictures land in `art/style_test/.out/`.

- `scene.py`: the ground (grass, tufts, clover, flowers, a dirt path with
  pebbles), shadows, the objects back to front, and the night (a blue tint,
  stepped light pools, glowing windows, fireflies).
- `hud.py`: wooden frames with planks and nails, paper panels, pixel icons,
  text set at screen resolution.
- The v2 look in `art/blender/acres_art.py` (`ACRES_ART_STYLE=v2`): 32 px per
  tile, light bands tinted cool to warm, boards and shingles in varied tones,
  grain, leafy clusters, a gentler colour punch. Without the switch, renders
  are exactly as before.
