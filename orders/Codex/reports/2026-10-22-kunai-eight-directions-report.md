# Job Report — Shared eight-direction kunai combat
- Agent: Codex
- Order: orders/Codex/2026-10-22-kunai-eight-directions.md
- Date:2026-10-22; continuation2026-10-23
- Final status: DONE — implemented, integrated, live verified; owner visual feedback remains welcome
- Commit / PR: Initial tested implementation fdddc7677c06d10728fc91c5d0b4d864908da6b9. Integrated via merge8830e85e600acb3e97509ed3de8a61c9202b551c, PR115 https://github.com/kiotdstudios/shinobi-rush/pull/115.

## Work completed
Owner rejected both chakra layers and paused that work. PR107 was converted to draft with an explicit no-merge title/body; no chakra code/assets are included here.

Created facing-specific light1/2/3, dash and guard body sets for both approved characters; fixed128×128 RGBA, transparent backgrounds, production palettes and metadata root(64,116). Preserved approved SE player records/pixels unchanged. Exported360 PNGs plus24 existing SE references,384 references total. Western headings mirror the corresponding eastern art at native anchor x64. Retained generated source sheets, selected indices, measured hand tracks and raw tool receipts/hashes. Regenerated or rejected wrong-facing/wide/early-neutral iterations before export.

Built a shared data-driven black-kunai/hand-occlusion/trail renderer, per-key orientation/draw-order and phase timing. Both skin bodies sample the same action profiles. Player visuals sample actual gameplay phases; enemy visuals sample its existing slower windup/active/recovery. Hitstop freezes body and blade together; interrupted actions, locomotion, set switches and death clear attachments. Bandit's existing two-swing AI now uses actual kunai attack art; light3/dash remain available to future enemy profiles without changing AI, damage or attack timing.

Added an isolated both-character8-direction review, normal/half playback(default half), pause/exact-key stepping and body/blade/trail switches. Added16 rendered GIF previews and contact sheet. Kept existing proof routes functional. Added opt-in read-only gameplay visual telemetry for actual-input browser verification.

## Files changed
- `assets/characters/{player,bandit}/kunai_eight/`: runtime body frames/import settings and ignored raw-source directories.
- `assets/combat/kunai/kunai-combat.art.json`: profiles and both skins' tracks.
- Player/bandit production manifests: literal8-heading action IDs.
- `scripts/combat/{kunai_combat_data,kunai_weapon_visual,weapon_rig}.gd`: shared lookup/attachment system.
- PlayerVisual/BanditVisual: requested attack-visual bindings; controllers/state machines unchanged.
- `scripts/art/kunai_pose_actor.gd`, proof gate and new review scene/script: actor-plane ordering, directional trails, bounded texture cache and review UI.
- Kunai wiring/chase/new eight-direction tests and runner registration.
- `docs/visuals/kunai-eight/`: reproducible extraction, QC, provenance, browser proofs, previews and integration notes.

## Tests run before commit
Environment: Windows PowerShell; Godot4.7.2 stable, Compatibility debug single-threaded Web preset; bundled Python and Node; Playwright Chromium. Commands run from `.tools/kunai-combat`. `$env:GODOT_BIN` points to repository `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.

| Exact command / steps | Result | Evidence |
| --- | --- | --- |
| `python docs/visuals/kunai-eight/export_pack.py` | PASS;384 references, manifests, measured tracks and uniform-sheet alignment | asset-qc.json, sources.json |
| `python docs/visuals/kunai-eight/inspect_sources.py` | PASS;21 selected source sheets extracted without clipping | build/kunai-tracks/source-qc.json |
| `python docs/visuals/kunai-eight/validate_pack.py` | PASS; native size/RGBA/hard alpha/opaque grips/all headings/no duplicate body within clip/unchanged approved SE | pack-validation.json |
| `python scripts/ci/validate_sprite_manifests.py` | PASS;1 manifest,0 errors | command output |
| `python scripts/ci/godot_ci.py import --project . --log-dir build/kunai-eight-import-main` | PASS; imported latest main wall kit too; own sidecars will be committed | import.log |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/kunai-eight-validation-final` | PASS;84 scripts,9 scenes,0 failures | validate-resources.log |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/kunai-eight-tests` | Initial run:1752 pass,1 failure,0 engine errors; fixed cleanup-test gait assumption | tests-builtin.log |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/kunai-eight-tests-final` | ABORTED after stale imports from newly integrated HUD/fire-pillar caused missing resources/type and stalled runner; fresh import completed, integrated rerun below | tests-builtin.log |
| `python scripts/ci/godot_ci.py export --project . --out ../kunai-eight-final-web --log-dir build/kunai-eight-export-main` | PASS;41MiB Web build with current main05dc2f3 | export.log |
| `python scripts/ci/godot_ci.py finalize-export --project . --out ../kunai-eight-final-web --kind game --commit-sha 05dc2f3d6688e9ecb97d90b96a774266c4d05467` | PASS; labels local uncommitted verification build with base SHA, not a claim that art was committed | build-info.json |
| `python scripts/ci/godot_ci.py check-export --dir ../kunai-eight-final-web --kind game --project . --expect-sha 05dc2f3d6688e9ecb97d90b96a774266c4d05467` | PASS; manifest+1394 sprite PNG import records packed | command output |
| `node docs/visuals/kunai-eight/browser-proof.mjs` | PASS on review export:192 paired poses,8 headings, exact stepping/wrap, sockets/angles/layers, skin switches, timing/layer controls, cache bounds,0 browser errors; repeat on final main export PASS | build/kunai-eight-browser/review.json and PNGs |
| `node docs/visuals/kunai-eight/gameplay-proof.mjs` | PASS on final main export: real keys attack in8 headings, no fallback, weapon cleanup; actual bandit AI light1/light2 rendered with attached kunai;0 errors | build/kunai-eight-gameplay/gameplay.json and PNGs |
| `node scripts/ci/smoke/controls-probe.mjs --serve-dir ../kunai-eight-final-web --out-dir build/kunai-eight-controls` | PASS; all controls/camera/vision checks,0 console errors | build/kunai-eight-controls |
| `python docs/visuals/kunai-eight/make_previews.py` plus visual inspection of contact sheet/selected engine poses | PASS;16 GIFs source-timed,8 directions both skins in contacts | docs/visuals/kunai-eight/*.gif, all-directions-contact.png |

| `node docs/visuals/kunai-eight/touch-proof.mjs` | PASS; actual touchscreen taps in390×844 and844×390 phone emulation for pause, NW, step and skin | build/kunai-eight-touch/touch.json |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/kunai-eight-tests-integrated` | PASS;1792 passed,0 failed,0 engine errors; expected malformed-fixture warning only | build/kunai-eight-tests-integrated/tests-builtin.log |

## Issues encountered
- Several raw generated sheets had wrong-facing or early-neutral keys, oversized framing, or insufficient finishing motion. Rejected/replaced those keys/sheets and retained receipts. Corrected chroma classification to preserve burgundy scarf colors, and applied uniform per-sheet native scale/root offsets before measuring sockets. QC now passes all selected sources without clipping.
- First rerun began with a stale import cache after integrating new main HUD/fire-pillar content. Missing imported HUD textures and FirePillar type stalled the runner; stopped that exact test process, imported all new content, and restarted the full suite. This was local checkout preparation; the combined Web build and fresh resource validation passed.
- Initial cleanup assertion expected literal run while the fixture could validly resume sprint; actual full weapon/trail layer had hidden. Corrected to permit run/sprint; clean integrated rerun passed all1792 checks.
- Early browser screenshot attempt captured a running clock after its desired key had passed. Replaced with paused exact-key stepping and atomic read-only snapshots. Diagonal-input test released keys sequentially before attacking and re-aimed to a cardinal; changed to attack with both actual keys held. These were test-harness issues, not changes to player movement.
- Export helper requires a fresh output directory and40-character SHA. Corrected local invocation and finalized/check-verified the fresh export.
- Legacy approved SE soles retain an existing one-pixel exclusive-bound convention(116/117); no alteration to approved pixels. New frames use exclusive bottom116.
- Browser checks use Chromium/software rendering. Native gamepad hardware and physical phone were not available; do not claim hardware coverage.

## Questions for project owner
None required to finish delivery. New facings are ready for owner visual review after publication; automated success does not imply visual approval.

## Outstanding work / next steps
No remaining work for this delivery. Keep chakra paused. Owner visual review of the new facings is not implied by automated checks. Other queued bandit action-art requests outside these attacks/guard remain separate.

## Safe integration —2026-10-23
Integrated main0c84e6f (Aki HUD/dust/substitution/bandit throw) with a pending merge. Resolved two overlaps by preserving the incoming eight-direction throw manifest/action alongside all shared melee clips, and preserving the throw visual branch alongside melee phase rendering. Added a cold-cache throw transition test. That test caught incoming has_frames() incorrectly testing the lazy cache rather than animation existence; switched to animations.has() and kept explicit throw progress paused. No throw AI/projectile/damage/controller changes.

- Import: python scripts/ci/godot_ci.py import --project . --log-dir build/kunai-eight-import-substitution — PASS.
- Validation: python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/kunai-eight-validation-substitution — PASS;88 scripts,9 scenes,0 failures.
- First combined native run: python scripts/ci/godot_ci.py tests --project . --log-dir build/kunai-eight-tests-substitution —1826 passed,1 failed (new cold-cache throw check);0 engine errors. Fixed the caught lazy-cache lookup; full rerun PASS1827 passed,0 failed,0 engine errors in build/kunai-eight-tests-final-merged/tests-builtin.log.
- New Web export: python scripts/ci/godot_ci.py export --project . --out ../kunai-eight-publish-web --log-dir build/kunai-eight-export-publish — PASS.
- Combined browser review: KUNAI_DIR=../kunai-eight-integrated-web KUNAI_OUT=build/kunai-eight-review-integrated node docs/visuals/kunai-eight/browser-proof.mjs — PASS192 paired poses, controls/layers/cache,0 errors.
- Gameplay driver was briefly made to require an AI throw during a route that only saw melee (no throw opportunity); removed that route assumption. Native cold-cache transition test exercises throw rendering directly. Actual-key melee/cleanup/bandit-swing rerun on publish export PASS in build/kunai-eight-gameplay-publish/gameplay.json;0 browser runtime errors.

- Final export metadata/check: finalize-export and check-export against base0c84e6f50bc0b7f106e1c84f2bcfc51ddf607780 on ../kunai-eight-publish-web — PASS;41MiB,1530 sprite PNG imports packed. Base label is local verification only; deployed build will be checked against exact merge SHA.
- Order validation: python scripts/ci/validate_orders.py — PASS.

## Published delivery —2026-10-23 06:25 UTC
- PR115: https://github.com/kiotdstudios/shinobi-rush/pull/115 — merged after required validate-orders-and-project and godot-ci-gate succeeded. PR CI run39909594605 passed native/export/browser/controls/debug checks.
- Tested head: cd33f9d96dd09b0905bad578eecf403c04f403c3. Public merge:8830e85e600acb3e97509ed3de8a61c9202b551c. git diff between these commits returned empty (the tested content is exactly the merged tree).
- Main CI/deploy run39910384603: every job passed, including Pages publication and post-deploy live smoke.
- Live review: https://kiotdstudios.github.io/shinobi-rush/?kunai=directions&v=8830e85 — both skins, all8 facings, half speed default.
- Exact public build-info commit matched8830e85e600acb3e97509ed3de8a61c9202b551c. node scripts/ci/smoke/smoke.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha 8830e85e600acb3e97509ed3de8a61c9202b551c --out-dir build/kunai-eight-live-smoke --label kunai-eight-live — PASS;9 served-file SHA256 hashes matched, ready/nonblank/input-effect checks passed,0 fatal console events. Evidence: build/kunai-eight-live-smoke/smoke-result.json (4 nonfatal environment warnings retained in console-log.json).
- KUNAI_URL=https://kiotdstudios.github.io/shinobi-rush/ KUNAI_OUT=build/kunai-eight-live-review node docs/visuals/kunai-eight/browser-proof.mjs — PASS192 paired poses,8 directions, exact steps, sockets/layers, controls and cache bounds;0 browser errors.
- KUNAI_URL=https://kiotdstudios.github.io/shinobi-rush/ KUNAI_OUT=build/kunai-eight-live-gameplay node docs/visuals/kunai-eight/gameplay-proof.mjs — PASS actual-key player attacks in8 directions, no fallback, cleanup and actual bandit melee light1/light2;0 errors.
- Opened actual public review in the in-app browser, visually checked both actors, clicked Pause, N and Step (north light1 key1 shown for both), then restored SE/both/half-speed playback and kept the tab as deliverable.
- Chakra PR107 checked again: draft=true, merged=false; rejected art remains paused.
- This follow-up changes order/report documentation only; no new runtime deployment is applicable. Runtime delivery is the verified merge above. The completed report is pushed on the delivery branch to retain final evidence without rebuilding identical game content.
