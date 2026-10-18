# Job Report - East and north-west shoulder breathing v5
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner visual assessment pending
- Commit / PR: Not committed; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Revised east and north-west to show shoulder and upper-arm breathing. Preserved all six other v4 directions byte-for-byte, including south-east. Retained 128x128 exports, synchronized timer, 16 timeline ticks and half-speed default (12 ticks/sec, 1.333s breath).

PixelLab generated two candidates per direction. Free PixelLab pixelart_workbench copy_region edits then held the head and lower-body cels steady while preserving generated shoulder motion. No frame interpolation, resynthesized filler or procedural deformation. Final east source group 69b3afe2-18d4-4464-9e3c-43797e58cf1b; final north-west source group be51a740-8f73-41c5-b45d-cad6b0520f13. Exact-edit IDs east 3a48372d-4eb7-4907-8636-fcb92887bb92 and north-west 39fa5c0f-9761-4b4e-8018-714b3f76e4f9.

## Files changed
- Local source, PixelLab receipts, original candidates, exact GIF exports, scripts, shoulder metrics and comparison: assets/characters/player/source/idle-review-v5/.
- Normalized frames and manifest: assets/characters/player/sprites/idle-review-v5/.
- Mobile review GIFs/README and this report only are published on the existing preview branch. Full art implementation remains separate.

## Tests performed before commit
- Extracted 16 frames from each PixelLab exact-edit GIF. Both clips retain 16 unique poses. Verified fixed head and lower-body rectangles byte-for-byte across all frames.
- Python assets/characters/player/source/idle-review-v5/refine_idle.py: PASS 128px RGBA normalization, no clipping, six unchanged-direction byte comparisons, 16-frame looping GIF export.
- Python assets/characters/player/source/idle-review-v5/check_shoulders.py: PASS metrics and comparison sheet generated. Inspected frames 0,3,6,9,12,15 against v4 for shoulders, neck/waist joins, facing and feet.
- Upper-arm warm-pixel vertical centroid span: east 0.424px to 0.682px; north-west 0.029px to 3.290px. This is a silhouette-region proxy, not exact joint tracking. East change is subtler than north-west and remains subject to owner assessment.
- Final normalized head horizontal centroid span east 0.169px, north-west 0.367px; feet span 0px for both. The head metric includes some collar pixels; the protected raw head region itself is identical across frames.
- Python assets/characters/player/source/idle-review-v5/stage_godot.py and assets/characters/player/source/idle-review-v5/run_review.ps1: PASS east, north-west, south-east; Godot 4.5.1 OpenGL compatibility, 16 captured frames per direction, zero runtime stderr. Evidence in source/idle-review-v5/evidence/.

## Issues encountered
Unconstrained generations restored lateral drift, so those candidates were rejected. Exact PixelLab cel copying preserves shoulder motion while eliminating head/lower-body drift. Raw generated groups and edit receipts are retained for reproducibility. No known file-integrity failure.

## Questions for project owner
None. Visual acceptance remains pending.

## Outstanding work / next steps
Owner inspection of the published mobile review. Full Order 01 is incomplete; remaining states and gameplay integration outstanding. Live deployment: not applicable to review-only GIFs; no gameplay code changed.
