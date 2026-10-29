# ORDER — Blightwood waterfall-bank reference section
- Agent: Codex
- Status: DONE
- Owner: Codex; user requested a ready-built section after finding the modular demo difficult to assemble.
- Priority: P1
- Branch/PR: codex/blightwood-river-section / [PR256](https://github.com/kiotdstudios/shinobi-rush/pull/256), merged runtime `9bf429cd29ef859918725549b73b325500ef8c6c`
- Dependencies: merged modular cliff system PR254; preserve terrain auto-blending.

## Objective
Build an editable reference-inspired stepped forest riverbank, using existing approved pieces, with a left stair approach, lush cliff tops, connected waterfall/pool and natural lower paths.

## Context / References
User's two attached screenshots compare the desired forest waterfall composition with the sparse engineering demo. The first is a composition reference, not a claim every decorative item is available.

## Scope / Files owned
Separate demo layout/preset, cliff grass presentation, isolated review route, evidence/docs/tests. Preserve normal saved maps, movement/combat/camera systems and terrain blending algorithms.

## Deliverables
Editable saved map, direct browser editor/play links, actual runtime screenshots, inventory/gap notes and tested PR/report.

## Acceptance Criteria / Tests
Load/save all map pieces without loss; climb/descend the stair; connected flowing waterfall and lower water; editable pieces; no runtime errors; normal maps unchanged. Inspect actual Web screenshots and verify canonical deployment before DONE.

## Handoff / Notes
Use existing art. Exact hanging banners and matching fern/bush sprites remain a decorative art gap; do not claim a pixel-identical recreation.

## Completed delivery
1,267 editable objects / 134 connected raised cells. Local and CI normal Godot suites: 5,135 passed / zero failures; focused checks: 62 passed; local browser: 26 passed; exact canonical live browser: 27 passed / zero errors. Main deployment and post-deploy smoke succeeded. Live [editor](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&map_editor=1&v=9bf429cd) / [play](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&editor=1&v=9bf429cd). See [report](reports/2026-10-28-blightwood-river-section-report.md) and [inventory/evidence](../../docs/visuals/river-section/README.md).
