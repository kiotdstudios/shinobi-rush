# Order — Blightwood grass-palette ground/path nine tiles
- Agent: Codex
- Status: DONE
- Priority: P1
- Owner: Codex
- Branch: codex/blightwood-ground-nine
- Dependencies: Existing approved grass PNGs; satisfied.

## Objective
Owner request: extract current grass colors and create a nine-tile ground/path set.

## Context / References
Existing assets/environment/kosen_courtyard/grass/tiles/*.png,72x36 floor grid and locked faux-isometric camera.

## Scope / Deliverables
Nine ground/path PNGs, atlas, exact extracted palette, source provenance, export script and previews. Owner-approved expansion: integrate nine tiles in world builder with dedicated Ground / paths filter and publish live.

## Acceptance Criteria
Nine unique72x36 RGBA tiles, consistent diamond footprint, palette limited to actual grass colors, Godot imports and loads every tile, assembled preview reviewed. Passed; see report. Owner approved. Local tests passed; PR144 merged and exact live build4fd5e7c verified with11browser checks.

## Handoff
Use role order and resource paths in ground-nine.art.json. Longer repetitions have organic, non-bit-identical joins. Deployed and verified:https://kiotdstudios.github.io/shinobi-rush/?editor=1&v=4fd5e7c
