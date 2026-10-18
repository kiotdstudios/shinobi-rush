# Job Report - East run arm correction v3
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner arm motion assessment pending
- Commit / PR: e36ce42; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner noted east's arm looking dragged during several run poses. Inspected all 20 original east frames in PixelLab; rear hand holds behind the hip through much of frames 6-12 instead of a continuous opposing pump. Queued east-only correction: 20 poses, bent elbows, prompt return swing, no trailing straight arm. PixelLab group 7bfaed40-6e08-4de3-9db6-fbb75c9902fa, job b7399f1d-63b2-47e1-b59b-fda5647e5f68.

Preserve all seven other run-v2 directions, especially the revised north vest. Keep approved 128px anatomical scale and origin [64,116], half-speed 12 poses/sec review, 20-tick clock. No procedural deformation or duplicate filler.

## Files changed
Local source, receipts, export/comparison tooling and Godot evidence: assets/characters/player/source/run-review-v3/. Normalized frame exports: assets/characters/player/sprites/run-review-v3/. Published branch will contain review GIFs/README/report only.

## Tests performed before commit
Original and replacement east full-frame inspections complete (all 20 poses, PixelLab workbench). Replacement alternates forward and rear bent-arm poses more frequently instead of the original long rear-hand hold. Python assets/characters/player/source/run-review-v3/build_review.py: PASS 160 unique normalized 128x128 RGBA frames, binary alpha and no clipping; 140 PNGs from the seven other v2 directions are byte-identical. East height range 91-101px through running poses with unchanged uniform scale. Python assets/characters/player/source/run-review-v3/compare_east.py: PASS 20-frame synchronized before/after GIF. GIF decode checks PASS 20 frames, normal 830ms, half 1670ms, quarter 3330ms; comparison 1670ms. Python assets/characters/player/source/run-review-v3/stage_godot.py and assets/characters/player/source/run-review-v3/run_review.ps1: PASS east and preserved north; 20 captured frames each, Godot 4.5.1 OpenGL compatibility, zero runtime stderr. Other directions were verified previously and remain byte-identical. Logs/captures in source/run-review-v3/evidence/. Order validation and staged diff check run before commit.

## Issues encountered
Session initially read-only; generation queued remotely, export resumed after write access returned. No final asset acceptance claimed.

## Questions for project owner
None. Corrected candidate will be provided for visual review.

## Outstanding work / next steps
Inspect generated arm swing, export/check, publish before/after and updated eight-direction run preview. Full Order 01 remains incomplete; sprint and other states outstanding. Live deployment: not applicable to review-only GIFs; no gameplay code changed.

Public verification: east-comparison and eight-direction half-speed GIFs both HTTP 200, 20 frames, 1670ms loop. Comparison 800x560; grid 600x1240. https://raw.githubusercontent.com/kiotdstudios/shinobi-rush/codex/mobile-animation-preview/assets/characters/player/previews/mobile/run-v3-east-comparison.gif
