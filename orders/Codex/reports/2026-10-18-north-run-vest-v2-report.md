# Job Report - North run fitted vest revision
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner vest motion assessment pending
- Commit / PR: 4c3d2ed; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner rejected the north run vest moving like a backpack. PixelLab north-only group bcece7c3-f57b-4598-8850-1f8095c2e488, job 9a786628-e176-428f-a7b5-17650fe8a976, replaces the 20 north poses with a fitted back panel intended to follow the torso. Inspected reference-scale frames 1,5,9,13,17,20: the vest stays between the shoulders and waist through alternating running poses. Subjective motion acceptance remains with the owner.

Other seven directions preserved byte-for-byte. Retained 128x128 RGBA, same uniform anatomical scale 104/108, nominal ground origin [64,116], authored 24fps timeline and half-speed review default at 12 poses/sec. New source canvas is 128x160; normalized north silhouette spans 98-108px through stride, without frame-by-frame scaling.

## Files changed
Local source and review tooling: assets/characters/player/source/run-review-v2/. Normalized frames and manifest: assets/characters/player/sprites/run-review-v2/. Published review branch includes timed GIFs, north before/after comparison, README and this report only. Original v1 remains preserved.

## Tests performed before commit
- PixelLab workbench inspect of six evenly spaced north poses: checked vest panel, straps, torso rotation and anatomy.
- Python assets/characters/player/source/run-review-v2/build_review.py: PASS 160 unique normalized RGBA frames, binary alpha, no clipping; all 140 PNGs in the other seven directions compare byte-identical to v1. Exports three looping 20-frame review GIFs.
- Python assets/characters/player/source/run-review-v2/stage_godot.py and assets/characters/player/source/run-review-v2/run_review.ps1: PASS revised north and unchanged south-east. Godot 4.5.1 OpenGL compatibility, 20 captured frames each, zero runtime stderr. Other seven directions had passed v1 checks and their PNGs remain identical. Logs/captures under source/run-review-v2/evidence/.
- Python assets/characters/player/source/run-review-v2/compare_north.py: PASS 20-frame half-speed before/after GIF with synchronized timer.
- Decoded durations and repository order validator/staged diff checks run immediately before commit.

## Issues encountered
Generation began while the session was read-only; export/testing resumed after write access was restored. No known rendering/integrity failure. Engine captures validate rendering, not whether every viewer perceives the vest as fitted; owner review remains necessary.

## Questions for project owner
None. Revised motion supplied for inspection.

## Outstanding work / next steps
Owner visual review, then continue distinct arms-back ninja sprint. Full Order 01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay files changed or live-game playtest claimed.

Public verification: north-comparison and half-speed eight-direction GIFs both HTTP 200, 20 frames, 1670ms. Comparison 800x560, eight-direction grid 600x1240. https://raw.githubusercontent.com/kiotdstudios/shinobi-rush/codex/mobile-animation-preview/assets/characters/player/previews/mobile/run-v2-north-comparison.gif
