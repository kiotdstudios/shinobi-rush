# ORDER — Blightwood hanging vines and fern clusters
- Agent: Codex
- Status: REVIEW
- Owner: Codex; direct user request
- Priority: P1
- Branch/PR: codex/blightwood-vines-ferns
- Dependencies: merged riverbank starter PR256; preserve ongoing editor/terrain work.

## Objective
Create native pixel-art hanging vines and small fern clusters matching the existing Blightwood grass palette and reference riverbank.

## Context / References
The owner's forest waterfall reference and current riverbank starter. Existing approved grass supplies palette, scale and pixel density. Vines hang from the cliff lip; ferns grow from bank soil.

## Scope / Files owned
Three vine and three fern assets, anchors/timing metadata, subtle anchored sway, independent editor catalog/filter, riverbank dressing, previews/tests/report. No movement/combat/camera rule changes.

## Deliverables
Transparent native sprites and metadata; movable/deletable editor entries; dressed riverbank; normal/half-speed previews and actual Web screenshots; tested reviewed PR and canonical live verification.

## Acceptance Criteria / Tests
Match palette/pixel scale; no opaque backgrounds; pinned vine tops and fern roots; no waterfall/stair obstruction; correct picking/layer filtering/move/delete/history/save/reload; no colliders; zero resource/browser errors.

## Handoff / Notes
PixelLab MCP reviewed and connected. Prefer native generation with fixed sampled palette for these small props; preserve approved art files.

Implementation and local acceptance checks pass. Await reviewed PR integration and canonical deployment verification; see the matching job report.
