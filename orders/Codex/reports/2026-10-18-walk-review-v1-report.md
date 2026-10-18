# Job Report - Eight-direction walk review v1
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner locomotion assessment pending
- Commit / PR: Not committed; preview PR https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner approved idle v5 and authorized locomotion review. Exporting the existing PixelLab walk group e24eae75-7e91-4711-b8d0-85b74c544234: eight unique directions, 16 generated poses each. No additional generations charged. Using the approved idle scale (104/108), 128x128 transparent RGBA canvas and nominal origin [64,116]. One median root offset per clip preserves stride motion without per-frame recentering or resizing. Half-speed review default is 12 poses/sec, 1.333s per loop; normal and quarter-speed reviews are also supplied with synchronized timer.

## Files changed
Local originals and review tools: assets/characters/player/source/walk-review-v1/. Normalized PNG frames, sheets, QC and manifest: assets/characters/player/sprites/walk-review-v1/. Local production state records idle v5 approval and walk progress. Published branch is limited to review GIFs, documentation and this report.

## Tests performed before commit
PixelLab workbench inspected walk frames 1,5,9,13 in all eight directions. Directional silhouettes and alternating contacts are present; continuity and speed require animated owner review.
Python assets/characters/player/source/walk-review-v1/build_review.py: PASS 128 unique normalized frames, 128x128 RGBA, binary alpha, no clipping and three looping GIFs. Inspected normalized contact sheet (0,4,8,12 in all eight directions). Python assets/characters/player/source/walk-review-v1/stage_godot.py and assets/characters/player/source/walk-review-v1/run_review.ps1: PASS all eight directions, 16 captured frames each, Godot 4.5.1 OpenGL compatibility with no runtime stderr. GIF decode check: 16 frames each; normal 670ms, half 1330ms, quarter 2670ms. Order validator and staged diff check passed before commit. Evidence: source/walk-review-v1/evidence/.

## Issues encountered
Work paused briefly when the session was read-only, then resumed after access was restored. Kiro's merged prototype now provides a sprite drop-in contract; current work remains an art review, not integration of an unapproved walk set.

## Questions for project owner
None. Owner visual review is the next acceptance step.

## Outstanding work / next steps
Owner visual assessment of walk loop, speed, foot contact and directional consistency. Normal run, arms-back sprint and other Order 01 states remain outstanding. Live deployment: not applicable to this review-only GIF job; no gameplay files changed.

Review limitations: source silhouettes vary in height through stride (96-112px across all directions); the fixed anatomical scale is preserved. Lowest visible foot varies through stride (112-122px overall); this is not proof of zero sliding in gameplay. No gameplay transition, collision or Web frame-time test was performed for this review-only job. Full animation acceptance remains pending owner review.
