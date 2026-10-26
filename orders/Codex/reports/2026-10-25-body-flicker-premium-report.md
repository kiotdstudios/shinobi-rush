# Job Report — Premium Body Flicker dodge
- Agent: Codex
- Order: orders/Codex/2026-10-25-body-flicker-premium.md
- Date: 2026-10-25 (America/New_York; UTC capture timestamps may read 2026-10-26)
- Final status: REVIEW — local implementation tested; reviewed integration/deployment pending
- Commit / PR: Not committed at report creation; implementation and integration links follow below.

## Work completed
Implemented the owner's pasted Body Flicker brief as a shared presentation component for the existing player dodge and bandit evade/retreat. The player uses its approved 128x128 eight-direction dodge poses, selected from actual action progress for launch, burst/travel, landing and recovery. Bandits use their own run/sprint body art. Replaced the bandit's old near-invisible alpha fade with an opaque recognizable body and the same effect system.

Added a three-slot stationary afterimage ring using the actual actor texture/frame/transform at reached positions only. Added white launch/arrival highlights, narrow quantized silhouette smear/multiples, pale blue/white/desaturated streaks, stationary authored launch dust and compact endpoint displacement. Ghost sprites are pixel-snapped for rendering, use nearest filtering and never extrapolate through walls. Effects cancel on teleports and interruptions, share immutable textures and keep transient node counts bounded. Equal evade/retreat counter values cannot accidentally reuse an old action. An attack interrupt does not restore a stale dodge pose or alter actor transforms.

No input map, player movement/controller, bandit movement/AI controller, collision/hitboxes, invulnerability, cooldown, attack cancel or dash-attack timing file was changed. Existing 0.30-second player dodge / 0.20-second movement and profile-driven bandit timings remain authoritative; suggested brief timing is adapted to them. Particle-only tail grants no extra protection. No new AI image jobs or character redesign were used; reusable approved body/VFX art plus a crisp pixel shader supplies the visuals.

Added an eight-direction, before/after, normal/half-speed Web review using real PlayerController/Bandit collision-constrained movement; added read-only normal-game effect inspection and an explicit baseline-player-presentation query for recorded comparisons. Preserved existing historical SE lab proofs. Recorded before/after actual normal-game keyboard gameplay and measured-timing GIF previews.

## Files changed
- scripts/vfx/evade_streak_fx.gd: shared phase presentation, actual-position snapshots, bounded pool and cleanup; existing public spawn/type contract retained.
- scripts/enemy/bandit_visual.gd: shared visual binding; remove old 0.12-alpha fade and duplicated streak setup.
- assets/vfx/body_flicker/premium_silhouette.gdshader (+ UID), premium.art.json: independent crisp silhouette/streak material and full pose/effect/timing contract.
- scripts/art/body_flicker_review.gd (+ UID), scenes/art/body_flicker_review.tscn, scripts/art/kunai_proof_gate.gd: opt-in real-controller review and read-only normal-game inspection.
- tests/test_body_flicker_premium.gd (+ UID), tests/run_tests.gd; intentional updated bandit presentation assertion in test_bandit_chase.gd and 0.01px floating-point tolerance in test_health_flicker.gd.
- docs/visuals/body-flicker-premium/: integration notes, browser and capture tools, two WebM gameplay recordings, before/normal/half-speed GIFs, screenshots and JSON evidence.
- Own order and report.

## Tests performed BEFORE implementation commit
Environment: Windows PowerShell; bundled Python/Node/Playwright Chromium; Godot 4.7.2 GL Compatibility. Dedicated .tools/dynamic-shrine checkout, original main base d98f0dc1; latest upstream at report creation 8fef224f awaits normal integration. Exact Godot executable: C:/Users/dielp/Documents/Codex/2026-10-17/shinobi-rush-is-the-new-game/.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe.

| Command / steps | Observed result | Evidence |
| --- | --- | --- |
| python scripts/ci/godot_ci.py import --project . --godot <exe> --log-dir build/flicker-import | PASS; own generated sidecars retained | build/flicker-import.log |
| python scripts/ci/godot_ci.py validate-resources --project . --godot <exe> --log-dir build/flicker-validate-final | PASS; 368 scripts, 25 scenes, 0 failures | build/flicker-validate-final.log |
| python scripts/ci/godot_ci.py tests --project . --godot <exe> --log-dir build/flicker-tests-precommit | PASS; 3118 passed, 0 failed. This full run preceded the final narrow teleport/rounded-obstacle test additions and cleanup refinement; the final focused rerun below covers those. | build/flicker-tests-precommit.log |
| <exe> --headless --path . --script res://build/test_flicker.gd (focused harness: bandit_chase, health_flicker, body_flicker_premium; same death/substitution fixture switches as full runner) | PASS on final local code; 146 passed, 0 failed, including all octants at 0.2/0.3/0.5s, fixed anchors/scale, stationary samples, wall and rounded tree footprint, duplicate calls, dash-attack interrupt, bandit identity/opacity, same-counter mode transitions, second retreat hop, teleport gap cancellation | build/flicker-focused-final.log |
| python scripts/ci/godot_ci.py export --project . --out ../body-flicker-web-v5-20261025 --godot <exe> --log-dir build/flicker-export-v5 | PASS, fresh Web build; no script/shader errors | build/flicker-export-v5.log |
| node docs/visuals/body-flicker-premium/browser-proof.mjs ../body-flicker-web-v5-20261025 docs/visuals/body-flicker-premium/local-proof | PASS; 23 checks: both actors' 8 directions, real wall and sample bounds, before/after, normal/half, no browser errors | local-proof/validation.json and 5 screenshots |
| node docs/visuals/body-flicker-premium/gameplay-proof.mjs ../body-flicker-web-v3-20261025 docs/visuals/body-flicker-premium/local-gameplay; inspected recorded direction data | PASS; real keyboard dodge in normal game, new presentation observed, all eight animation headings recorded, no browser errors. This pre-integration recording predates the narrow collision-arrival cleanup refinements; gameplay controller/timing unchanged. | local-gameplay/gameplay-validation.json; gameplay-before.webm / gameplay-after.webm |
| node docs/visuals/body-flicker-premium/capture-preview.mjs ../body-flicker-web-v3-20261025 build/flicker-capture; python docs/visuals/body-flicker-premium/make_previews.py build/flicker-capture | PASS; actual screenshots at measured intervals: before 40 frames/7.29s, normal 40/7.25s, half 80/14.5s | before.gif / normal.gif / half-speed.gif |
| Viewed Web screenshots for travel, wall stop and bandit; inspected native and browser logs | PASS; recognizable opaque bodies, sharp small streaks, trailing ghost silhouettes; no missing textures or shader/browser errors | local-proof/*.png |
| python scripts/ci/validate_orders.py; git diff --check | PASS | command output |

GIFs and WebM recordings are silent. Raw duplicate Playwright videos and screenshot frames are preserved under ignored build/, not committed. WebM delivery compressed with bundled FFmpeg libvpx-vp9 CRF42; no generated/interpolated animation frames.

## Issues encountered / fixes
- Initial focused harness lacked full-runner death/substitution fixture switches; corrected harness before interpreting gameplay results.
- A strict old distance assertion failed on 134.9992px versus 135px; added a 0.01px numerical tolerance only, no movement change.
- Initial manual move_and_slide test outside physics ticks used wall-clock frame delta and overshot; rewrote feature tests to await actual physics/process frames.
- Review wall was initially disabled with its parent process mode; fixed fixture to toggle only the collider. Browser proof caught it before commit.
- Switching the review from player to bandit before PhysicsServer synchronized moved bodies could choose the alternate legal evade heading; deferred bandit trigger until a real physics/process boundary. Normal AI/controller behavior unchanged.
- Separate hop/evade identity, early collision arrival timing and immediate interrupted-tail cleanup were hardened and retested before commit.
- Godot full-suite warning for deliberately invalid t_badsheet fixture is expected. Earlier standalone harness emitted 6 ObjectDB cleanup warnings; final focused run had no such warnings. No unexpected runtime/browser errors remain in passing evidence.
- Import-generated unrelated tools/shot_autotile.gd.uid and tools/shot_shrine_climb.gd.uid are preserved under ignored build/ rather than included in this task.

## Questions for project owner
None.

## Outstanding work / next steps
Integrate latest main via reviewed PR, run native/export/browser checks after integration, obtain required CI and merge normally, then wait for canonical main deploy/postdeploy smoke and verify the exact deployed SHA with both review and real-game keyboard proof. Status must remain REVIEW until that succeeds. Final report-only evidence update follows deployment.

Canonical live URL: https://kiotdstudios.github.io/shinobi-rush/?flicker=review . NOT YET VERIFIED LIVE for this change at report creation.
