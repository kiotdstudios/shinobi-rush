# Ancient Flame Shrine: elevation and depth

Applies to the `dynamic_shrine` landmark (staircase, circular platform, central monument, arches).

- `scripts/environment/shrine_elevation.gd`: geometry (stairs, platform, mound) and `elevation_at()`. Elevation is a logical value; the player draws at `visual_y = ground_y - elevation`. It eases at 480 px/s, so there is no teleport.
- `dynamic_shrine.gd`: stone is built from 34 px vertical strips per layer (base, fore_l, fore_r, mon, arch_l, arch_r), each with its own y-sort key for ground level and for the upper level. Colliders: ground mound (minus the stair notch), monument ellipse, and a player-only edge body (platform rim and stair sides).
- `make_layers.py`: regenerates the layer PNGs from `stone.png` / `emission.png` (asserts an exact recomposite).
- `shrine_climb.gif`, `contact_sheet.png`: real-game capture from `tools/shot_shrine_climb.gd` (approach, climb, circle the monument, descend, walk around all sides).
- Tests: `tests/test_shrine_elevation.gd`.
