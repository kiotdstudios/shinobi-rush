# ORDER — existing ground/path to brown dirt transitions
- Agent: Codex
- Status: REVIEW — 3763/0 full native, 211/0 focused, 4/4 Web-game checks. NOT LIVE; scheduled review/integration pending.
- Branch: codex/ground-dirt-transitions
- PR: https://github.com/kiotdstudios/shinobi-rush/pull/230
- Dependencies: PR226 brown earth material, existing Ground / paths artwork.

## Objective
Create the same organic broken blending for existing ground/path material meeting brown dirt.

## Context / References
Owner requests a companion to the grass-to-dirt revision. Preserve existing art, native pixel scale, palette and 72×36 diamond grid.

## Scope / Deliverables
Reuse exact ground and soil pixels: 16 corner masks with three variations, nine familiar edge/corner aliases, contact sheet and tiled preview. Add a separate builder filter using standard floor placement/move/delete/save behavior. Do not repaint the map or modify collision, AI, camera or controls.

## Acceptance criteria
Organic broken ground/soil boundaries; native opaque diamonds without gaps; matching source colors; all variants import; builder filter, placement, movement, deletion and persistence work; required tests/report and reviewed PR integration before live completion.
