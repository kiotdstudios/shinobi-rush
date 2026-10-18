# Job Report - Walk height audit and normal run review v1
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner normal-run assessment pending
- Commit / PR: Not committed; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner allowed progression after requesting a west/east walk height audit. All 16 walk silhouettes measured: east 98-103px, mean 100.5625px; west 97-103px, mean 100.5px. Contact sheet includes original E, original W and mirrored E at frames 0,4,8,12. No systematic height mismatch found, so unique west retained. Mirroring would reverse asymmetric hair/outfit details and is not necessary for this measured size difference.

Queued all eight normal-run directions in PixelLab group ea94edbf-ce06-46ef-925b-c0847a5a461a, 20 unique authored poses per direction. Bent arms pumping beside the torso distinguish normal running from arms-back ninja sprint. Approved 128px scale, nominal origin [64,116], source timeline 24fps and half-speed review default retained.

## Files changed
Local source/scripts/receipts/evidence: assets/characters/player/source/run-review-v1/. Export frames and manifest: assets/characters/player/sprites/run-review-v1/. Published branch contains review GIFs/docs/report only. Approved idle and walk remain preserved.

## Tests performed before commit
- Walk height audit: Pillow alpha bounding-box heights for all 16 frames in E/W. Inspected side-by-side original E/W and mirrored E poses. Local evidence .tools/walk-east-west-check.png.
- Python assets/characters/player/source/run-review-v1/build_review.py: PASS 160 unique 128x128 RGBA poses, binary alpha and no clipping; inspected normalized contact sheet in all eight directions for appearance and bent-arm running. Python assets/characters/player/source/run-review-v1/stage_godot.py and assets/characters/player/source/run-review-v1/run_review.ps1: PASS all eight directions, 20 captured frames each, Godot 4.5.1 OpenGL compatibility with zero runtime stderr. Decoded GIF checks PASS 20 frames each: normal 830ms, half 1670ms, quarter 3330ms. Order validator and staged diff check run before commit. Evidence source/run-review-v1/evidence/.

## Issues encountered
One shell wrapper initially reported a stale native exit code after successful PowerShell downloads; confirmed all 160 files present and reran export successfully. Gait-phase differences can make west appear shorter at individual synchronized ticks despite almost identical cycle-average height. Silhouette height alone does not guarantee identical internal anatomy; the visual comparison was also inspected.

## Questions for project owner
None. New animation will be supplied for visual review.

## Outstanding work / next steps
Finish normal-run generation, export/test all eight directions and publish mobile review. Sprint, jump, dodge, melee and hit states remain outstanding. Full Order 01 is incomplete. Live deployment: not applicable to review-only GIF publication; no gameplay files changed.

Normal-run silhouette heights vary through crouch/flight (90-109px overall), with unchanged anatomical scale. Run east mean 95.85px, west 96.5px. First/last pose and perceived gait speed remain subject to owner review; Godot checks verify rendering and integrity, not subjective animation acceptance. No gameplay transitions or live game Web playtest performed for this review-only job.
