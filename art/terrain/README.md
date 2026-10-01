# Ground textures

`make_terrain.py` generates the ground as pixel art, straight into the asset catalog:
`terrain_grass` (tufts, clover, leafy weeds, flowers, daisy patches), `terrain_dirt` (tan
speckle, pebbles), `terrain_gravel` and `terrain_asphalt`. Each is 512 × 512: one chunk of
16 × 16 tiles at 32 px per tile, seamless, so the pattern doesn't visibly repeat on screen.

```sh
uv run --with pillow --with numpy python art/terrain/make_terrain.py
```

The game's ground shader (`Acres/World/TerrainRenderer.swift`) picks one of these per pixel,
never a blend, with ragged edges, a darker rim on the path side and grass tufts poking over it.
