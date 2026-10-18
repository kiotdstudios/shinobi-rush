# Job Report - South ninja sprint facing v4
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner visual acceptance pending
- Commit / PR: pending; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Replaced south only after owner reported it faced diagonally. PixelLab PixMiniMax job 0469ee58-b8d4-4423-8823-3f7249f517f1, group a4351ada-93ae-4bd8-8f5c-1327054d9ba8, cost 2 generations. Prompt pins face/chest to straight screen-down south with visible front shoulders, continuous torso movement, forward lean and arms swept back. Retained source poses 4-23 from 24 generated poses, matching the existing 20-pose sprint timeline. Seven other directions retain exact sprint-v3 PNG bytes, including moving north vest correction. No mirroring or synthetic intermediate frames.

## Files changed
Local sources, receipts, build/comparison/staging scripts and evidence: assets/characters/player/source/sprint-review-v4/. Normalized assets and manifest: assets/characters/player/sprites/sprint-review-v4/. Review branch publishes four GIFs, mobile README and this report only. Production source remains local pending broader accepted asset handoff.

## Tests performed before commit
- Bundled Python build_review.py: PASS 160 unique 128x128 RGBA frames, binary alpha, no clipping, consistent clip-level root and uniform scale104/108; south height96-102px. Seven unchanged directions/140 PNGs byte-identical to v3.
- Inspected south-contact.png covering all20 retained poses: front face and chest stay south-facing; no westward turn; arms remain behind/outward with alternating leg stride. Identity retained, unmasked, no sword/cape.
- Bundled Python compare_south.py: PASS20-frame synchronized v3/v4 comparison.
- Bundled Python stage_godot.py; PowerShell run_review.ps1: PASS south, north and east,20captures each, Godot4.5.1 OpenGL compatibility, zero runtime stderr. Inspected south engine capture. Remaining directions unchanged from prior tested assets.
- Pillow decoded GIFs: all20frames, grid600x1240; normal830ms, half1670ms, quarter3330ms. Comparison800x560,1670ms. Half speed default retained.
- Order validator and git diff --cached --check executed immediately before commit; results recorded in terminal.

## Issues encountered
None in export/engine checks. Subjective forward-lean/facing acceptance remains with owner; the front projection foreshortens the arms. No gameplay integration or Web performance claim made.

## Questions for project owner
None. New review links supplied for inspection.

## Outstanding work / next steps
Owner review of south sprint and latest north vest. Full Order01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay code changed.
