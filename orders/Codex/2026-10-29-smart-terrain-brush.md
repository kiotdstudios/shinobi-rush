# ORDER — Smart Terrain Brush and Tile Family Detection
- Agent: Codex
- Owner: Codex, explicitly assigned by owner in this chat
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/smart-terrain-brush
- Dependencies: merged #245/#251

## Objective
Paint terrain by selecting related tiles; group by metadata first and offer pixel edge/color suggestions requiring manual approval.

## Context / References
Owner request continues Fire Animation Variations. #245/#251 are merged in main 090d8688; #253 records deployment evidence. Later cliff/foliage changes through #261 preserve the blending algorithm.

## Scope / Files owned
Tile-family detection, existing editor auto-tiler integration, layout approvals/history, connected fill, tests and browser proof. No unrelated gameplay or art changes. Separate checkout preserves other Codex work; coordination notice sent to Initialize Shinobi Rush game.

## Deliverables
Smart palette paint, review/override dialog, persistent approvals, bounded fill, native tests, browser evidence, PR and job report.

## Acceptance Criteria / Tests
72x36 lattice; deterministic corners and existing A/B/C variation; metadata before pixels; no implicit pixel approvals; paint/erase/fill/undo/redo/save/reload; resource and Web verification; normal reviewed CI/integration/live verification.

## Handoff / Notes
Four-material diamonds retain the existing documented fallback. Approved materials use registered terrain kits; suggestions do not synthesize new transition art.

## Local validation
33 focused native checks, 13 Smart Brush browser checks, 27 existing Auto Blend browser checks, 448/30/2 resource validation and Web export/content checks passed. Full native regression remains running. #262 foundation is incorporated; final integration and canonical verification pending.
