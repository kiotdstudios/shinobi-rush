# Job Report — Premium Body Flicker dodge
- Agent: Codex
- Order: orders/Codex/2026-10-25-body-flicker-premium.md
- Date: 2026-10-25 (America/New_York; UTC capture timestamps may read 2026-10-26)
- Final status: DONE — merged, deployed and verified in canonical live gameplay
- Commit / PR: Runtime PR209 https://github.com/kiotdstudios/shinobi-rush/pull/209 merged as 4e248c1b0c2a2e427eba49dca4c7e2b026ce306c; final evidence/report-only PR follows.

## Final verified delivery
**LIVE:** https://kiotdstudios.github.io/shinobi-rush/?flicker=review&v=4e248c1b . The normal game also uses the new player/bandit effect without a review query.

- Exact merged/deployed SHA: **4e248c1b0c2a2e427eba49dca4c7e2b026ce306c**. Runtime PR209 is merged.
- Exact tested PR head: e543734a9b1f68908f11b54c44bba8c1a8149838. PR CI [40259677681](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40259677681) passed required checks.
- Main CI [40260710058](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40260710058): **all jobs succeeded**, including native import/validate/tests/export, predeploy browser/controls/debug checks, Pages deployment, postdeploy live smoke and gate.
- Main native summary: **3266 passed / 0 failed**. Resource validation: **379 scripts / 25 scenes / 0 failures**.
- Canonical live review: **25/25 passed**, including both actors' eight directions, actual wall stop/sample bounds, rapid baseline interruption, real autoplay triggers and Normal/Half playback. **No browser errors**. Tested at 2026-10-26T03:10:03.565Z (2026-10-25 23:10 EDT).
- Actual normal-game keyboard test: **4/4 passed**, including all eight animation directions and the new shared presentation. **No browser errors**. Tested at 2026-10-26T03:10:36.672Z = **2026-10-25 23:10:36 EDT**.
- Recorded the actual public baseline at 8d08423c before deployment and the actual public updated game at 4e248c1b afterward. Final gameplay-before.webm / gameplay-after.webm replace the earlier local-comparison videos. Source JSON and screenshots are public-before/ and public-after/.
- Inspected live travel, wall-stop and bandit screenshots, plus the normal-world screenshot. Approved character identities/scale remain intact; afterimage samples stay on reached positions, and the compact effects do not hide the body. Existing world/background gaps and dense grass composition are unchanged by this job; no terrain repair is claimed.
- Recording limitation: the normal-world headless Chromium capture reported 3–4 render FPS in both baseline and updated builds. These recordings prove real gameplay/input integration; no hardware frame-rate claim is made. The close-up normal/half GIFs use 25 FPS compositor recordings of the isolated real-controller review, extracted at 24 FPS without interpolation.
- Final evidence is indexed in docs/visuals/body-flicker-premium/deployment.json. Questions: None. Outstanding runtime work: None; visual owner feedback can guide future refinements.

The following sections retain the pre-commit work/testing history; their pending statuses describe those earlier checkpoints, not the final delivery above.

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

## Integration pass — 8fef224f (before merge commit)
- Implementation commit: 2c60e732. Integrated origin/main 8fef224fab1b83a83a6c62563fb41d3e7b520d81 with `git merge --no-commit --no-ff origin/main`; automatic merge, no conflicts.
- `python scripts/ci/godot_ci.py import ... --log-dir build/flicker-integrated-import`: PASS.
- `python scripts/ci/godot_ci.py validate-resources ... --log-dir build/flicker-integrated-validate`: PASS, 370 scripts, 25 scenes, 0 failures.
- `python scripts/ci/godot_ci.py tests ... --log-dir build/flicker-integrated-tests`: PASS, **3201 passed, 0 failed**, including Aki's floor coverage checks. The only expected warning is the deliberately invalid sprite-sheet fixture.
- Fresh integrated Web export and browser review: PASS, initially 23 checks, then **24 checks** after adding an actual autoplay-input regression assertion. Evidence: integrated-proof/validation.json.
- Normal-game keyboard recording proof after integration: PASS, **4 checks**, including all eight headings and no browser errors. Evidence: integrated-gameplay/gameplay-validation.json. Raw duplicate videos retained in ignored build/.
- Visual inspection of recorded GIF frames caught review-only autoplay input being pressed outside a physics tick. Corrected it to trigger on physics ticks; final focused harness rerun is **147 passed, 0 failed**, including real repeated autoplay dodges. Production controllers did not change.
- Regenerated final previews from actual 25 FPS compositor video, extracted at 24 FPS without interpolation, rather than the original sparse screenshot samples. GIFs use unscaled cropped status/playfield panels and cumulative 10ms timing quantization; no speed-up from rounding every frame separately. Capture helper fails if fewer than eight real dodges execute. See final preview-recordings metadata.
- Acknowledged the new full-diamond floor standard to Diel in commentary ("I read the tiles order."). No floor art repainted by this feature; Aki's fixes are retained from main and coverage tests pass.
- Latest main advanced to 35aa84fd while testing; another normal integration pass is required before opening/merging the runtime PR. No live publication is claimed yet.

## Final base integration — 35aa84fd (tested before this merge commit)
- Prior integration commit: d3f15ebc. Merged origin/main 35aa84fd35693f4f6dba0e9f14764c16d34e7501 using `git merge --no-commit --no-ff origin/main`; clean automatic merge. Preserved Aki's builder Bandit and tag-bomb integration.
- `python scripts/ci/godot_ci.py tests --project . --godot <exe> --log-dir build/flicker-final-base-tests`: **3221 passed, 0 failed**, including the new autoplay-input regression and latest upstream builder tests.
- `python scripts/ci/godot_ci.py export --project . --out ../body-flicker-final-base-web-20261025 --godot <exe> --log-dir build/flicker-final-base-export`: PASS.
- `node docs/visuals/body-flicker-premium/browser-proof.mjs ../body-flicker-final-base-web-20261025 docs/visuals/body-flicker-premium/final-base-proof`: **24/24 passed**, no browser errors.
- `node docs/visuals/body-flicker-premium/gameplay-proof.mjs ../body-flicker-final-base-web-20261025 build/flicker-final-base-gameplay`: **4/4 passed**, including actual normal-game keyboard input, all eight headings and shared presentation; no browser errors. JSON and screenshots copied to final-base-gameplay/.
- Final GIF preview capture now includes a minimum-eight-actual-dodges guard. Compositor-derived crops were inspected: Before/Normal 174 extracted frames, 7.25s each; Half 352 frames, 14.66s. Sizes approximately 1.27/1.71/3.10 MB. This supersedes the sparse screenshot previews recorded in the initial report.
- `python scripts/ci/validate_orders.py` and `git diff --check`: PASS. Runtime remains REVIEW until PR gates, normal merge, main deploy/postdeploy and exact public-build verification complete.

## PR / final comparison-mode hardening
- Runtime PR: https://github.com/kiotdstudios/shinobi-rush/pull/209 (attached). Combined tested head before this hardening: 7e5ba9c46f5c95e7480c2446c1072ce206654797.
- During final self-review, found that rapidly interrupting the optional BEFORE comparison could try to clear nodes that only exist in the new effect. Added a legacy-only immediate cleanup guard and regression. Normal production presentation/movement is unchanged.
- Final focused suite after guard: **148 passed, 0 failed**, `build/flicker-focused-baseline.log`.
- Fresh release Web export `../body-flicker-release-web-20261025`: PASS. Release browser proof: **25/25 passed**, now explicitly rapidly interrupting the BEFORE comparison; no browser errors. Evidence: release-proof/validation.json.
- Push this tested guard to PR209 and wait for checks on the new head. Previous-head native CI succeeded; no old-head CI result will be used to merge the new head.

## Chidori upstream integration — 8d08423c (tested before merge commit)
- Main advanced during PR CI to 8d08423c7b2976742d7fc8e2e3eb730eaf2207c9 (Aki's Chidori). Integrated with `git merge --no-commit --no-ff origin/main`; clean merge. Did not edit Aki's Chidori controller, input or VFX implementation.
- `python scripts/ci/godot_ci.py import ... --log-dir build/flicker-chidori-import`: PASS.
- `python scripts/ci/godot_ci.py tests ... --log-dir build/flicker-chidori-tests`: **3251 passed, 0 failed**, including Chidori interaction tests and the final legacy-comparison interruption guard.
- Fresh export `../body-flicker-chidori-web-20261025`: PASS.
- `node docs/visuals/body-flicker-premium/browser-proof.mjs ../body-flicker-chidori-web-20261025 docs/visuals/body-flicker-premium/chidori-proof`: **25/25 passed**, no browser errors.
- New merged head must receive its own PR checks; prior heads' CI will not be used to merge it. Canonical publication remains pending.

## R3 upstream integration — 305dee8f (tested before merge commit)
- Previous tested-head PR CI completed its native/export/browser checks, but main advanced to 305dee8f410f3850cedbab11e58538526427c009 (Aki R3 lock-on). Integrated normally with `git merge --no-commit --no-ff origin/main`; clean merge; retained input/reticle changes unchanged.
- Changed-area native regression harness `build/test_flicker_lock.gd` ran bandit chase, health/flicker, premium flicker, R3 lock-on, combat and Chidori suites: **226 passed, 0 failed** (build/flicker-lock-focused.log). The prior full combined suite was 3251/0; the new exact-head CI must run the full suite again before merge.
- Fresh Web export `../body-flicker-lock-web-20261025`: PASS. Browser proof on this integrated build: **25/25 passed**, no browser errors; evidence lock-proof/validation.json.
- Actual public baseline before deployment recorded separately at main 8d08423c7b2976742d7fc8e2e3eb730eaf2207c9: 4/4 actual-game keyboard/direction/presentation/error checks passed. Raw recording/evidence is retained under ignored build/flicker-public-before for the final live before/after report.

## Final report-only verification before commit
- Verified all live JSON check values true and both after-build SHA values equal the merged SHA.
- Inspected actual public screenshots; VP9 compression of both real public recordings completed successfully.
- python scripts/ci/validate_orders.py; git diff --check; JSON and image integrity checks: run before this documentation/evidence commit.
- This follow-up changes evidence/docs/order status only. Runtime was already merged/deployed by PR209; it does not claim another game deployment.

- Artifact decode check: bundled FFmpeg does not include a null muxer, so the attempted null-output check was unavailable. Both final WebM files successfully decoded an end-of-stream frame to PNG; Pillow integrity checks passed. No recording defect was found.
