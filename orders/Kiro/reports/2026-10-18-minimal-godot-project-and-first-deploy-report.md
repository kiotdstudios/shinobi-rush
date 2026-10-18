# Job Report — Minimal Godot project and first deploy (stage 2 of 2)
- Agent: Kiro
- Order: [orders/Kiro/order_01.md](../order_01.md)
- Date: 2026-10-18
- Final status: DONE (stage 2 delivered; the live deployment was verified by the orchestrator on 2026-10-18, see "Live deployment evidence" below). Local verification on Windows was complete and all GitHub Actions checks were green before the merge; the CI tables below describe the implementation head 857cc16.
- Commit / PR: [PR #6](https://github.com/kiotdstudios/shinobi-rush/pull/6) (merged 2026-10-18T14:54Z, merge commit d651078). Implementation head SHA checked by CI: `857cc16636b9b2e062d6cdb40c9f6033cbd9fbd6`; report-only follow-up commits sit on top of it (see `git log`). Implementation commits (all prefixed `Order 01 (Kiro): `): 17a9965 (project), 97a5cf1 (scripts/ci patches), 786c085 (review follow-ups), 75e1d49 (controls probe in CI, PCK assertion), 6ff00f1 (wires the manifest validator into CI and makes it cwd-independent), 7da1ff2 (smoke test fix), 857cc16 (docs). Branch: `kiro/order-01-stage2-godot-project` (from `main` 5dcad328ed6961f81888c9762df4a06f1ee0214e, the merge of stage 1, PR #4).

## Work completed
- **Minimal real Godot 4.7.2 project at the repository root** (the locked architecture, section 11 of `docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md`): GL Compatibility, one single-threaded Web export preset named `Web`, main scene `res://scenes/main.tscn`, a training arena with a controllable placeholder player (WASD move, Shift sprint, InputMap actions, wall collision), a debug HUD, an animation lab for judging sprite size and animation (compare view for two sets, zoom, overlays), a `JavaScriptBridge` readiness hook `window.__SHINOBI_READY__` and a state object `window.__SHINOBI_STATE__`.
- **Placeholder art only.** The figure is a labelled placeholder (`BOOTSTRAP BUILD - PLACEHOLDER ART`, `SPRITES: none (placeholder)`). Nothing was copied from `assets/`, no sprite set is committed, and no generated test sprite was committed.
- **Sprite drop-in contract for Codex** (`docs/prototype/SPRITE_DROP_IN.md`): a `*.manifest.json` per set plus PNGs, no code edits needed. **Production frames are 128x128 RGBA (locked; 64x64 is legacy reference only, never shipped)** and the lab compares any two sets. Next step for Codex: drop a manifest and frames into `assets/characters/player/`, push, open the live build.
- **Pipeline additions:** built-in test runner `res://tests/run_tests.gd` detected by `godot_ci.py tests`; sprite manifest validator `scripts/ci/validate_sprite_manifests.py` (wired into the `detect` job, independent of the current directory); controls probe `scripts/ci/smoke/controls-probe.mjs` in `smoke-predeploy`; `check-export` now asserts `project.binary` and every sprite manifest and sprite PNG import record are inside `index.pck` (`EXPORT011`; asserts 0 sprites while no art exists); `smoke-config.json` now requires the ready hook and an input effect.
- **Stage 1 review follow-ups:** `sanitize()` neutralises a leading `::` after any Unicode whitespace (new U+00A0 etc. tests, `Found Godot project` print routed through it); `PRJ012` is an error when `assets/characters/player/references` lacks `.gdignore`; the stray `>` was removed from the stage 1 report; the self-test harness test no longer depends on the shipped `smoke-config.json`.
- **`.gdignore` markers** (empty files): `docs/`, `orders/`, `world/`, `skills/`, `scripts/ci/`, `exports/`, and `assets/characters/player/references/`. **The `assets/characters/player/references/.gdignore` file is the only touch under `assets/`**: required (the approved turnaround must never be imported or shipped), harmless, and not an asset. Codex's art is untouched.
- **Docs and bookkeeping:** `GODOT_CI_AND_DEPLOYMENT.md` and `GODOT_PROJECT_HANDOFF.md` updated (project exists, `.gdignore` files, test runner, manifest validator, controls probe, what a failing job means, first-deploy expectations, manual rollback); `order_01.md` stays IN_PROGRESS with acceptance boxes 1 to 3 ticked (box 1 on local plus CI evidence, boxes 2 and 3 on CI evidence), the rest unticked; this report.
- **GitHub Pages:** enabled by the orchestrator with the owner's authorization on 2026-10-18 (not by this pull request or CI); baseline B: `build_type=workflow`, `https://kiotdstudios.github.io/shinobi-rush/`, environment `github-pages` with a main-only branch policy. This job changed no repository or admin setting. At the time of this job the site was not yet deployed; it is now (see "Live deployment evidence" below).
- **Not verified (stated plainly):** controller hardware, a DualSense in browsers, Safari and mobile browsers, real art, and 60 FPS on a real GPU (FPS could only be observed under software GL, 4 to 6 FPS in headless Chromium, so smoothness is not verified). Codex or the owner should judge frame pacing on the live build.

## Files changed
Paths by area (full list: `git diff --stat origin/main...HEAD` or the PR's Files tab): Godot project files at the root (`project.godot`, `export_presets.cfg`, `icon.svg`, `icon.svg.import`, `scenes/`, `scripts/arena|player|sprites|ui|web`, `tests/`); `scripts/ci/**` (patches, validator, probe, tests); `.github/workflows/godot-ci.yml` and `pipeline-self-test.yml`; `.gitignore` (`exports/*` plus `!exports/.gdignore` instead of `/exports/`, so the marker is trackable); `docs/development/*`; `docs/prototype/TESTING.md` and `SPRITE_DROP_IN.md`; the `.gdignore` files; `orders/Kiro/order_01.md` and reports. No file of other agents or of open PRs #1, #2 and #3 was edited. Decisions: `.gitignore` uses `exports/*` plus `!exports/.gdignore` so the marker is trackable; `PRJ012` is an error when the references folder lacks `.gdignore`; `check-export` defaults its project to the repository root; the validator defaults its repo root to the script location. `docs/prototype/`, `world/` and `skills/` received new files only.

## Tests run before commit
Environment: Windows, PowerShell 5.1, Godot 4.7.2.stable (`Godot_v4.7.2-stable_win64_console.exe`), Node v24.19.0, Chromium via Playwright under `%TEMP%\shinobi-stage2b\pw-browsers`, ephemeral ports. Durations are wall clock. Results are quoted from the stage 2B progress log. Local rows have no run URL; the GitHub Actions runs are in the CI table below.

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

Not run by this report step: nothing was re-run for the documentation commit. GitHub Actions runs for this branch: see the next section.
## GitHub Actions results (pull request #6, head `857cc16636b9b2e062d6cdb40c9f6033cbd9fbd6`, all first attempts, no fixes needed)
| Check (workflow) | Conclusion | Run |
| --- | --- | --- |
| `validate-orders-and-project` (Repository checks) | success | [39133101233](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39133101233) |
| `Detect Godot project` (Godot CI) | success | [39133101326](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39133101326) |
| `Import, validate, test and export (Web)` (Godot CI) | success | same run |
| `Pre-deploy browser smoke test` (Godot CI) | success | same run |
| `godot-ci-gate` (Godot CI) | success | same run |
| `Deploy to GitHub Pages (main only)` (Godot CI) | skipped by design on pull requests | same run |
| `Post-deploy live smoke test` (Godot CI) | skipped by design on pull requests | same run |
| `Tooling lint and unit tests` (Pipeline self-test) | success | [39133101282](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39133101282) |
| `Self-test - positive and negative cases` (Pipeline self-test) | success | same run |
Status read from `gh pr view 6 --json statusCheckRollup` and `gh run list`. Deploy and post-deploy did not run, so nothing is deployed.
### Evidence artifacts inspected (downloaded with `gh run download 39133101326` into a temp folder outside the repo)
- `web-export/build-info.json` and `smoke-predeploy/build-info.json`: `kind=game`, `export_preset=Web`, `export_mode=debug`, `godot_version=4.7.2-stable`, templates `4.7.2.stable`, `renderer=gl_compatibility`, `thread_support=false`, `event=pull_request`, `run_id=39133101326`, `head_sha=857cc16...`. `commit_sha` is `9a66e0b67d4f725cbba40314ccbe1a5ee5552886`, the pull request merge commit (`refs/pull/6/merge`) that CI checked out, not the branch head; it is not a commit on the branch. I re-hashed the 9 exported files with SHA-256 and all match the manifest. The two build-info copies have identical field values.
- `smoke-result.json` / `summary.md`: VERDICT PASS, 11 checks passed: webgl2 (SwiftShader), build-info matches expected commit, 9 served files verified by sha256, engine-start 2704 ms, canvas 1280x720 not blank (58 colours), ready hook true, input-effect 4.168% pixels changed (needs >= 0.10%), Emscripten 4.0.20 single-threaded with Compatibility renderer, console 8 events, 4 warnings, 0 fatal.
- `controls-probe/probe-result.json`: 6/6 pass: ready after 1428 ms, walk dx 90.4 per 500 ms (MOVE), sprint dx 169.2 (SPRINT, `sprinting=true`), wall: y 60 to -488 with 3 later samples spread 0.00, 7 console messages, 0 errors. These dx values differ from the local run (70.0 / 106.2) because frame rate differs on the runner; the checks are relative.
- `logs/tests-builtin.log`: `SUMMARY: 123 passed, 0 failed`. `project-validation.json`: `[]` (no findings). Import, export and resource-validation logs are present.
- Screenshots opened and looked at: `01-settled.png` shows IDLE, Pos (0, 60), `SPRITES: none (placeholder)` and the placeholder figure among labelled blocks; `02-after-input.png` shows IDLE, Speed 0, Pos (90, 60) (the key press had already ended); `probe-03-sprint.png` shows SPRINT at 270 px/s, Pos (351, 60); `probe-04-at-wall.png` shows MOVE at 175 px/s, Pos (441, -487), where the player is cut off at the top edge of the frame (only feet and shadow visible). FPS shows 6 to 8 (software GL on the runner), so smoothness remains unverified.
- This is a CI export served locally on the runner, not the live site.

## Issues encountered
- **Harness test depended on the shipped config** (found by `node --test`): fixed in the test (commit 7da1ff2), not by relaxing a gate.
- **`.gitignore` rule `/exports/` broke a workflow-lint test and hid the marker:** replaced by `exports/*` plus `!exports/.gdignore`; the lint test was updated to match.
- **Minor layout observation (not fixed, product decision):** in the compare view at 2x zoom the translucent HUD backing panel (top left) dims the head and upper body of the 128 stand; at 3x/4x the stands are partly or fully off screen (documented limit). Workaround: use 1x, or walk N/W. Possible fixes (move the stands, or hide/shrink the HUD while compare is on) change the 1x look and were not applied.
- **Known limitation, north wall clip:** at the north wall the camera limit equals the arena bound, so the player is almost off-screen (only feet and shadow visible). A top margin on the camera limit would fix it; that is game code and was not changed.
- **Smoothness unverified:** FPS could only be observed under software GL (4 to 6 FPS in headless Chromium).
- **Shell tool dropped some command outputs;** each affected command was re-run with output redirected, and the table only lists results seen in a completed call.
- **First GitHub run of the Godot jobs against this project:** all green on the first attempt for head 857cc16, no glue defects found, no gate relaxed.
- **Rollback is a revert-and-redeploy, not a dispatch of an old commit:** `deploy` only runs on `main` and builds the commit it was started on, so `workflow_dispatch` rebuilds the head of `main`. Documented in `GODOT_CI_AND_DEPLOYMENT.md#manual-rollback`; re-running the last good run is documented but not yet exercised.
- Not verified at all: controller hardware, DualSense in browsers, Safari and mobile, real art, 60 FPS on a real GPU.

## Live deployment evidence (added after the merge, verified by the orchestrator)
- **First deployment:** [Godot CI run 39138070349](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39138070349) (push to `main`, commit d651078): detect, build, pre-deploy smoke, deploy, post-deploy smoke and `godot-ci-gate` all success. https://kiotdstudios.github.io/shinobi-rush/ returned HTTP 200 and its `build-info.json` reported `commit_sha` d6510784aaf9c588928f62554bf3cd04b5cd687d. Pages serves gzip: `index.wasm` about 38 MB raw and 10.2 MB gzip, `index.pck` 76 KB raw.
- **Post-deploy smoke on the real URL:** 11 of 11 checks pass (WebGL2, `build-info` kind=game with the expected commit, 9 served files match the build's SHA-256 hashes, page load 200, engine start 3.3 s, canvas 1280x720 not blank, `__SHINOBI_READY__` true, keyboard input changes 4.18% of sampled pixels, engine evidence single-threaded Compatibility, 7 console events with 0 fatal). The evidence screenshots were opened: the placeholder arena renders and holding D moved the player from x=0 to x=90.
- **Latest verified:** [run 39158946428](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39158946428) (commit 068047e, PR #8), built 2026-10-18T19:29Z; all six jobs success; the live `build-info.json` reports 068047e. A live screenshot was opened: figure about 108 px tall at the 128x128 scale.
- **Admin state read back after the fact:** Pages `build_type=workflow`; environment `github-pages` with a main-only branch policy; ruleset "Agent Rules" now requires `validate-orders-and-project` and `godot-ci-gate` (all other rules unchanged).
- **Still not verified:** controller hardware, DualSense in browsers, Safari/mobile, real art, and frame rate on a real GPU.

## Questions for project owner
- RESOLVED: who owns the bootstrap (Kiro, reassigned) and whether Kiro should build a minimal project (yes, 2026-10-17); enabling Pages (done 2026-10-18); merge authorization (the orchestrator merges once checks are green).
- RESOLVED 2026-10-18: `godot-ci-gate` was added to the ruleset's required status checks after the first green `main` runs (by the orchestrator, with the owner's authorization); a red Godot job now blocks merging.
- STILL OPEN (owner or Codex): judge animation, sprite size and frame pacing on the real live build with a real GPU, and say whether the HUD dimming at 2x compare zoom should be fixed.
- RESOLVED: the debug log (PR #10) extends rather than replaces `window.__SHINOBI_STATE__` and `__SHINOBI_READY__`; both are still the CI contract and the live smoke test passes alongside it.

## Outstanding work / next steps
- Pull request #6 was merged (d651078).
- Done: the orchestrator watched the first deployment ([run 39138070349](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39138070349)) and verified https://kiotdstudios.github.io/shinobi-rush/ (see "Live deployment evidence").
- **Live deployment: VERIFIED** (2026-10-18).
- Codex drop-in via manifest (`docs/prototype/SPRITE_DROP_IN.md`, 128x128 default).
- Debug log coexistence: verified. PR #10 is merged and the live smoke test and controls probe pass alongside it.
- Done 2026-10-18: the gate check is in the ruleset's required checks.
- Optional polish listed as follow-ups: stand caption direction fallback marker (`SE>S`), fewer per-frame allocations in the lab and player visual, the compare-view HUD overlap at 2x.
- Review follow-ups deferred (non-blocking): sanitise manifest text printed as `::error` in `validate_sprite_manifests.py` (encode `%`, CR, LF) with a unit test; unit tests for the builtin branches of `cmd_tests`; make `sprint-faster` in the controls probe robust to sampling jitter (known risk: a few percent chance of a spurious red on a slow runner; if only `sprint-faster` fails, re-run once, then investigate); the first-run checklist was not walked item by item.
- Release (non-debug) export and gdUnit4 verification stay out of scope.
