# Job Report - Eight-direction ninja sprint review v1
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner sprint assessment pending
- Commit / PR: 37e2750; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner passed normal run v3 and instructed progression to ninja sprint. Queued all eight directions, 24 generated poses per direction, in PixelLab group 471a4495-8a9d-451d-9779-2a0feb371e9a (16 generations total). Target: forward torso lean, both arms swept back throughout, powerful alternating leg cycle, clearly distinct from normal bent-arm running. Preserve fitted armor and body scale.

Review uses approved uniform scale 104/108, 128x128 RGBA frame canvas and nominal origin [64,116], 24fps authored timeline. Generated 24 poses per direction; excluded source indices 0-3 (upright lead-in), retaining indices 4-23 as 20 distinct sprint poses with no filler/interpolation. Default half-speed review is 12 poses/sec and 1.667-second loop. Normal/quarter reviews also supplied with synchronized actual-seconds timer. Accepted idle v5, walk v1 and run v3 are preserved.

## Files changed
Local source/receipts/export tooling/evidence: assets/characters/player/source/sprint-review-v1/. Normalized PNG exports/sheets/manifest: assets/characters/player/sprites/sprint-review-v1/. Published branch limited to GIF review artifacts, documentation and this report.

## Tests performed before commit
Python assets/characters/player/source/sprint-review-v1/build_review.py: PASS 160 unique 128px RGBA exports, binary alpha and no clipping after selecting source poses 4-23. Inspected all 20 retained poses for seven directions using local contact sheets .tools/sprint-poses-0.png and sprint-poses-1.png. Original and retry spot checks used PixelLab workbench. Initial Godot capture script passed all eight directions, 20 frames each, zero runtime stderr, but south-west posture remained visually inadequate; Final south-west replacement retested after rebuilding: PASS 20-frame Godot capture, zero runtime stderr. Seven protected direction SHA256 hashes remained identical, preserving their earlier runtime checks. Seven protected direction hashes saved. Normal-vs-sprint comparison exports 20 frames; decoded durations PASS normal 830ms, half 1670ms, quarter 3330ms, comparison 1670ms.

## Issues encountered
Initial south-west and north-west candidates reverted to bent-arm normal running and were rejected/preserved locally under rejected/. Retried south-west group e7b36ffa-267e-41be-86ab-6365959888ff (job ea17effb-c05b-40cf-8117-ea5594adad51), north-west group 1a2914bc-e664-4a43-a667-f89ad3294c29 (job 401cdd92-7e1c-4369-9aa0-94ef6fca65db); four additional generations total. North-west retry accepted for review. South-west retry kept arms back but stayed too upright, so a Pixen edit created a properly leaned source pose (job 737791d1-96c6-4a97-a6c7-e15b9a6496fc, 1 generation), then a third south-west animation was generated from that pose (group 56ec2953-debe-4be0-b52e-769493c0ac46, job 4ef4ede3-1705-4c75-84ee-0ffe70dbde57, 2 generations). Total cost including retries and pose edit: 23 generations. Sustained lean, arm posture, perceived speed and loop continuity require visual acceptance; frame count alone does not establish quality.

## Questions for project owner
None. New animation supplied for visual review.

## Outstanding work / next steps
Owner visual review of eight-direction ninja sprint and normal-run comparison. Jump, dodge, melee, hit/recovery, equipment/VFX and runtime integration remain outstanding. Full Order 01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay code changed.

Final visual inspection: all 20 retained poses in each direction reviewed on contact sheets; south-west now maintains forward lean and both arms extended back throughout. North is foreshortened by the back-facing camera angle; perceived lean and gait speed remain subject to owner review. No claim of flawless subjective animation acceptance. Final frame-integrity checks pass 160 unique RGBA poses with no clipping, binary alpha, unchanged anatomical scale. Godot commands: Python assets/characters/player/source/sprint-review-v1/stage_godot.py, assets/characters/player/source/sprint-review-v1/run_review.ps1 (all eight), then finalize_southwest.ps1 and run_final_southwest.ps1 for changed south-west. Evidence in source/sprint-review-v1/evidence/. Final decoded GIF duration and repository/staged-diff checks run before commit.

Public verification: sprint half-speed and action comparison both HTTP 200, 20 frames, 1670ms loop; eight-direction grid 600x1240, comparison 800x560. https://raw.githubusercontent.com/kiotdstudios/shinobi-rush/codex/mobile-animation-preview/assets/characters/player/previews/mobile/sprint-v1-half-speed.gif
