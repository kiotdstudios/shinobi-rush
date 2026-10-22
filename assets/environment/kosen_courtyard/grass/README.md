# Kosen nine-role wind grass

Matches Aki's72×36 isometric floor grid and slate/dark-olive palette. Nine terrain pieces: top corner, NE edge, right corner, NW edge, center, SE edge, left corner, SW edge, bottom corner. Four optional tall silvergrass accents add readable curved blades and fine seed heads without changing the nine-role topology.

## Runtime and animation

- Ground art:112×112 RGBA, source root `[56,84]`, TileData origin `[0,28]`.
- Tall art:112×160 RGBA, source root `[56,136]`, TileData origin `[0,56]`.
- Logical diamond72×36, nearest filtering, alpha background, no physics/navigation layers.
- Wind: **144 runtime phases /24 FPS /6seconds**, not144 hand-painted PNGs. Nearest-sampled rooted deformation bends tips, adds fine follow-through and carries a world-space gust across neighboring cells. Root rows remain fixed. Normal strength1; Gust1.6. Analytic swept-bound QC checks the strong-gust displacement against every occupied row.
- A single shared shader material per layer, two Y-sorted TileMapLayers,247 ground cells and111 deterministic tall accents across five planted areas in the west courtyard. Tall growth avoids the existing tree-trunk/stone footprints. No per-frame sprite spawning or ever-growing particle count.

`WindGrassTileset.role_at(x,y,width,height)` selects the nine-slice role for rectangular patches. Native tile indices use Godot's diamond-down grid. Corner selection is based on local patch adjacency rather than the stone floor's arena-perimeter rule. Fields larger than3×3 repeat the center/edge roles. Visual texture continuity is organic overlap/fringe; these are not advertised as bit-identical periodic texture borders.

`?grass=review` provides meadow, assembled nine-piece patch, close view, isolated blade and player-follow views. Normal/half speed, pause, one-frame step, wind toggle and Gust are independent of gameplay timing. Normal game loads the planted grass too. The optional review camera/UI does not edit Kiro's controller. Aki's World Builder integration remains separate; this delivery does not add a grass painting tool to its solid-object catalog.

## Source and palette

Original art made with built-in image generation, as separate nine-terrain and four-tall-stand sheets. Source sheets are preserved under `source/` and excluded from runtime. Fixed shared-scale nearest extraction, magenta cleanup, palette mapping and explicit root registration are reproducible with:

```
python docs/visuals/wind-grass-nine/export_grass.py
python docs/visuals/wind-grass-nine/asset_qc.py
```

All13 assets are unique and contain only the22-color manifest palette. Exact floor slate/moss shadow RGB values are retained, with a derived desaturated sage/straw highlight ramp. No paid PixelLab generation was used; read-only capability review found generative tools do not guarantee exact palette/anchor preservation, so deterministic export establishes those constraints.

See `docs/visuals/wind-grass-nine/FLOOR_REVIEW.md`, contact sheets, actual renderer capture and report for QA. Source and animated art are Codex-owned; floor, collision, AI, world-editor logic and gameplay remain with their existing owners.
