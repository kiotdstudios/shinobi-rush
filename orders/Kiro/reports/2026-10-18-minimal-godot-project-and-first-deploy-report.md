# Job Report — Minimal Godot project and first deploy (stage 2 of 2)
- Agent: Kiro
- Order: [orders/Kiro/order_01.md](../order_01.md)
- Date: 2026-10-18
- Final status: IN_PROGRESS — stage 2 of 2: PR open, first deployment pending. Local verification on Windows is complete (table below); GitHub Actions evidence for this pull request is not available yet and is added by the CI step. **Live deployment: PENDING (deploys on merge to main; verified separately by the orchestrator).**
- Commit / PR: PR link and commit SHAs are not recorded yet. They are added in a report-only follow-up commit once the pull request exists. Branch: `kiro/order-01-stage2-godot-project` (from `main` 5dcad328ed6961f81888c9762df4a06f1ee0214e, the merge of stage 1, PR #4).

## Work completed
- **Minimal real Godot 4.7.2 project at the repository root** (the locked architecture, section 11 of `docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md`): GL Compatibility, one single-threaded Web export preset named `Web`, main scene `res://scenes/main.tscn`, a training arena with a controllable placeholder player (WASD move, Shift sprint, InputMap actions, wall collision), a debug HUD, an animation lab for judging sprite size and animation (compare view for two sets, zoom, overlays), a `JavaScriptBridge` readiness hook `window.__SHINOBI_READY__` and a state object `window.__SHINOBI_STATE__`.
- **Placeholder art only.** The figure is a labelled placeholder (`BOOTSTRAP BUILD - PLACEHOLDER ART`, `SPRITES: none (placeholder)`). Nothing was copied from `assets/`, no sprite set is committed, and no generated test sprite was committed.
- **Sprite drop-in contract for Codex** (`docs/prototype/SPRITE_DROP_IN.md`): a `*.manifest.json` per set plus PNGs, no code edits needed. **128x128 RGBA is the documented production default** (owner-approved scale); 64x64 is supported as review evidence and the lab compares two sets. Next step for Codex: drop a manifest and frames into `assets/characters/player/`, push, open the live build.
- **Pipeline additions:** built-in test runner `res://tests/run_tests.gd` detected by `godot_ci.py tests`; sprite manifest validator `scripts/ci/validate_sprite_manifests.py` (wired into the `detect` job, independent of the current directory); controls probe `scripts/ci/smoke/controls-probe.mjs` in `smoke-predeploy`; `check-export` now asserts `project.binary` and every sprite manifest and sprite PNG import record are inside `index.pck` (`EXPORT011`; asserts 0 sprites while no art exists); `smoke-config.json` now requires the ready hook and an input effect.
- **Stage 1 review follow-ups:** `sanitize()` neutralises a leading `::` after any Unicode whitespace (new U+00A0 etc. tests, `Found Godot project` print routed through it); `PRJ012` is an error when `assets/characters/player/references` lacks `.gdignore`; the stray `>` was removed from the stage 1 report; the self-test harness test no longer depends on the shipped `smoke-config.json`.
- **`.gdignore` markers** (empty files): `docs/`, `orders/`, `world/`, `skills/`, `scripts/ci/`, `exports/`, and `assets/characters/player/references/`. **The `assets/characters/player/references/.gdignore` file is the only touch under `assets/`**: required (the approved turnaround must never be imported or shipped), harmless, and not an asset. Codex's art is untouched.
- **Docs and bookkeeping:** `GODOT_CI_AND_DEPLOYMENT.md` and `GODOT_PROJECT_HANDOFF.md` updated (project exists, `.gdignore` files, test runner, manifest validator, controls probe, what a failing job means, first-deploy expectations, manual rollback); `order_01.md` stays IN_PROGRESS with acceptance boxes unticked except where local evidence proves them (only box 1); this report.
- **GitHub Pages:** enabled by the orchestrator with the owner's authorization on 2026-10-18 (not by this pull request or CI); baseline B: `build_type=workflow`, `https://kiotdstudios.github.io/shinobi-rush/`, environment `github-pages` with a main-only branch policy. This job changed no repository or admin setting. The site is not deployed (HTTP 404 expected until the first deployment).
- **Not verified (stated plainly):** controller hardware, a DualSense in browsers, Safari and mobile browsers, real art, and 60 FPS on a real GPU (FPS could only be observed under software GL, 4 to 6 FPS in headless Chromium, so smoothness is not verified). Codex or the owner should judge frame pacing on the live build.

## Files changed
Not listed file by file yet; the exact `git diff --stat` and SHAs come with the report-only follow-up. Areas: Godot project files at the root (`project.godot`, `export_presets.cfg`, `icon.svg`, `icon.svg.import`, `scenes/`, `scripts/arena|player|sprites|ui|web`, `tests/`); `scripts/ci/**` (patches, validator, probe, tests); `.github/workflows/godot-ci.yml` and `pipeline-self-test.yml`; `.gitignore` (`exports/*` plus `!exports/.gdignore` instead of `/exports/`, so the marker is trackable); `docs/development/*`; `docs/prototype/TESTING.md` and `SPRITE_DROP_IN.md`; the `.gdignore` files; `orders/Kiro/order_01.md` and reports. No file of other agents or of open PRs #1, #2 and #3 was edited.

## Tests run before commit
Environment: Windows, PowerShell 5.1, Godot 4.7.2.stable (`Godot_v4.7.2-stable_win64_console.exe`), Node v24.19.0, Chromium via Playwright under `%TEMP%\shinobi-stage2b\pw-browsers`, ephemeral ports. Durations are wall clock. Results are quoted from the stage 2B progress log. Run URLs: none yet (pending CI run).

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python -m unittest discover -s scripts/ci/tests` | Ran 131 tests OK, rc=0, 6.3 s | local, progress log B5 part 1 |
| `python -m unittest scripts/ci/test_validate_sprite_manifests.py` | Ran 23 tests OK, rc=0, ~1 s | local |
| `(cd scripts/ci/smoke) node --test` | first run rc=1, 22/23: `ready hook: --require-ready-hook and the config key reach the verdict` failed (the test parsed the shipped `smoke-config.json`, where B2 set `require_ready_hook=true`, while it expected the default). Test-only fix (`--config <missing file>`), commit 7da1ff2. Re-run: 23/23 pass, 0 fail, rc=0, 0.65 s | local |
| `python scripts/ci/check_workflows.py` | `check_workflows: OK - 0 problem(s)`, rc=0, 0.4 s | local |
| `python scripts/ci/validate_orders.py` | `Agent READMEs and order structure validated.`, rc=0, 0.2 s | local |
| `python scripts/ci/validate_godot_project.py --project c:\shinobi-rush --repo-root c:\shinobi-rush` | PASS 0 errors 0 warnings (engine 4.7.x), rc=0, 0.4 s | local |
| `GODOT_BIN --headless --path c:\shinobi-rush --import` | rc=0, 4.9 s | local |
| `godot_ci.py validate-resources --project c:\shinobi-rush` | `validated 11 scripts, 3 scenes, 0 resources, 0 failures`, rc=0, 1.5 s | local |
| `godot_ci.py import --project c:\shinobi-rush` (wrapper) | rc=0, 5.6 s | local |
| `godot_ci.py tests --project c:\shinobi-rush` | `SUMMARY: 123 passed, 0 failed`, rc=0, 7.7 s (one non-failing WARNING from the deliberate bad-sheet negative test) | local |
| `godot_ci.py export --project c:\shinobi-rush --out %TEMP%\shinobi-stage2b\b5-export` | rc=0, 5.4 s (export left outside the repo) | local |
| `godot_ci.py finalize-export --kind game` | rc=0, 0.7 s (`export OK ... 36 MiB, build-info.json written for commit 7da1ff2`) | local |
| `godot_ci.py check-export --dir ...\b5-export --kind game --project c:\shinobi-rush` | `export check: OK`; `PCK contents: project.binary present; asserted 0 sprite manifest(s) and 0 sprite PNG import record(s)`, rc=0, 0.3 s | local |
| `python scripts/ci/validate_sprite_manifests.py` (plain, repository root) | `No sprite manifests under C:\shinobi-rush\assets\characters (nothing to validate).` rc=0, 0.2 s | local |
| `python scripts/ci/selftest.py --godot-dir ...\godot-threaded --work-dir ...\selftest-work --evidence-dir ...\selftest-evidence` (full run, second Godot with threaded templates installed first) | rc=0, 182 s, `PASS: all 16 cases ran; 36/36 expectations met`; 36 PASS lines, 0 FAIL; the negative cases failed at the right step | local |
| `(cd scripts/ci/smoke) node smoke.mjs --serve-dir <b5-export> --out-dir evidence\smoke-local --label local --expected-sha 7da1ff2bd6c9a8e9144f4e24adcb4a3da2bfd608` (real Chromium) | VERDICT PASS rc=0, 24 s. webgl2 (SwiftShader), build-info matches, 9 served files match sha256, engine-start 4284 ms, canvas 1280x720 not blank (58 colours), ready-hook true, input-effect 3.701% pixels changed, Emscripten 4.0.20 single-threaded + Compatibility, no-fatal-console (8 events, 4 warnings, 0 fatal) | local, `stage2b\evidence\smoke-local*` |
| `node controls-probe.mjs --serve-dir <b5-export> --out-dir evidence\probe-local` (real Chromium) | VERDICT PASS rc=0, 30 s. ready 4087 ms; walk dx 70.0 per 500 ms (MOVE); sprint dx 106.2 (`sprinting=true`); wall: 3 later samples spread 0.00; 0 console errors / 7 msgs | local, `stage2b\evidence\probe-local*` |
| Earlier probe run, same export (commit 75e1d49 step): hooks-absent run on a plain page | `SKIPPED` note, rc=0 | local |
| PCK content check with a synthetic manifest + PNG (not committed, deleted) | export-with-sprites `check-export` rc=0 `asserted 1 manifest, 1 PNG`; the same check on the sprite-less export rc=1 with 2x `EXPORT011` | local |
| Compare view with two synthetic sets (`__verify__128`, `__verify__64`, generated in a temp copy, never in the repo, deleted afterwards): `compare-shots.mjs`, 1280x720, zoom 1x and 2x, idle and run; six screenshots opened and inspected | rc=0, 24 s, 0 error/pageerror. Caption overlap: none at 1x and 2x. Nothing hidden under the lab panel at 1x/2x/3x. One minor observation, see Issues | local, `stage2b\evidence\compare\cmp-00..05` |
| `git status --short --ignored` after the runs | only `!! scripts/ci/smoke/node_modules/` (ignored); no export output in the repo; `git ls-files` matching `__verify__`: 0 | local |

Not run by this report step: nothing was re-run for the documentation commit. GitHub Actions runs for this branch: pending CI run.

## Issues encountered
- **Harness test depended on the shipped config** (found by `node --test`): fixed in the test (commit 7da1ff2), not by relaxing a gate.
- **`.gitignore` rule `/exports/` broke a workflow-lint test and hid the marker:** replaced by `exports/*` plus `!exports/.gdignore`; the lint test was updated to match.
- **Minor layout observation (not fixed, product decision):** in the compare view at 2x zoom the translucent HUD backing panel (top left) dims the head and upper body of the 128 stand; at 3x/4x the stands are partly or fully off screen (documented limit). Workaround: use 1x, or walk N/W. Possible fixes (move the stands, or hide/shrink the HUD while compare is on) change the 1x look and were not applied.
- **Smoothness unverified:** FPS could only be observed under software GL (4 to 6 FPS in headless Chromium).
- **Shell tool dropped some command outputs;** each affected command was re-run with output redirected, and the table only lists results seen in a completed call.
- **The Godot jobs have not yet run on a GitHub runner against this project.** Expect glue defects on the first run; they are fixed in this pull request, never by relaxing a gate.
- **Rollback is a revert-and-redeploy, not a dispatch of an old commit:** `deploy` only runs on `main` and builds the commit it was started on, so `workflow_dispatch` rebuilds the head of `main`. Documented in `GODOT_CI_AND_DEPLOYMENT.md#manual-rollback`; re-running the last good run is documented but not yet exercised.
- Not verified at all: controller hardware, DualSense in browsers, Safari and mobile, real art, 60 FPS on a real GPU.

## Questions for project owner
- RESOLVED: who owns the bootstrap (Kiro, reassigned) and whether Kiro should build a minimal project (yes, 2026-10-17); enabling Pages (done 2026-10-18); merge authorization (the orchestrator merges once checks are green).
- STILL OPEN: add the pipeline's gate check (`godot-ci-gate`, and optionally `Godot CI / detect`) to the ruleset's required status checks. Recommended after the first green `main` run, because GitHub only offers checks it has seen recently. Until then a red Godot job does not block merging.
- STILL OPEN (owner or Codex): judge animation, sprite size and frame pacing on the real live build with a real GPU, and say whether the HUD dimming at 2x compare zoom should be fixed.
- STILL OPEN: PR #2 (debug telemetry) adds a spec and two orders; should its Kiro order extend this project's `window.__SHINOBI_STATE__` or replace it?

## Outstanding work / next steps
- Open the pull request, drive CI to green, then add the PR link, SHAs and run URLs in a report-only follow-up commit (and tick the order boxes that CI proves).
- The orchestrator merges, watches the first deployment (`deploy`, `smoke-postdeploy`, `deploy-info.json`), verifies `https://kiotdstudios.github.io/shinobi-rush/` (expected, not verified) and only then closes the order out (its final status is set by the orchestrator, not by this report).
- **Live deployment: PENDING (deploys on merge to main; verified separately by the orchestrator).**
- Codex drop-in via manifest (`docs/prototype/SPRITE_DROP_IN.md`, 128x128 default).
- PR #2 debug telemetry coexistence: check that its debug log export does not clash with `window.__SHINOBI_STATE__` / `__SHINOBI_READY__` and with the smoke console policy once it is merged.
- Recommended admin step: add the gate check to the ruleset's required checks after the first green `main` run.
- Optional polish listed as follow-ups: stand caption direction fallback marker (`SE>S`), fewer per-frame allocations in the lab and player visual, the compare-view HUD overlap at 2x.
- Release (non-debug) export and gdUnit4 verification stay out of scope.
