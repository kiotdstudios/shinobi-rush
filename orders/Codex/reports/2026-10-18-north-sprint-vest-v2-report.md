# Job Report - North ninja-sprint vest stabilization v2
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner vest-motion assessment pending
- Commit / PR: Not committed; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner flagged north sprint armor reading like a swinging backpack. Final correction uses PixelLab exact copy_region editing on the original north arms-back sprint: a single torso/vest attachment cel from raw frame 5 is reused for retained raw frames 5-24, inclusive rectangle [58,46,90,75]. This stabilizes the approved broad olive plate together with its shoulder/waist attachment region. Original sprint motion outside the rectangle is preserved exactly. PixelLab edit ID 4c6b87c4-9910-4e24-83c7-881265ef192c, original source group 471a4495-8a9d-451d-9779-2a0feb371e9a.

All seven other sprint directions remain byte-identical to v1. Preserve 128x128 RGBA, uniform anatomical scale 104/108, origin [64,116], 20 distinct sprint poses, 24fps authored timeline and half-speed 12 poses/sec review. Static torso cel is intentional; whole animation frames are not duplicated and leg poses remain unique. Normal-run revisions and accepted idle/walk sets remain unchanged.

## Files changed
Local originals, rejected references, receipts, exact-edit GIF, extraction/export/comparison tools and evidence: assets/characters/player/source/sprint-review-v2/. Normalized frames and manifest: assets/characters/player/sprites/sprint-review-v2/. Published review branch contains only GIFs, README and this report.

## Tests performed before commit
- Original north source poses 5,8,11,14,17,20,23,24 inspected in PixelLab; final edited neck/shoulder/waist joins inspected at 4x in frames 6,10,14,18,22,24.
- Python assets/characters/player/source/sprint-review-v2/extract_exact.py: PASS 24 decoded frames, fixed torso crop matches source frame across all retained poses, all visible pixels OUTSIDE the edit rectangle match original source for every frame.
- Python assets/characters/player/source/sprint-review-v2/build_review.py: PASS 160 unique normalized 128px RGBA frames, binary alpha and no clipping. Seven untouched directions (140 PNGs) compare byte-identical to v1. North silhouette range 94-105px, as before.
- Python assets/characters/player/source/sprint-review-v2/compare_north.py: PASS 20-frame synchronized before/after GIF.
- Python assets/characters/player/source/sprint-review-v2/stage_godot.py and assets/characters/player/source/sprint-review-v2/run_review.ps1: PASS north, east and south-west, 20 captures each, Godot 4.5.1 OpenGL compatibility with zero runtime stderr. Other directions previously passed and remain byte-identical. Logs/captures in source/sprint-review-v2/evidence/.
- GIF decode PASS 20 frames each: normal 830ms, half 1670ms, quarter 3330ms, north comparison 1670ms. Repository order validator and staged diff check executed immediately before commit.

## Issues encountered
Two Pixen reference edits were rejected: job 4b4dafed-acb4-44bc-b883-6d9ceaca833a changed facing/added a mask; b30bdac4-cd3e-4a27-b5ef-f08e480072cb removed too much of the approved back plate. A subsequent animation from the approved north normal-run vest (group 99e09b53-8ebf-42a1-b3b0-fb60ced2a674, job f5a3dd1b-f36e-4929-a2e8-65214f7c4b6e) improved plate fit but reverted to bent-arm normal running; rejected. Final exact edit preserves the original sprint rather than using any of these candidates. Total paid attempts: three generations; exact copy_region editing free.
The torso region is deliberately held steady; perceived rigidity and overall vest motion remain subject to owner review. Engine render checks do not establish subjective visual acceptance.

## Questions for project owner
None. North-only before/after supplied for inspection.

## Outstanding work / next steps
Owner visual review of north vest and updated sprint grid. Full Order 01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay code changed or live-game playtest claimed.
