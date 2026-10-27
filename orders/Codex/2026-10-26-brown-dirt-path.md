# ORDER — brown/tan dirt path matching grass edges
- Agent: Codex
- Owner: Codex
- Status: REVIEW � art ready; 3498/0 full native tests, 124/0 focused floor/import checks; not live
- Branch: codex/brown-dirt-path
- PR: https://github.com/kiotdstudios/shinobi-rush/pull/226
- Dependencies: approved grass tiles and full-diamond floor standard

## Objective
Create brown/tan earth tiles for the player's travel path, with matching grass edge topology and registration so path and grass blend.

## Context / References
Current `grass9_*` art, `(56,84)` anchor on 112×112 canvas; existing 72×36 diamond lattice; `2026-10-25-full-diamond-floor-tiles.md`. Owner's new request overrides the older exact-green-palette request for this sibling earth material.

## Scope / Deliverables
Art-only sibling pack: nine named roles, all 16 exposed-side masks for narrow paths/bends, transparent PNG atlas, palette/material source, manifest, grass-blend preview, ZIP and integration notes. Preserve approved ground/grass. No gameplay, catalog, saved layout or terrain-painting changes in this art delivery.

## Acceptance Criteria
Brown/tan readable earth; exact existing logical cell and grass anchor; correct edge/corner roles; 100% opaque diamond coverage; original grass fringe on exposed sides only; no inner grass seams between connected path tiles; sharp pixel clusters; Godot imports pass; floor coverage regression passes; report and art PR. Explicitly mark not live until integrated.
