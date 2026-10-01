# HUD art

`make_hud.py` generates the wood-and-paper HUD as pixel art, straight into the asset catalog:

- **Frames** (`ui_hud_panel`, `ui_hud_wood`, `ui_hud_slot`, `ui_hud_slot_selected`,
  `ui_hud_button`, `ui_hud_button_quiet`): drawn at art scale and saved twice as big, so one art
  pixel is 2 points. The game stretches them with fixed corners and tiled edges and middle
  (`PixelFrame` in `Acres/UI/HUDStyle.swift`, cap inset = 2 × the border listed there).
- **Icons** (`ui_icon_*`): 12 × 12 art pixels, shown at 24 points with no smoothing. Round
  things (coin, star, sun, moon, clouds) are drawn from shapes with automatic outline and
  shading; tools and the rest are hand-placed pixels.

```sh
uv run --with pillow --with numpy python art/hud/make_hud.py
```

The font is Fredoka (`Acres/Resources/Fonts`, SIL Open Font License, see `Fredoka-OFL.txt`).
