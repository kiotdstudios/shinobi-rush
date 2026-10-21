# Job Report — Bandit gait continuity, pursuit and ninja evade
- Agent: Codex
- Order: orders/Codex/2026-10-21-bandit-chase-evade.md; direct owner request
- Date: 2026-10-21
- Final status: DONE — merged, deployed and independently live-tested
- Commit / PR: implementation7fd035c776a1f214f4aa8ea6235f15ef2f372f81; https://github.com/kiotdstudios/shinobi-rush/pull/52. Original report written before implementation commit.

## Work completed
Paused kunai work. Audited every bandit run frame and all160 existing body PNGs. Corrected bandit-local gait restarts across direction/action changes; added near-distance hysteresis, regular run and fast arms-back pursuit. Detected player is pursued at470px/s (near320), versus previous160. Existing idle/run/sprint are all actively selected.

Added lateral/away evasion when the player approaches or targets the bandit. Burst0.20sec at640px/s with1.25sec cooldown, full-distance collision checks on both sides, no teleport or invulnerability. Damage interrupts normally. Six original generated dark traversal-streak frames are a separate nearest-filtered transparent VFX layer. No enemy attack added.

Added minimal L/R3 lock-on selection helper and readable target brackets; no camera rotation, movement steering, combat hitbox or player-controller modifications. Additive read-only WebBridge diagnostics enable actual input-based browser checks.

## Files changed
- scripts/enemy/bandit.gd, bandit_visual.gd: pursuit/evasion and phase continuity.
- scripts/player/player_lock_on.gd (+uid), scenes/player/player.tscn: bounded targeting helper.
- scripts/ui/debug_hud.gd: target-toggle control legend.
- scripts/web/web_bridge.gd: additive enemy/target telemetry.
- assets/vfx/ninja_evade/: six PNGs/import sidecars plus timing metadata.
- tests/test_bandit_chase.gd (+uid), tests/run_tests.gd:16 behavior regression checks.
- scripts/ci/smoke/bandit-probe.mjs: actual-keyboard Web feature test.
- docs/visuals/bandit-chase-evade/: frame audit, normal/half previews, VFX sheet and browser evidence.

## Tests run BEFORE commit
Windows, Godot4.7.2 console, bundled Python/Node, headless Chromium software renderer.
Set GODOT_BIN to .tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe (absolute workspace path).

| Exact command / manual steps | Result | Evidence |
|---|---|---|
| python scripts/ci/godot_ci.py import --project . --log-dir build/bandit-chase | PASS; new assets import | build/bandit-chase/import.log |
| python scripts/ci/godot_ci.py tests --project . --log-dir build/bandit-chase-final |642 passed,0 failed | build/bandit-chase-final/tests-builtin.log |
| python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/bandit-chase-final |38 scripts,6 scenes,0 failures | validation log |
| python scripts/ci/godot_ci.py export --project . --out ../bandit-chase-web --log-dir build/bandit-chase-export | PASS Web debug export | export.log |
| python scripts/ci/godot_ci.py finalize-export --project . --out ../bandit-chase-web --kind game --commit-sha 9bc99f2cf165a6354383c8d6c213a8ad977b7b41 | PASS; local uncommitted source uses base identifier only, not a deployment claim | local smoke build info |
| node scripts/ci/smoke/bandit-probe.mjs --serve-dir ../bandit-chase-web --out-dir build/bandit-feature-probe | All9 checks PASS: lock/unlock, evade on lock, evade on approach, EVADE state seen, sprint/run/idle observed,0 browser errors | docs/visuals/bandit-chase-evade/local-feature-probe.json |
| node scripts/ci/smoke/controls-probe.mjs --serve-dir ../bandit-chase-web --out-dir build/bandit-chase-controls | PASS movement393.8, sprint607.5, wall stop, lab, jump/dodge, camera presets,0 console errors | local-controls.json |
| node scripts/ci/smoke/smoke.mjs --serve-dir ../bandit-chase-web --out-dir build/bandit-chase-smoke --label bandit-chase-local | PASS rendered canvas, actual keys, file hashes,0 fatal errors | local-smoke.json |
| Pillow source/QC and contact-sheet inspection |160 unique approved frames;128px binary-alpha body assets retained. Separate VFX thresholded/palette-cleaned, no new body interpolation | asset-qc.json, contact sheets and GIFs |
| git diff --check | PASS | local command |

## Issues encountered / limitations
The source clip has stronger diagonal/lateral loop seams (documented in the audit); no duplicate files. Removing frame0 did not consistently improve the seam, so approved body pixels/order are retained. This change fixes live restart/chatter rather than claiming redrawn source in-betweens. Full Godot tests initially626 passed before adding16 focused checks, then642 passed with those checks.

Initial export destination was occupied and rejected; fresh ../bandit-chase-web used. A shortened finalize SHA was rejected; rerun successfully with40-character SHA. These were tooling argument corrections, not runtime failures. Expected malformed-sheet test emits a fixture warning; all assertions pass. Software-rendered browser performance is not hardware performance evidence. Physical gamepad was unavailable; R3 uses Godot's named right-stick constant, keyboard toggle was browser-tested. A screenshot triggered from sampled EVADE telemetry can capture a later pose due browser/render timing; state/frame tests and the separate VFX contact sheet verify the effect setup.

## Questions for project owner
None.

## Outstanding work / next steps
PR/CI/review, merge, Pages deployment, live SHA and actual-keyboard smoke verification. Do not mark DONE before those complete. Optional future art refinement: authored transition poses for rough source run seams; no frame omission or synthetic interpolation applied here. Kunai remains paused.

## Integration retest before merge-update commit
Main advanced to111182a (Aki HUD live zoom readout). Merged without committing, preserving both HUD legend and zoom. Re-ran `python scripts/ci/godot_ci.py tests --project . --log-dir build/bandit-chase-merged`:642 passed,0 failed. Exported fresh `../bandit-chase-merged-web`, finalized using current premerge implementation identifier, ran `node scripts/ci/smoke/smoke.mjs --serve-dir ../bandit-chase-merged-web --out-dir build/bandit-merged-smoke --label bandit-chase-merged`:PASS,0 fatal errors. Local artifacts still use base identifiers for uncommitted sources; deployed SHA must be independently checked after integration.

## Verified live delivery — 2026-10-21 11:08 UTC
PR52 merged after all checks were green and merge state clean, using expected head9f9216ac93f3de7c52ed8a08b592f779b9414cb8. Live merge SHA **fa85e9399c019f627ceb806f6805f427ed68554f**.

- PR: https://github.com/kiotdstudios/shinobi-rush/pull/52
- Main CI/deploy: https://github.com/kiotdstudios/shinobi-rush/actions/runs/39589013113 — import/tests/export, predeploy browser, Pages deploy, postdeploy live smoke and gate all success. Repository checks and pipeline self-test also success.
- Public build-info.json independently reports the exact merge SHA.
- `node scripts/ci/smoke/smoke.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha fa85e9399c019f627ceb806f6805f427ed68554f --out-dir build/bandit-live-smoke --label bandit-live`: PASS;9 served files hash-verified, nonblank rendered game, actual movement/dodge/attack keys,0 fatal errors.
- `node scripts/ci/smoke/bandit-probe.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --out-dir build/bandit-live-feature`: all9 feature checks PASS again on the public game, including L toggle/unlock, evasion on target lock and on unlocked approach, sprint/run/idle seen,0 browser errors.
- Live screenshot inspected: correct approved player/red-scarf bandit, Aki zoom readout retained, controls legend includes L/R3. Public browser tab requested in Codex; app returned queued (no claim it is already visible).
- Evidence: docs/visuals/bandit-chase-evade/live-{feature-probe.json,smoke.json,gameplay.png}.
- Test URL: https://kiotdstudios.github.io/shinobi-rush/?camera=close&v=fa85e93

No remaining deployment or test blockers. Source-art loop-seam observation above remains an explicit art-quality limitation, not a deployment failure. Kunai work stays paused. This final evidence/status update is a report-only follow-up commit on the delivery branch; it changes no runtime source.
