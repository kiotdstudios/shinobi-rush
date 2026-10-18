# Job Report - South normal-run cadence audit and revision v4
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner cadence assessment pending
- Commit / PR: Not committed; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner suspected a duplicated south normal-run frame. Audited all 20 run-v3 south frames: no exact duplicate RGBA poses. Consecutive changed-pixel counts range 1946-2615, with 2364 changed pixels at the loop seam. Closest nonconsecutive pose pairs include frames 10/18 and 15/18 (385 changed pixels each). Half-speed GIF durations are 80/90ms for every frame, with no double-length hold. All 20 frames inspected on .tools/south-run-frame-audit.png. Similar stride poses plus the upright first two poses can create a perceptual cadence hitch even though the files are unique.

Queued south-only replacement from an already-running reference with pinned running end pose: PixelLab group a7bcbca7-0210-48e6-bc04-a359b6bf390e, job b28c3343-f30f-4ee8-8ec7-12df9a075f47, 20 generated poses, one generation. Preserve seven other run-v3 directions including east arm and north vest corrections. Sprint review v1 remains separate and unchanged.

## Files changed
Local raw source/export/comparison tooling/evidence: assets/characters/player/source/run-review-v4/. Normalized frames/manifest: assets/characters/player/sprites/run-review-v4/. Published branch limited to review GIFs/docs/report.

## Tests performed before commit
Original south pixel hashes, pairwise differences, consecutive differences, all-frame visual inspection and GIF timing audit completed. Replacement all 20 poses inspected in PixelLab workbench; starts/ends running instead of the old upright lead-in. Python assets/characters/player/source/run-review-v4/build_review.py: PASS 160 unique normalized 128px RGBA frames, binary alpha/no clipping; seven other directions compare byte-identical to run-v3. Python assets/characters/player/source/run-review-v4/audit_cadence.py: PASS 20 unique south poses; v4 adjacent changed pixels 1394-2164 and seam 1645, versus v3 1946-2615 and seam 2364. Reduced pixel change is diagnostic only, not proof of subjective smoothness. Python assets/characters/player/source/run-review-v4/compare_south.py: PASS 20-frame comparison. Final decoded GIFs PASS 20 frames: normal 830ms, half 1670ms, quarter 3330ms, comparison 1670ms. Python assets/characters/player/source/run-review-v4/stage_godot.py and assets/characters/player/source/run-review-v4/run_review.ps1: PASS south, east, north; 20 captures each, Godot 4.5.1 OpenGL compatibility, zero runtime stderr. Other directions previously passed and remain byte-identical. Logs/captures in source/run-review-v4/evidence/. Order validator and staged diff check run before commit.

## Issues encountered
No exact file duplicate or repeated GIF index found. Distinguish this finding from subjective repeated gait poses; a unique image is not proof of a smooth animation.

## Questions for project owner
None. Revised comparison will be supplied for inspection.

## Outstanding work / next steps
Inspect replacement, export/check, publish south comparison and updated run grid. Sprint review remains pending owner feedback. Full Order 01 incomplete. Live deployment: not applicable to review-only GIFs; no gameplay files changed.

South silhouette height is 88-95px through the new mid-run poses, versus 93-108px including the old upright lead-in and stronger hair spikes. No compensating per-frame scaling was applied; uniform scale 104/108 and nominal ground origin [64,116] remain unchanged. Body/pose perception and cadence acceptance remain for owner review.
