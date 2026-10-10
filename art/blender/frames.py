"""Sprite frames from docs/ASSETS.md (made from the game's asset manifest), so
renders and mockups always match what the game expects. No Blender needed."""

import os
import re

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def frame(name):
    """(tiles_w, tiles_h, anchor_y) of a sprite. A night-light overlay
    (`…_lights`) is framed exactly like its building, so the glow lands on the
    windows: the list shows no anchor for light layers, and the middle of the
    frame would put the windows up on the roof."""
    if name.endswith("_lights"):
        base = name[: -len("_lights")]
        try:
            return frame(base)
        except KeyError:
            pass
    doc = os.path.join(REPO, "docs", "ASSETS.md")
    family = re.sub(r"_dir\d\d$", "_dir00", name)  # direction sets are one row
    with open(doc) as f:
        for line in f:
            m = re.match(r"\| `%s`[^|]*\| [^|]+ \| ([\d.]+) × ([\d.]+) \| ([\d.]+|—) \|" % re.escape(family), line)
            if m:
                anchor = 0.5 if m.group(3) == "—" else float(m.group(3))
                return float(m.group(1)), float(m.group(2)), anchor
    raise KeyError(f"{name} is not in docs/ASSETS.md")
