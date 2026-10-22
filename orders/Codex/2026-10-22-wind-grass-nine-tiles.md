# ORDER — Palette-matched nine-tile animated grass

- Agent: Codex
- Status: DONE
- Priority: P0 — direct owner request
- Owner: Codex (environment art, decorative wind animation)
- Branch/PR: `codex/wind-grass-nine` / https://github.com/kiotdstudios/shinobi-rush/pull/85 (merged)
- Dependencies: review Aki floor PR #75; current main with tree collision/vision updates

## Objective
Review Aki's delivered ground tiles and add detailed, wind-swept grass inspired by Ghost of Tsushima's world motion. Match the current floor palette and deliver a reusable nine-tile terrain family.

## Context / References
Existing `KosenFloorTileset`:72×36 isometric logical diamonds; nine terrain roles plus four additional center variants,13 textures total. Use existing slate/moss colors and compatible subdued foliage highlights. Preserve the existing ground, tree collision, navigation, player and camera controllers.

## Scope / Files owned
New grass assets/manifest, nine-role TileSet builder, decorative wind component, additive scene placement and review controls. No replacement of Aki's accepted floor assets or gameplay changes.

## Deliverables
Floor audit with findings; center/four edges/four corners; transparent overflow for detailed blades; smooth multi-phase rooted wind with spatial gusts; live patches beside existing courtyard/tree art; nine-tile assembly/contact sheet, native/half-speed preview, tests/report/PR/deployment evidence.

## Acceptance Criteria / Tests
Correct72×36 logical grid and nine semantic roles; palette fit; no opaque ground plates or blade clipping; connected patches without straight internal cuts; blade roots stable, tips bend in waves rather than the whole ground sliding. Normal gameplay remains usable. Asset QC, unit/resource checks, Web export, real browser seam/motion/root tests, reviewed PR and verified exact live SHA.

## Completion
Deployed build1a151d693b833a859ef67f19f635b0e2a6a5182f.1287tests passed; all15 grass browser checks and exact-SHA public smoke passed. Live review: https://kiotdstudios.github.io/shinobi-rush/?grass=review&v=1a151d6 . Full evidence in reports/2026-10-22-wind-grass-nine-tiles-report.md.
