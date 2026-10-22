# ORDER — Detailed blue chakra charge
- Agent: Codex
- Status: REVIEW
- Priority: P0 — direct owner request
- Owner: Codex (character/VFX art and opt-in review integration)
- Branch/PR: codex/chakra-charge
- Dependencies: approved 128×128 player; integration base17d516d (includes Aki's grass/builder update)
## Objective
Create a detailed blue chakra-charge animation based on the owner's Naruto charging GIF. Support future per-instance energy color changes for upgrades/transformations without altering the character palette.
## Context / References
GIF found at Dropbox/ALL FOLDERS/SHINOBI RUSH/naruto18_k6ke2c3w.gif (six frames/900ms). Reference only; do not redistribute. Approved baseline and native production sprites define character identity and gameplay camera.
## Scope / Files owned
New charge body/VFX assets, manifests, art playback component and isolated review page. Preserve movement/combat balance/camera systems; expose activation/tint API rather than inventing leveling mechanics.
## Deliverables
128x128 eight-direction body poses; separate transparent aura/wisp/ground layers; high-frame loop with explicit authored counts, FPS and anchors; tint metadata/API; normal/half-speed preview, contact sheets, tests/report/PR/live verification.
## Acceptance Criteria / Tests
Preserve body scale/feet/design; original blue rising energy with deliberate pixel clusters; unique frames without blurred interpolation or padded duplicates; separate tintable VFX; proper occlusion and stable anchors. Import/manifest QC, Godot tests/export, actual browser review/playback/tint checks, reviewed integration and live SHA verification.
## Handoff / Notes
Other queued art orders remain separate. Blue is the default; alternate palettes are preview/API capabilities, not unlocked progression rewards.

Pre-commit acceptance:1,486 Godot checks,31 integrated chakra browser checks,11 smoke checks, native asset QC/import/manifest/export all passed. Report: [chakra charge job report](reports/2026-10-22-chakra-charge-report.md). Required PR checks and public deployment verification pending.
