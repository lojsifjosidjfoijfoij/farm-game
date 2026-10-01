"""Shows a sprite's model in the open Blender app, looking through the game's
camera, so a person can turn it around and point at things. Run inside Blender
(e.g. through the MCP for Blender add-on), in a new empty file: it clears the
scene first.

    import sys; sys.path.insert(0, "/path/to/farm-game/art/blender")
    import live; live.show("building_barn_old")

Edits to models.py are picked up on every call. The sprites themselves are
still written by render.py from the command line (it needs Pillow, which
Blender's own Python doesn't have).
"""

import importlib

import bpy

import acres_art
import models
import render


def show(name):
    for module in (acres_art, models, render):
        importlib.reload(module)
    build, options = render.ASSETS[name]
    acres_art.reset()
    build()
    acres_art.frame_camera(*render.frame(name), top_down=options.get("top_down", False))
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.shading.type = "SOLID"
                space.shading.color_type = "MATERIAL"
                space.region_3d.view_perspective = "CAMERA"
