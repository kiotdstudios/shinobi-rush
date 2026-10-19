# ORDER — Close-combat camera preset and validation scene
- Agent: Kiro
- Status: IN_PROGRESS (deliverable 1 DONE and verified live; deliverable 2 not started, waiting for a chief decision)
- Priority: P1
- Owner: Kiro
- Branch/PR: kiro/camera-preset-close = PR #21, merged as eeed7d2 (deliverable 1). Deliverable 2 has no branch yet.
- Dependencies: PR #19 (owner-approved framing, merged 2026-10-19). Deliverable 2 needs deliverable 1 merged. Aki and Orcha must coordinate with Kiro before touching camera or occlusion code.

## Objective
Give the owner a configurable camera preset for the close-combat framing (standing player about 16-19 % of viewport height) without changing today's default view, then a validation scene to judge it.

## Context / References
- PR #19: `docs/visuals/CAMERA_AND_ART_DIRECTION.md` section "OWNER-APPROVED GAMEPLAY CAMERA FRAMING - 2026-10-19" and `docs/GAME_DESIGN_DOCUMENT.md` section "Owner-approved gameplay camera and scale". The owner's reference screenshot is now in the repo as reference material only: `reference/mockup/owner-close-combat-reference.png` (PR #22, committed with the owner's permission; an empty `.gdignore` keeps it out of the Godot import and the web build, checked on the live pck). It is a visual reference, not a Godot asset.
- `WorldScale.CAMERA_BASE_ZOOM` (1/2.25) and PR #12 are prototype baselines. Numeric Godot zoom stays PROVISIONAL until the owner approves it in-engine.
- Orcha's dynamic combat camera order is separate: presets only set the baseline; a director layers relative offsets on top.

## Scope / Files owned
`scripts/camera/**`, `scripts/world_scale.gd`, `scripts/player/**`, `scripts/ui/animation_lab.gd`, `scripts/web/web_bridge.gd`, `tests/**`, `scripts/ci/smoke/controls-probe.mjs`, `docs/development/**`, `docs/prototype/TESTING.md`, `orders/Kiro/**`. Not touched: `docs/visuals/**`, the GDD, `assets/`, `world/`, other agents' orders.

## Deliverables
1. Camera preset (this PR): `CameraPreset` with `wide` (default, unchanged) and `close` (computed from the figure height, snap to 1.0 inside the band), `?camera=wide|close|<number>`, lab key `N`, `camera_preset` in `__SHINOBI_STATE__`, unit tests, controls-probe checks, handoff and testing docs.
2. Validation scene (NEXT workflow, separate brief, NOT part of PR #21): an isolated comparison scene for the owner to judge wide against close. NOT STARTED: Aki's open PR #20 (`aki/camera-scale-validation`) already builds an isolated scene (composition, ground tile, gate pillars, one bandit placeholder, a zoom literal 126/108). Proposed split, waiting for the chief: Aki owns scene content and ground tiles; Kiro owns `CameraPreset` integration, a `?scene=validation` entry, stations, the measurement tool, a CI probe and props built as `Block` + `BlockRear`, after #20 lands.

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
- 2026-10-19 Kiro (orchestrator): REVIEW -> IN_PROGRESS. Deliverable 1 DONE: PR #21 (head 7fea08d, 14 files, +716/-19) merged as eeed7d2793c197f996ee547449fc45e20f6fb401 at 03:12:39Z after independent approval. PR CI run 39191291445 (492 tests passed, 0 failed; smoke 11; controls probe 13; debug probe 26); main run 39193598683 on eeed7d2, all six jobs green. Verified on the live build (default wide 0.4444 and 2880x1620; `?camera=close` 1.1667, 1097.1x617.1, standing figure 127 px = 17.6 % of 720; `?camera=bogus` wide; `?camera=2` 2.0000; 0 console errors) and re-checked on c172f6e at 08:20Z. Details in `reports/2026-10-19-chief-camera-preset.md`.
- 2026-10-19 Kiro (orchestrator): the first real art (Codex PR #23, `body_height_px` 104) turned the controls probe of PR #21 red: the probe pinned the 108 px placeholder zoom and assumed the animation lab starts closed (a CI unit test also assumed no sprites exist). Not a preset defect. Codex fixed all three inside PR #23 (merged as d9ebccf at 08:32:14Z, main run 39223465511 green: 493 tests, controls probe 16, debug probe 26, smoke 11 + 11); my own fix job was aborted to avoid colliding with it. Live check with the real art: `?camera=close` zoom 1.2115, view 1056.5x594.3, standing figure 127 px = 17.6 % of 720; default unchanged (wide 0.4444, 2880x1620). Open decisions in the chief report: lab no longer opens by itself, ground shadow removed, close zoom 1.2115 or 1.2.
