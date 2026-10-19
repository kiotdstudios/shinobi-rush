# ORDER — Close-combat camera preset and validation scene
- Agent: Kiro
- Status: REVIEW
- Priority: P1
- Owner: Kiro
- Branch/PR: kiro/camera-preset-close (deliverable 1; PR number in the status log)
- Dependencies: PR #19 (owner-approved framing, merged 2026-10-19). Deliverable 2 needs deliverable 1 merged. Aki and Orcha must coordinate with Kiro before touching camera or occlusion code.

## Objective
Give the owner a configurable camera preset for the close-combat framing (standing player about 16-19 % of viewport height) without changing today's default view, then a validation scene to judge it.

## Context / References
- PR #19: `docs/visuals/CAMERA_AND_ART_DIRECTION.md` section "OWNER-APPROVED GAMEPLAY CAMERA FRAMING - 2026-10-19" and `docs/GAME_DESIGN_DOCUMENT.md` section "Owner-approved gameplay camera and scale". The owner's reference screenshot is not in the repo and must not be committed.
- `WorldScale.CAMERA_BASE_ZOOM` (1/2.25) and PR #12 are prototype baselines. Numeric Godot zoom stays PROVISIONAL until the owner approves it in-engine.
- Orcha's dynamic combat camera order is separate: presets only set the baseline; a director layers relative offsets on top.

## Scope / Files owned
`scripts/camera/**`, `scripts/world_scale.gd`, `scripts/player/**`, `scripts/ui/animation_lab.gd`, `scripts/web/web_bridge.gd`, `tests/**`, `scripts/ci/smoke/controls-probe.mjs`, `docs/development/**`, `docs/prototype/TESTING.md`, `orders/Kiro/**`. Not touched: `docs/visuals/**`, the GDD, `assets/`, `world/`, other agents' orders.

## Deliverables
1. Camera preset (this PR): `CameraPreset` with `wide` (default, unchanged) and `close` (computed from the figure height, snap to 1.0 inside the band), `?camera=wide|close|<number>`, lab key `N`, `camera_preset` in `__SHINOBI_STATE__`, unit tests, controls-probe checks, handoff and testing docs.
2. Validation scene (NEXT workflow, separate brief, NOT part of this PR): an isolated comparison scene for the owner to judge wide against close.

## Acceptance Criteria / Tests
- No parameter: wide, zoom 0.4444, view 2880x1620 (unchanged).
- `?camera=close`: `camera_preset=close`, zoom 1.1667, view about 1097x617, standing figure about 126 px (17.5 % of 720).
- Garbage falls back to wide; `?camera=2` gives zoom 2.
- Head and feet visible at the north and south walls, no void, lab open/close restores the active baseline.
- In-engine tests green; a new test fails when the default is flipped or the parser accepts garbage (shown); required CI green.

## Handoff / Notes
- Report: `orders/Kiro/reports/2026-10-19-camera-preset-report.md`.

## Status log
- 2026-10-19 Kiro: QUEUED -> IN_PROGRESS. Preset module, wiring, tests and local Web verification done on branch kiro/camera-preset-close.
- 2026-10-19 Kiro: IN_PROGRESS -> REVIEW. PR open, CI status in the report. NOT merged and NOT DONE: the orchestrator merges and sets DONE after the live build is verified. Deliverable 2 (validation scene) is still to do.
