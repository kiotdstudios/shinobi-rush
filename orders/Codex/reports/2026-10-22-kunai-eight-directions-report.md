# Job Report — Shared eight-direction kunai combat
- Agent: Codex
- Order: orders/Codex/2026-10-22-kunai-eight-directions.md
- Date:2026-10-22; continuation2026-10-23
- Final status: REVIEW — local acceptance passed; PR/publication pending
- Commit / PR: Not committed; all pre-commit acceptance checks now passed.

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
Commit/push, required CI/PR integration, Pages publication and exact-SHA live feature/gameplay smoke. Add actual commit/PR/deployment evidence in a report update. Keep chakra paused. Other queued bandit action-art requests outside these attacks/guard remain separate.
