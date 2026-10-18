# Job Report - West and north-west idle review v4
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner inspection pending
- Commit / PR: dc72e8c; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Generated PixelLab replacements for west and north-west. Preserved all six other v3 directions byte-for-byte, including the south-east reference and prior corrections. Kept 128x128 RGBA frames, 16 timeline ticks, 0.5x default, and synchronized actual-seconds timer (1.333s loop). No procedural animation or interpolated filler frames.
West group: 847d8f0f-4494-4938-adcb-a3a19dcf3c9e. North-west group: fb92d396-701a-479c-8e75-28d0f38e3e91.

## Files changed
Local sources, scripts, GIFs, Godot evidence: assets/characters/player/source/idle-review-v4/.
Normalized frames and metrics: assets/characters/player/sprites/idle-review-v4/.
Published review files only: assets/characters/player/previews/mobile/idle-v4-*.gif, idle-current.gif, README.md and this report. Full production assets remain on the art work branch.

## Tests performed before commit
- Python assets/characters/player/source/idle-review-v4/refine_idle.py: PASS no clipping, 16 raw frames for each revised direction, six unchanged-direction byte comparisons, 16-frame looping GIF exports.
- Python assets/characters/player/source/idle-review-v4/stage_godot.py: PASS.
- assets/characters/player/source/idle-review-v4/run_review.ps1: PASS west, north-west, south-east using Godot 4.5.1 OpenGL compatibility, 16 captured frames per direction and zero runtime stderr. Logs and captures in source/idle-review-v4/evidence/.
- Inspected contact sheet of frames 0,4,8,12 for west and north-west: stable facing and foot contact; chest expansion visible.
- West head centroid span: 3.974px -> 1.002px; torso 2.305px -> 1.787px; feet 0.016px. North-west head 4.714px -> 0px; torso 4.607px -> 0.934px; feet 0px.
- Repository order validation and git diff check run immediately before commit.

## Issues encountered
Initial session was read-only; generation completed remotely but downloading/testing/publishing waited for restored write access. West retains small residual head movement and needs owner visual assessment. Metrics quantify silhouette centroids and do not replace subjective animation review.

## Questions for project owner
None. Updated preview is provided for visual feedback.

## Outstanding work / next steps
Owner inspection of the new idle GIF. Full Order 01 is incomplete; remaining states and gameplay integration outstanding. Live deployment: not applicable to these review-only GIFs; no gameplay code changed.

Public verification after push: HTTP 200, decoded 600x1240 GIF, 16 frames, 1330ms half-speed loop. New mobile URL: https://raw.githubusercontent.com/kiotdstudios/shinobi-rush/codex/mobile-animation-preview/assets/characters/player/previews/mobile/idle-v4-half-speed.gif
