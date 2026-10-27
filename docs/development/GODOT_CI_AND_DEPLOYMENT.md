# Godot CI, Web export and live-test deployment

Owner: Kiro (Order 01, DONE and verified live on 2026-10-18). Audience: anyone who merges to `main`, whoever builds the Godot project, and repository administrators.

## Status: read this first

- **Order 01 is DONE (verified live on 2026-10-18).** Stage 1 delivered the pipeline (merged, PR #4, merge commit 5dcad32). Stage 2 added the **minimal real Godot 4.7.2 project at the repository root** (placeholder art only, clearly labelled), the Codex sprite drop-in contract and the first deployment (PR #6, merge commit d651078). The project owner reassigned that bootstrap to Kiro on 2026-10-17. The orchestrator set DONE only after it had checked the live build itself; the evidence is in [order_01.md](../../orders/Kiro/order_01.md) and the [chief report](../../orders/Kiro/reports/2026-10-18-kiro-chief-report.md).
- **A Godot project now exists** (`project.godot`, `export_presets.cfg`, `scenes/`, `scripts/`, `tests/` at the repository root). All Godot jobs therefore run for real. Read a green check as exactly what the gate says and no more: **a green check on a pull request means "imported, validated, tested, exported and started in headless Chromium". It does not mean the game is deployed.** Pull requests never deploy.
- **Live deployment: VERIFIED.** Every push to `main` builds, smoke-tests, deploys and smoke-tests the live URL; pull requests never deploy. The first deployment was [Godot CI run 39138070349](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39138070349) (commit d651078); the latest verified at the time of writing is [run 39158946428](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39158946428) (commit 068047e). GitHub Pages was **enabled on 2026-10-18 by the project's orchestrator with the project owner's explicit authorization** (Actions source; not by a pull request and not by CI): `build_type=workflow`, and the `github-pages` environment has a main-only deployment branch policy (details and re-check commands: [Admin-only steps](#admin-only-steps)).
- **Live URL (verified):** `https://kiotdstudios.github.io/shinobi-rush/`. The authoritative URL is the `page_url` output of the deploy step, recorded in `deploy-info.json`. The served `build-info.json` field `commit_sha` shows which commit is live.
- **What has been run (all verified).** Locally on Windows against the real project (Godot 4.7.2, real Chromium): unit tests, validators, import, resource validation, the project's own tests, export, export checks, the browser smoke test and the controls probe. On GitHub Actions: the Godot jobs on every pull request, the first deployment and every later redeploy on `main`, and the post-deploy smoke test against the live URL. **Not verified:** controller hardware, DualSense in browsers, Safari/mobile, real art and frame rate on a real GPU.
- **The pipeline self-test builds throwaway projects, never the game.** They are generated at run time in a temporary folder, are never committed or deployed, and every file says "PIPELINE SELF-TEST - NOT THE GAME".
- What the project has to provide, the repository-root convention and the `.gdignore` list: [GODOT_PROJECT_HANDOFF.md](GODOT_PROJECT_HANDOFF.md).
## What exists

| Path | Purpose |
| --- | --- |
| `.github/workflows/repository-checks.yml` | Required check `validate-orders-and-project` (orders, instructions, project discovery). Unchanged semantics. |
| `.github/workflows/godot-ci.yml` | Godot pipeline: detect, build, pre-deploy smoke, deploy (main only), post-deploy smoke, `godot-ci-gate`. |
| `.github/workflows/full-regression.yml` | The FULL browser regression (smoke + the whole controls probe + the debug-log probe, in parallel jobs on one export of one commit) and its `Full regression result` gate. Nightly, on demand, on `release-*` tags and on PRs that touch it or `scripts/ci/smoke/`. Never deploys; read-only token. |
| `.github/workflows/pipeline-self-test.yml` | Tooling verification (lint, unit tests, positive and negative end-to-end cases). Never deploys. |
| `scripts/ci/godot-version.env` | The single pin file (Godot, Node, Playwright, actionlint, runner image). |
| `scripts/ci/*.py` | Python standard-library tooling used by the workflows and by local runs. Unit tests: `scripts/ci/tests/`. |
| `scripts/ci/godot_walker.py` | Holds the GDScript text of the headless resource walker (loads every script, scene and resource in the project). `godot_ci.py` writes it to a temporary folder outside the project each time, so no `.gd` file is committed. |
| `scripts/ci/smoke/` | Node + Playwright browser smoke test (`smoke.mjs`), the controls probe (`controls-probe.mjs`) and the debug-log probe (`debug-probe.mjs`), pinned with a lockfile. |
| `scripts/ci/validate_sprite_manifests.py` | Sprite manifest validator (stdlib Python); unit tests in `scripts/ci/test_validate_sprite_manifests.py`. |
| `project.godot`, `export_presets.cfg`, `scenes/`, `scripts/` (game code), `tests/` | The Godot project at the repository root (stage 2). `tests/run_tests.gd` is the dependency-free test runner. |
| `.gdignore` files | Empty marker files that hide non-game folders from Godot (list and rules: [below](#gdignore-files-and-the-one-assets-exception)). |

## Job graph (godot-ci.yml)

```text
pull_request | push to main | workflow_dispatch
        |
     detect  (also validates sprite manifests: validate_sprite_manifests.py)
        | no project.godot (fork / future state) -> godot-ci-gate: NOT VALIDATED, NOT DEPLOYED (green, loud annotation)
        | project found (the normal case now)
      build  install pinned Godot + templates (cached, SHA512-verified)
             -> headless import
             -> validate project settings and Web export preset
             -> validate every script and scene loads
             -> run tests: res://tests/run_tests.gd, or GUT / gdUnit4 (warning if none exists)
             -> export Web (debug template, single-threaded, Compatibility) + build-info.json
             -> finalize-export (build-info.json written; the file and PCK checks run in smoke-predeploy and deploy)
        |
  smoke-predeploy   real Chromium against a local static server (no COOP/COEP, like Pages); runs on PRs too
                    -> check-export (files vs build-info.json; sprite manifests and PNG imports inside index.pck)
                    -> smoke.mjs (engine start, canvas, ready hook, input effect, bounded player-movement assertion, console)
                    (the comprehensive controls and debug probes are NOT here; see "Two tiers" below)
        |
     deploy         ONLY push to main / dispatch from main; Pages preflight, configure, upload, deploy
        |
  smoke-postdeploy  real Chromium against the real URL; waits until build-info.json shows THIS commit
        |
  godot-ci-gate     always runs; the single status to require once a project exists
```

Nothing is published from pull requests. The `deploy` job has `pages: write` and `id-token: write`; no other job has any write permission.

## Two tiers: fast deploy and full regression

Routine pushes take the FAST path above: build and tests, one pre-deploy browser smoke (`smoke.mjs`: engine start, canvas, ready hook, input effect and a bounded `player-moves` assertion that real key input changes `window.__SHINOBI_STATE__.x`), deploy of the exact smoke-tested bytes, and the live post-deploy smoke with SHA match. Job names, the `deploy` contract and `godot-ci-gate` semantics are unchanged, so required checks do not change.

The comprehensive probes were removed from that critical path only, not from the repository. They run in `full-regression.yml`:

| Trigger | What it tests |
| --- | --- |
| Nightly, 07:00 UTC (03:00 Eastern daylight / 02:00 Eastern standard) | tip of the default branch |
| Manual: Actions > Full browser regression > Run workflow, pick the branch or tag | the tip of that ref (to test one exact commit, push a tag such as `release-candidate-2026-10-27` on it and run on the tag) |
| Push of a tag named `release-*` | exactly the tagged commit: this is the major-release gate |
| Pull request touching `full-regression.yml` or `scripts/ci/smoke/**` | that PR head, so the suite is validated before it changes |

Each run builds its own export from the commit it runs on, checks `build-info.json` against that SHA, and runs `smoke`, `controls-probe` and `debug-probe` as parallel jobs on those same bytes. `Full regression result` fails if any job failed, was cancelled or was skipped. Evidence (screenshots, JSON, logs) is uploaded per job as `full-regression-*-evidence` for 30 days, and a failing nightly shows as a red run on the Actions tab (and GitHub's failed-workflow notification). It requests no write permission, so it cannot open issues; watch the Actions tab.

**Trade-off.** A fast deployment no longer guarantees that the full camera, vision and debug suite passed for that exact push. The last nightly tells you whether the suite was green on the previous night's tip.

### Release procedure

1. Choose the commit to release. Tag it: `git tag release-YYYY-MM-DD <sha> && git push origin release-YYYY-MM-DD`.
2. Wait for the `Full browser regression` run on that tag. Release only if `Full regression result` is green; its summary names the SHA.
3. Never release on a red or missing full-regression run for the release commit.

## Gates

| Gate | Fails when | Evidence |
| --- | --- | --- |
| Pins and workflow hygiene (`check_workflows.py`) | a pin is malformed, an action is not SHA-pinned, a runner is `*-latest`, a write permission leaks, docs show a stale pin | job log annotations |
| Project discovery | several projects without `GODOT_PROJECT_DIR`, or an invalid override | `detect` job summary |
| Headless import | Godot exits non-zero, times out, or prints `ERROR:` / `SCRIPT ERROR:` (Godot exits 0 on a script parse error, so the log is scanned) | `logs/import.log` |
| Project and preset validation | any rule in the table of [GODOT_PROJECT_HANDOFF.md](GODOT_PROJECT_HANDOFF.md) reports an error | `project-validation.json` |
| Script and scene validation | a `.gd` file cannot compile, a scene cannot load, a dependency is missing (orphan scripts included) | `logs/validate-resources.log` |
| Sprite manifests (`detect` job) | a `*.manifest.json` under `assets/characters/` breaks the schema (`::error file=<path>::` annotations); with no manifest it passes ("nothing to validate") | `detect` job log |
| Tests | `res://tests/run_tests.gd` (or GUT / gdUnit4) reports a failure or exits non-zero (absence of any framework only warns) | `logs/tests-*.log` |
| Web export | export fails, prints engine errors, produces a threaded build, or files do not match `build-info.json` | `logs/export.log`, `build-info.json` |
| Export contents (`check-export`, error `EXPORT011`; the workflows pass no `--project`, so the project is the repository root, and a non-root `GODOT_PROJECT_DIR` would need `--project` or the check would find no `assets/` and assert 0) | `index.pck` lacks `project.binary`, or lacks a sprite manifest or sprite PNG import record that exists in the repository (the check always prints what it asserted, including "0 manifests" while no art exists). Runs in `smoke-predeploy` and again on the staged site in `deploy` | job logs |
| Pre-deploy smoke test | engine does not start, canvas missing or blank, fatal console / page / network error, wrong commit, ready hook never true, no visible effect of input | `smoke-predeploy/` |
| Controls probe | the hooks `window.__SHINOBI_READY__` / `window.__SHINOBI_STATE__` exist but holding D does not move the player, Shift+D is not faster, the player walks through a wall, or the console shows errors. If neither hook is ever defined it prints "SKIPPED - hooks absent" and exits 0 (1 on console errors) | `controls-probe/` in the pre-deploy smoke artifact |
| Deploy preflight | Pages not enabled for Actions, branch-based Pages, custom domain without opt-in | `deploy` job summary |
| Post-deploy smoke test | the live URL never serves this commit's `build-info.json`, served bytes differ, or the browser checks fail | `smoke-postdeploy/` (includes `deploy-info.json`) |

The Web export uses the **debug** export template on purpose: release templates silently swallow GDScript runtime errors (verified on Godot 4.7.2), which would blind the browser smoke test. The live build is a test build, not a production release.

## Project discovery

`scripts/ci/discover_project.py` searches the repository at run time for `project.godot`, ignoring `.git`, `.godot`, `node_modules` and `.import`. Projects nested inside another project are ignored. The convention of this repository is a project **at the repository root** (section 11 of the locked prototype brief [PLAYER_CHARACTER_CODEX_HANDOFF.md](../prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md)), so discovery reports `project_dir=.` and the jobs run `godot --headless --path <repository root>`; details and the `.gdignore` list are in [GODOT_PROJECT_HANDOFF.md](GODOT_PROJECT_HANDOFF.md#where-the-project-lives). Exactly one project is required; several fail the check unless the repository variable `GODOT_PROJECT_DIR` (a relative POSIX path; `.` is the repository root) names the one to build. Nothing in the pipeline hard-codes a project path. Generated output never goes into the project tree: the Web export is written to `$RUNNER_TEMP/web-export`, evidence to `$RUNNER_TEMP/evidence`, and `godot_ci.py export` refuses an output directory inside the project.

## Pins and how to bump them

All tool versions live in `scripts/ci/godot-version.env`. Workflows and local scripts read it through `scripts/ci/pins.py`; `check_workflows.py` fails the build if the Playwright pin differs from `package.json` or `package-lock.json`, if any workflow uses a runner other than the pinned image, if an action is not pinned to a full commit SHA, or if the values below go stale.

| Pin | Value |
| --- | --- |
| `GODOT_VERSION` | <!--pin:GODOT_VERSION-->`4.7.2`<!--/pin--> |
| `GODOT_TAG` | <!--pin:GODOT_TAG-->`4.7.2-stable`<!--/pin--> |
| `GODOT_TEMPLATES_VERSION` | <!--pin:GODOT_TEMPLATES_VERSION-->`4.7.2.stable`<!--/pin--> |
| `NODE_VERSION` | <!--pin:NODE_VERSION-->`24.22.0`<!--/pin--> |
| `PLAYWRIGHT_VERSION` | <!--pin:PLAYWRIGHT_VERSION-->`1.64.1`<!--/pin--> |
| `ACTIONLINT_VERSION` | <!--pin:ACTIONLINT_VERSION-->`1.7.12`<!--/pin--> |
| `RUNNER_IMAGE` | <!--pin:RUNNER_IMAGE-->`ubuntu-24.04`<!--/pin--> |

The editor zips and the export templates are pinned together by SHA512 and are always taken from the same Godot release tag. The installer refuses a download whose SHA512 differs from the pin and verifies `godot --version` after installing.

### Bumping Godot

1. Pick a stable release (never a beta or release candidate): `gh api repos/godotengine/godot-builds/releases --jq '.[] | select(.prerelease==false) | .tag_name'`.
2. Download its checksums: `gh release download <version>-stable --repo godotengine/godot-builds --pattern SHA512-SUMS.txt`.
3. `python scripts/ci/pins.py bump-godot --version <version> --sums-file SHA512-SUMS.txt` rewrites the version and the three SHA512 values.
4. `python scripts/ci/check_workflows.py --write` refreshes the pin values shown in the docs.
5. Run the self-test locally (see below), open a PR, and confirm `Pipeline self-test` is green. A project saved with a newer Godot than the pin is rejected (`PRJ008`), so bump the pin before anyone upgrades the editor used for the project.

### Bumping Playwright, Node, actionlint or an action

- Playwright: `npm install --save-exact --ignore-scripts --prefix scripts/ci/smoke playwright@<x.y.z>`, then set `PLAYWRIGHT_VERSION` to the same value. The Chromium build follows from the Playwright version.
- Node: set `NODE_VERSION` to a version listed in <https://github.com/actions/node-versions> (`versions-manifest.json`).
- actionlint: set `ACTIONLINT_VERSION` and the two checksums from the `actionlint_<version>_checksums.txt` release asset.
- A GitHub Action: resolve the tag to a commit and confirm it belongs to the action's default branch: `gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq .object.sha` (dereference annotated tags with `git/tags/<sha>`), then `gh api repos/<owner>/<repo>/compare/main...<sha> --jq .status` must say `behind` or `identical`. Update every `uses:` line and its `# vX.Y.Z` comment.

## Caching

| Cache | Key | Contents | Notes |
| --- | --- | --- | --- |
| Godot install | `godot-<os>-<version>-e<editor sha12>-t<templates sha12>-v<layout>` (self-test adds `-threaded-templates`) | editor, `_sc_`, nothreads debug template, manifest | Re-verified by sha256 on every restore; a mismatch triggers a clean reinstall. |
| Playwright browsers | `playwright-<os>-<version>-headless-shell-v1` | Chromium headless shell | `npx playwright install` still runs (cheap when cached) to install OS packages. |
| npm | managed by `actions/setup-node` from `package-lock.json` | `~/.npm` | |

Not cached on purpose: the project's own import cache `.godot/`. With the project at the repository root it sits in the workspace root next to `docs/`, `orders/` and `scripts/`; it is git-ignored, never uploaded as an artifact and rebuilt by every `import` step, so there is no cache key to maintain. The Godot install cache above lives in `~/.cache/shinobi-rush/godot`, outside the workspace.

Caches created in a pull request are only visible to that PR; the first run after a merge to `main` may download the 1.28 GB templates archive again. Clear a suspicious cache with `gh cache delete <key>`.

## Evidence

| Where | What |
| --- | --- |
| Job summary (`$GITHUB_STEP_SUMMARY`) | per-step tables; the `godot-ci-gate` summary states NOT VALIDATED / NOT DEPLOYED / VALIDATED and DEPLOYED explicitly |
| Artifact `godot-ci-build-evidence` | Godot logs, `project-validation.json` |
| Artifact `web-export` | the exact bytes that are smoke-tested and deployed, with `build-info.json` (commit, run, engine, per-file sha256) |
| Artifacts `godot-ci-predeploy-smoke-evidence`, `godot-ci-postdeploy-smoke-evidence` | `smoke-result.json`, `console-log.json`, `network-summary.json`, screenshots, `build-info.json`, `summary.md`; the post-deploy artifact also holds `deploy-info.json` (page URL, expected and live SHA, polling attempts) |
| Artifact `selftest-evidence` | per-case logs and screenshots of the throwaway projects, `selftest-results.json` |

Evidence artifacts are kept 14 days; `web-export` 7 days.

## Local reproduction on Windows

Prerequisites: Python 3.10+, Node.js 22+ (CI uses the pinned version), Git. No Godot installation is needed.

```powershell
cd C:\path\to\shinobi-rush
# 1. unit tests
python -m unittest discover -s scripts/ci/tests -v
cd scripts\ci\smoke; npm ci --ignore-scripts; node --test; cd ..\..\..
# 2. install the pinned Godot + templates into a private folder (about 1.4 GB the first time; SHA512-verified)
python scripts/ci/install_godot.py install --platform windows --dest "$env:LOCALAPPDATA\shinobi-rush-ci\godot" --with-threaded-templates
# 3. install the browser used by the smoke test
cd scripts\ci\smoke; npx playwright install --only-shell chromium; cd ..\..\..
# 4. pipeline self-test with throwaway projects, all 16 cases (about 2 to 3 minutes)
python scripts/ci/selftest.py --godot-dir "$env:LOCALAPPDATA\shinobi-rush-ci\godot" --work-dir "$env:TEMP\shinobi-selftest" --evidence-dir "$env:TEMP\shinobi-selftest-evidence"
# 5. the real project (it is the repository root, so <project> is "."; run from the repository root):
$env:GODOT_BIN = (python scripts/ci/install_godot.py print-bin --platform windows --dest "$env:LOCALAPPDATA\shinobi-rush-ci\godot")
python scripts/ci/godot_ci.py import --project <project>
python scripts/ci/validate_godot_project.py --project <project>
python scripts/ci/godot_ci.py validate-resources --project <project>
python scripts/ci/godot_ci.py tests --project <project>
python scripts/ci/godot_ci.py export --project <project> --out "$env:TEMP\web-export"
python scripts/ci/godot_ci.py finalize-export --project <project> --out "$env:TEMP\web-export" --kind game
python scripts/ci/godot_ci.py check-export --dir "$env:TEMP\web-export" --kind game --project <project>
python scripts/ci/validate_sprite_manifests.py
cd scripts\ci\smoke; node smoke.mjs --serve-dir "$env:TEMP\web-export" --out-dir "$env:TEMP\smoke-evidence" --expected-sha (git rev-parse HEAD)
node controls-probe.mjs --serve-dir "$env:TEMP\web-export" --out-dir "$env:TEMP\controls-evidence"; cd ..\..\..
```

`godot_ci.py tests` runs `godot --headless --path . --script res://tests/run_tests.gd` (the project's own runner; the same command works by hand and prints `SUMMARY: N passed, M failed`). The exact CI step lines (including `--expect-sha`) are in `.github/workflows/godot-ci.yml`. The import step creates `.godot/`, `*.uid` and `*.import` files in the project folder, exactly like opening the editor. Commit the `.uid` and `.import` files; never commit `.godot/`. To play an export by hand, serve the folder with `node scripts/ci/smoke/lib/serve.mjs "$env:TEMP\web-export" 8080` and open `http://127.0.0.1:8080/` (not `file://`).

## Pipeline self-test

`pipeline-self-test.yml` runs on pull requests and pushes that touch the pipeline files, and on demand. It is path-filtered, so it must never be a required check (see below). It proves, with generated throwaway projects:

| Case | Expected result |
| --- | --- |
| `good` | static validation, import, resource validation, export, build-info, browser smoke (strict: ready hook and input effect required) all pass; the tests step warns loudly that no framework exists; a `selftest` export is refused where a `game` export is required |
| `forward_plus_base` | a project whose desktop renderer is Forward+ passes everything (validator warning `PRJ005` only) and the browser reports the Compatibility renderer: the desktop renderer is not CI's decision |
| `repo_shaped_layout` | the repository-root layout of the prototype brief, generated at run time in a temporary folder: `project.godot` at the root of a checkout, next to `docs`, `orders`, `skills`, `world`, `scripts/ci` and `assets/characters/player/references` (each with images or scripts behind an empty `.gdignore`), game code in `scripts/player/`, game art in `assets/characters/player/placeholder/` and a control image in a folder that is NOT ignored. Expected: static validation reports no `PRJ012`/`PRJ013`; Godot's import converts the game art and the control image and none of the ignored images; the resource walker loads exactly the 3 game scripts and the scene and skips the ignored, dot, `node_modules`, `exports` and `scripts/ci` folders (invalid decoy scripts there are never loaded); the exported pack contains the game code, the game art and the control image and none of the ignored images or decoys; the browser smoke test (strict) passes; and the walker still skips `scripts/ci` after its `.gdignore` is deleted |
| `gdignore_scripts` | `scripts/.gdignore` next to game code fails static validation with `PRJ013` |
| `selftest_fixture_refused` | a generated fixture validated without the self-test's allow flag fails with `PRJ014` (it can never pass as the game) |
| `threads_enabled` | static validation fails with `EXP005` |
| `threads_enabled_export` | the threaded export is refused by `finalize-export`, and the browser fails at engine start with the missing Cross-Origin Isolation notice (no COOP/COEP, like Pages) |
| `missing_main_scene`, `no_main_scene` | static validation fails with `PRJ004` / `PRJ003` |
| `web_renderer_override` | `rendering_method.web` other than Compatibility fails static validation with `PRJ006` |
| `parse_error` | import passes (Godot cannot see an orphan script) but resource validation fails and names `broken.gd` |
| `parse_error_referenced` | import fails on `Parse Error` although Godot exits 0 |
| `startup_script_error`, `startup_error`, `page_error` | browser smoke fails at `no-fatal-console` and the recorded first fatal event names the injected fault (`Nonexistent function 'selftest_nonexistent_method'`, `SELFTEST_INTENTIONAL_STARTUP_ERROR`, `[pageerror] SELFTEST_PAGE_ERROR`), while `engine-start` and `canvas-visible` still pass |
| `blank_canvas` | browser smoke fails at `canvas-not-blank` (the recorded detail says the canvas looks uniform), while `engine-start`, `canvas-visible` and `no-fatal-console` still pass |

A negative case that fails for the wrong reason counts as a failure (the exit code must be exactly 1 and the named rule or check must appear; exit code 2 is an infrastructure error, not an expected failure; a browser negative additionally needs the injected fault in the failed check's recorded detail and its unrelated checks must still pass). The run must execute all 16 cases and record exactly the expected number of expectations per case (`EXPECTED_COUNTS` in `selftest.py`), otherwise it fails with `harness / completeness`; `--cases` produces a labelled PARTIAL run and `check_workflows.py` (`WF016`) forbids it in workflows. The work directory must be new, empty or created by an earlier self-test run (marker file `.shinobi-ci-owned`); anything else is refused, never deleted.

## `.gdignore` files, and the one `assets/` exception

The project is the repository root, so Godot would otherwise import-scan and export the images of non-game folders. Empty marker files (committed in stage 2) hide them: `docs/.gdignore`, `orders/.gdignore`, `world/.gdignore`, `skills/.gdignore`, `scripts/ci/.gdignore`, `exports/.gdignore` (hand-made editor exports; the folder itself is git-ignored apart from the marker) and `assets/characters/player/references/.gdignore`. CI exports to `$RUNNER_TEMP`, never into the project. `PRJ012` (the missing-marker check) is an **error** for `assets/characters/player/references` (the approved turnaround would otherwise be imported and packed into the game) and a warning for the other folders; `PRJ013` rejects a `.gdignore` anywhere that hides game files (never in `scripts/` itself or `assets/` as a whole).

**The only touch under `assets/`:** the empty file `assets/characters/player/references/.gdignore`. It is required (see above), harmless and not an asset. Stage 2 adds no other file under `assets/` and modifies no art (Codex owns the art).

## Test runner, manifest validator and controls probe

- **Test runner.** `tests/run_tests.gd` is a dependency-free SceneTree script. `godot_ci.py tests` detects it before GUT and gdUnit4 and runs `godot --headless --path . --script res://tests/run_tests.gd`; a non-zero exit fails the `build` job. The suite prints one `PASS`/`FAIL` line per check and `SUMMARY: N passed, M failed`. It writes parser fixtures only to `user://` and does not depend on committed sprites. Run it by hand after `godot --headless --path . --import` ([TESTING.md](../prototype/TESTING.md)). The deliberate negative test of a bad sprite sheet logs one non-failing `WARNING`.
- **Sprite manifest validator.** `python scripts/ci/validate_sprite_manifests.py` checks every `*.manifest.json` under `assets/characters/` against schema v1 ([SPRITE_DROP_IN.md](../prototype/SPRITE_DROP_IN.md)). It runs in the `detect` job (no `working-directory`) and in the tooling tests, prints `::error file=<path>::<message>` annotations for Codex, and resolves the repository root from its own location, so a wrong current directory cannot turn it into a silent pass (`--repo-root` overrides). With no manifests it exits 0 ("nothing to validate"). **Production frames are 128x128 RGBA (locked)**: a production manifest with a base `frame_size` other than [128, 128], a per-animation canvas under 128 in either dimension, or a `foot_anchor` outside its frame is an error; `body_height_px` outside 100-112 is a warning. Manifests under `references/`, `previews/`, `source/` or `study/` (legacy 64x64 reference art) are checked for JSON/schema only and are excluded from the export.
- **Controls probe.** `scripts/ci/smoke/controls-probe.mjs` runs after `smoke.mjs` in `smoke-predeploy` against the same local export. It reads `window.__SHINOBI_READY__` and `window.__SHINOBI_STATE__`, holds `KeyD` (about 600 ms; x must grow), holds `Shift+KeyD` (must be faster, `sprinting=true`) and walks into a wall (position must stop changing). It fails with an explicit "hooks exist but input had no effect" message, and prints "SKIPPED - hooks absent" if neither hook is ever defined. Evidence goes to `controls-probe/` in the pre-deploy smoke artifact.

## Performance budget for a full 128x128 set (measured 2026-10-18)

Synthetic `__verify__` set at Codex's frame targets, built in a throwaway copy of the repo and never committed: 8 directions, idle 12, walk 12, run 16, sprint 20, dodge 12, jump 16, light attack 12, heavy attack 18, hit 10 frames = 1024 frames, all 128x128 RGBA (64 MiB raw), one sheet per animation. Godot 4.7.2 Web DEBUG export (single thread), loaded lazily one animation at a time through `SpriteSet.get_frames`, real Chromium 156 (Playwright 1.64.1) on Windows with SwiftShader software GL. MiB = 2^20 bytes.

- **PCK:** 8.37 MiB (lossless import, stylized flat art); 49.4 MiB for full-frame random noise (worst case: PNG-like data does not compress, so wire size is about the PCK size even with Pages gzip). 1024 loose PNGs instead of 9 sheets: 10.1 MiB. Lossy WebP import: 0.98 MiB (quality not assessed).
- **Per-animation load (`get_frames`, sheets):** 30 to 88 ms (idle 51, walk 40, run 62, sprint 88, dodge 48, jump 54, light 43, heavy 64, hit 30; 479 ms for all nine). Loose frames: 126 to 222 ms each, 1530 ms total (3x slower). First draw of the first animation added 162 ms of one-time GL warm-up.
- **`RENDER_TEXTURE_MEM_USED`:** 7.1 MiB before loading, then after idle, walk, run, sprint, dodge, jump, light, heavy, hit: 15.1, 23.1, 33.7, 47.1, 55.1, 65.7, 73.7, 85.7, 92.4 MiB. A second pass over every animation and direction adds nothing (92.4 MiB). That is 1.33x the raw RGBA size (6.7 to 13.3 MiB per animation), for sheets and for loose frames alike.
- **Phones (inference, not measured on a phone):** about 85 MiB of GPU texture for ONE character is too much once enemies, effects and the arena are added, and `SpriteSet` caches every animation it has built for the life of the set (no eviction). The timings above are desktop-CPU software GL; expect phones to be slower. The 20-frame sprint sheet is 2560 px wide: Chromium here reports `MAX_TEXTURE_SIZE` 8192, but WebGL2 only guarantees 2048, so check real devices.
- **Frame rate is deliberately not reported:** SwiftShader renders on the CPU, so FPS there says nothing about a phone GPU.
- **Recommendation, lazy loading:** keep per-animation loading; preload the hot set (idle, walk, run is about 27 MiB on top of the 7.1 MiB baseline) behind the loading screen and prefetch attack, dodge and hit before they are needed, because the first use costs a hitch. Add eviction for animations not used for a while before enemies share this pipeline.
- **Recommendation, sheet packing:** one sheet per animation, rows = directions (the manifest `sheet` form), never one PNG per frame. Keep sheets under 4096 px wide.
- **Recommendation, import compression for Web:** lossless (today's default) is the safe baseline. VRAM-compressed import (`compress/mode=2`) cut texture memory 4x on the same set (7.1 to 28.4 MiB, +21.3 instead of +85.3) and `get_frames` to 37 ms for all nine, but the PCK then carries both desktop (S3TC/BPTC) and mobile (ETC2/ASTC) copies (32.1 MiB raw, 6.2 MiB gzip) unless one family is disabled in the preset. Block compression on pixel-art edges and alpha was NOT visually assessed: have Codex judge it on real art before adopting it.
- **Reproduce:** copy the repo without `.git`, `exports` and `.godot`; generate the set under `assets/characters/__verify__/` (manifest id `__verify__`, `frame_size` [128, 128], `foot_anchor` [64, 116], sheets named by animation); set a temporary main scene whose script calls `SpriteSet.parse` and `get_frames` per animation, waits two frames, and reads `Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)`, then publishes JSON to `window.__PERF__` through `JavaScriptBridge.eval`; run `godot --headless --path <copy> --import`, `python scripts/ci/godot_ci.py export --project <copy> --out <dir>`, then serve `<dir>` with `scripts/ci/smoke/lib/serve.mjs` and read `window.__PERF__` in Playwright Chromium. For the VRAM run set `compress/mode=2` in the generated `.png.import` files (plus `rendering/textures/vram_compression/import_etc2_astc=true` and `for_mobile=true` for ETC2/ASTC) and re-import. Delete the copy afterwards.

## What a failing job means

| Job / step | A failure means | First thing to look at |
| --- | --- | --- |
| `detect` / sprite manifests | A manifest has a schema, size, path or anchor error. Nothing about the engine. | the `::error file=` annotation |
| `build` / import, validate, resources | The project does not compile or load: script parse error, missing scene or dependency, invalid preset, a `.gdignore` that hides game code. | `logs/*.log`, `project-validation.json` |
| `build` / tests | A check of `tests/run_tests.gd` failed (a game-logic regression). | `logs/tests-*.log`, the `FAIL` lines |
| `build` / export | The Web export failed or is not single-threaded Compatibility. | `logs/export.log` |
| `smoke-predeploy` / `smoke.mjs` | The exported game does not start in a browser, is blank, throws a console error, or the input has no visible effect. | `smoke-result.json`, screenshots |
| `smoke-predeploy` / controls probe | The game starts but walk, sprint or wall collision regressed. | `controls-probe/` |
| `godot-ci-gate` | At least one upstream job failed or was cancelled. This is the one status to require. | the gate summary |
| `deploy` (main only) | The preflight found Pages not enabled for Actions, or the staged site is not the smoke-tested game build. Nothing was published. | `deploy` summary |
| `smoke-postdeploy` | Pages never served this commit's `build-info.json`, or the live build fails the browser checks. **The broken build may already be live**: roll back (below). | `smoke-postdeploy/deploy-info.json` |

Never relax a gate to turn a job green. A red `smoke-predeploy` blocks deployment because `deploy` needs it.

## First deployment

What happens after a merge to `main` (observed on the first deployment, [run 39138070349](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39138070349), 2026-10-18):

1. The push to `main` starts `Godot CI`. `build` and `smoke-predeploy` repeat on the merge commit, so a cold cache (templates download, about 1.28 GB) can make this the slowest run.
2. `deploy` runs the Pages preflight, stages the site, repeats the export check on it, uploads the artifact and deploys. The environment `github-pages` already exists and allows only `main`.
3. `smoke-postdeploy` polls `build-info.json` on the live URL until it shows this commit (CDN propagation can take a short while), then runs the browser checks. `deploy-info.json` records the real `page_url`.
4. The site `https://kiotdstudios.github.io/shinobi-rush/` changes from HTTP 404 to the game. The build is a debug-template test build with **placeholder art**.
5. The orchestrator verifies the live build and only then sets the order to DONE. A green run alone is not that verification.

Possible first-run defects are listed in [First run on a real project](#first-run-on-a-real-project). Fix them with a normal pull request; do not edit settings by hand to make a run pass.

## Manual rollback

`deploy` only runs for a push to `main` or a `workflow_dispatch` started on `main` (`github.ref == refs/heads/main`), and it builds the commit the run was started on. A `workflow_dispatch` therefore always rebuilds the **current head of `main`**; it cannot deploy an older commit by itself. Options, best first:

1. **Revert and redeploy.** Open a pull request that reverts the bad commit (`git revert <bad-sha>`), let the checks pass, merge. The push to `main` rebuilds, re-tests and deploys the last good code. This is the supported path (pull requests and the ruleset stay in force).
2. **Re-run the last good run.** In Actions, open the last successful push run of `Godot CI` on `main` and use "Re-run all jobs" (or `gh run rerun <run-id> -R kiotdstudios/shinobi-rush`). A re-run uses the original commit, so it rebuilds and redeploys that commit. Not yet exercised on this repository: verify the live commit with `build-info.json` afterwards.
3. **Manual dispatch** (`gh workflow run godot-ci.yml --ref main -R kiotdstudios/shinobi-rush`) is for re-publishing the current `main` after a transient failure (for example a Pages outage), not for going back.

After any rollback, check `https://kiotdstudios.github.io/shinobi-rush/build-info.json` (field `commit_sha`) to confirm which commit is live. Never force-push `main`.

## Admin-only steps

These need repository administrator rights. Neither Order 01's pull requests nor any workflow performs them; steps 1 and 2 were done once, by hand, as described below.

1. **Enable GitHub Pages with the GitHub Actions source** (required before the first deploy). **DONE on 2026-10-18** by the project's orchestrator with the project owner's explicit authorization (not by Order 01's pull request and not by CI). Settings > Pages > Build and deployment > Source: **GitHub Actions**. CLI equivalent, kept here as the reproducible / disaster-recovery instruction (forks, re-enabling): `gh api -X POST repos/kiotdstudios/shinobi-rush/pages -f build_type=workflow`. Verified state after the change (read-only `gh api repos/kiotdstudios/shinobi-rush/pages`): `build_type=workflow`, `html_url=https://kiotdstudios.github.io/shinobi-rush/`, `public=true`, `https_enforced=true`, `status=null` (nothing deployed yet) and the site answers HTTP 404 until the first deployment. Without Pages, the `deploy` job on `main` would fail with "GitHub Pages is NOT enabled" (the honest outcome, but a red `main`); the preflight message stays for forks.
2. **The `github-pages` environment: VERIFIED.** Enabling Pages created it (2026-10-18) with a main-only custom branch policy: `can_admins_bypass=true`, `deployment_branch_policy={protected_branches: false, custom_branch_policies: true}` and exactly one branch policy `{name: "main", type: "branch"}`, so only `main` may deploy. Re-check with `gh api repos/kiotdstudios/shinobi-rush/environments/github-pages` and `gh api repos/kiotdstudios/shinobi-rush/environments/github-pages/deployment-branch-policies`. Optionally add required reviewers (Settings > Environments > github-pages) if deployments should need approval.
3. **Optional repository variables** (Settings > Secrets and variables > Actions > Variables): `GODOT_PROJECT_DIR` only if the repository ever contains more than one Godot project; `PAGES_ALLOW_CUSTOM_DOMAIN=true` only if a custom domain on this Pages site is intended (the preflight refuses to deploy a test build over a custom-domain site by default).
4. **Require the Godot gate: DONE on 2026-10-18** by the orchestrator with the owner's explicit authorization, after the gate had passed on `main`. `godot-ci-gate` (source: GitHub Actions) was added to the ruleset **Agent Rules** (id 25328492) next to `validate-orders-and-project`; every other rule (pull request required, strict up-to-date mode, no force-push, no deletion, no bypass actors) is unchanged, which was verified by re-reading the ruleset. CLI equivalent: read the ruleset with `gh api repos/kiotdstudios/shinobi-rush/rulesets/25328492`, append `{"context": "godot-ci-gate", "integration_id": 15368}` to the `required_status_checks` rule and `PUT` it back with `gh api -X PUT ... --input payload.json` (write the JSON as UTF-8 **without** a byte-order mark, or the API answers HTTP 400). Consequence: a red Godot job now blocks merging, and every pull request, docs-only ones included, waits for the gate (about 10 minutes) because the workflow deliberately has no `paths:` filter.
5. **Do not require** `Pipeline self-test` or its jobs.
6. Optional hardening: Settings > Actions > General > "Require actions to be pinned to a full-length commit SHA" (all workflows here already comply), and a `.github/dependabot.yml` for the `github-actions` ecosystem (not added by Order 01 because it is outside the order's file scope).

### Why a workflow-level `paths:` filter must not be used on a required check

If a workflow is skipped because of path filtering, branch filtering or a commit message, the checks it would have produced stay **Pending**, and a pull request that requires them can never merge. A job skipped by a job-level `if:` reports success instead. That is why `repository-checks.yml` and `godot-ci.yml` have no `paths:` filter and decide inside the workflow (`detect` job and `if:` conditions), and why `godot-ci-gate` runs with `if: always()` and checks the upstream results explicitly: a required check on a downstream job would count as passed when the upstream job fails and the downstream one is skipped.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `NOT VALIDATED, NOT DEPLOYED` | No `project.godot` was found (a fork, or the project was moved or deleted). With the project at the repository root this should not happen: check `Godot CI / detect`. |
| `Multiple Godot projects` | Set the repository variable `GODOT_PROJECT_DIR`. |
| `SHA512 mismatch for ...` | The pin does not match the download. Re-run the bump procedure; never edit one hash alone. |
| Import log shows `SCRIPT ERROR: Parse Error` | A script does not compile. Open the project in the pinned editor. Godot exits 0 here; the pipeline fails on the log text. |
| `EXP005 ... thread_support` | Threads need COOP/COEP headers that GitHub Pages cannot send. Set Thread Support = Off in the Web preset. |
| Smoke test: `status notice shown: ... features required to run Godot projects on the Web are missing` | Threaded export, no WebGL2, or an insecure origin. The local server uses `127.0.0.1`, which is a secure context. |
| Smoke test exit code 3, `webgl2-available` fails | The runner's headless Chromium has no WebGL2. This is an environment problem, not a game defect. Try `SMOKE_CHROMIUM_ARGS="--use-angle=swiftshader"`, then `"--use-gl=angle --use-angle=swiftshader"` in the workflow `env`. |
| `no-fatal-console` fails on a harmless engine message | Godot `WARNING:` blocks never fail. Plain `console.error`, `ERROR:` and `SCRIPT ERROR:` do. Fix the cause; only as a last resort add a justified entry to `scripts/ci/smoke/console-allowlist.json` or `scripts/ci/godot-log-allowlist.txt` in a reviewed PR. |
| `GitHub Pages is NOT enabled` | Admin step 1. |
| `... is not empty and was not created by this tooling` | The self-test refuses to delete a directory it did not create. Point `--work-dir` at a new or empty folder. |
| `PRJ012 ... Add an empty .gdignore file to: ...` | The project is the repository root and a folder without game resources has no `.gdignore`, so Godot would import its images and export them. Create the empty file in each listed folder (`docs`, `orders`, `skills`, `world`, `scripts/ci`, `assets/characters/player/references`). Missing in `references` it is an error, elsewhere a warning. |
| `EXPORT011` | `index.pck` lacks `project.binary`, or a sprite manifest or sprite PNG `.import` record that exists in the repository. Check `export_presets.cfg` filters (manifests must be included; `source/` and `references/` are excluded on purpose). |
| `HOOKS EXIST BUT INPUT HAD NO EFFECT` (controls probe) | The game publishes `window.__SHINOBI_STATE__` but `x` did not change while `KeyD` was held. Check the InputMap actions and that the canvas has focus. |
| `PRJ013 .gdignore ... hides N game file(s)` | A `.gdignore` sits next to game code (typically `scripts/.gdignore`). Remove it; only `docs`, `orders`, `skills`, `world`, `scripts/ci` and `assets/characters/player/references` are ignored. |
| Required check stuck on Pending | A workflow-level `paths:` filter or a renamed job. Run `python scripts/ci/check_workflows.py`. |
| Cache never hits | PR caches are branch-scoped. Merge to `main` once; check the key in the log. |

## Security notes

- Workflows request `contents: read` at the top level. Only the `deploy` job gets `pages: write` and `id-token: write`. No workflow uses secrets; `check_workflows.py` rejects `secrets.*`, `pull_request_target`, `workflow_run`, untrusted expressions (PR titles, branch names) and unpinned actions.
- Every third-party action is pinned to a full commit SHA that was verified to belong to the action's default branch.
- The workflows never enable Pages and never create or edit environments, rulesets, variables, secrets or protection rules; the Pages and environment state described in the admin steps was set up by an administrator and stays under administrator control. `check_workflows.py` also rejects any workflow that mentions the self-test allow flag `SHINOBI_ALLOW_SELFTEST_PROJECT` (`WF019`): only `selftest.py` may set it, for its own child processes.
- Text from the project, Godot logs and the browser console is untrusted: it is sanitised before it reaches the workflow log so it cannot inject workflow commands, and the summary escapes Markdown.
- Downloads are SHA512-verified (Godot) or lockfile-verified (npm). Nothing is fetched with `curl | sh`.
- Pull requests from forks run the same checks with a read-only token and never deploy.

## First run on a real project

The stage 2 pull request was the first time the Godot jobs ran on a runner, and they passed on the first GitHub run. Keep this checklist for the next time a run goes red after a pin bump or a new Godot version. Look at these in order, and treat any failure there as a pipeline defect to fix in the same PR (not as a reason to disable a check):

1. `Godot CI / detect` summary: `project_found=true` and `project_dir=.` (the repository root); the sprite manifest step passes ("nothing to validate" while no art exists).
2. `build`: cold cache (the first run downloads the 1.28 GB templates archive and installs two files from it); the `Install pinned Godot` step downloads and installs (it prints `already installed and verified` on a cache hit and `existing install is not usable ... reinstalling` when a restored cache does not match the pinned manifest; it has no `SHA512 verified` line); `Load pinned tool versions` and `Prepare working directories` wrote the environment variables the later steps use (`GODOT_BIN`, `EVIDENCE_DIR`, `EXPORT_DIR`, `PROJECT_DIR`); the tests step prints `SUMMARY: 123 passed, 0 failed` (the count grows as tests are added).
3. `build` artifacts: `web-export` (with `build-info.json`) and `godot-ci-build-evidence` exist.
4. `smoke-predeploy`: `webgl2-available` passes (exit code 3 means the runner's headless Chromium has no WebGL2; see Troubleshooting); the controls probe prints a PASS verdict.
5. `godot-ci-gate` summary says `VALIDATED (not deployed: only main deploys)` on the PR.
6. After the stage 2 pull request is merged to `main` (Pages and the `github-pages` environment are already set up): `deploy` and `smoke-postdeploy` on `main`, then `deploy-info.json` in the post-deploy artifact ([First deployment](#first-deployment)).

Uploads use `overwrite: true`, so "Re-run all jobs" replaces an artifact of the same name instead of failing (from the action's documentation; not observed on this repository).
## Known limitations

- The deploy path (`configure-pages`, `upload-pages-artifact`, `deploy-pages`) and the post-deploy smoke test have never executed end to end (Pages itself is enabled). They are linted (actionlint), their decision logic is unit-tested, and `check_workflows.py` checks every script name and option used in a `run:` step (`WF017`). Their first real run is the push to `main` after the stage 2 merge.
- Gamepad input cannot be automated in the browser smoke test or the controls probe; keyboard only. Controller hardware, a DualSense in browsers, Safari and mobile browsers are **not verified**.
- The pixel check proves that the canvas is not uniform. It cannot prove that the picture is correct. All art is placeholder; no real sprite set exists yet.
- Frame pacing is not verified: the browser tests run under software GL (SwiftShader), where only 4 to 6 FPS were observed. 60 FPS on a real GPU has to be judged on the live build.
- The live build uses the debug template (slower than release). A separate release export is out of scope for Order 01.
- GUT is verified against Godot 4.7.2; the gdUnit4 command line is taken from its sources and is unverified against a real project (the project itself uses `tests/run_tests.gd`).