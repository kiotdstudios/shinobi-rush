# Job Report — Bootstrap Godot CI and Live Browser Deployment (stage 1 of 2)
- Agent: Kiro
- Order: [orders/Kiro/order_01.md](../order_01.md)
- Date: 2026-10-18
- Final status: IN_PROGRESS — Stage 1 of 2 delivered (CI/deploy pipeline). Stage 2 = minimal real Godot project at the repo root + first live deployment, separate PR. Tooling verified locally on Windows (the pipeline self-test also passed in CI on ubuntu-24.04 on the first run, with no workflow change needed: [run 39123715912](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39123715912), all 16 cases, 36/36 expectations; every check of PR #4 was green on commit 3355115); the `godot-ci.yml` jobs `build`, `smoke-predeploy`, `deploy` and `smoke-postdeploy` have never run on a runner or against a real project. **Live deployment: NOT PERFORMED (stage 2 (project bootstrap) not yet delivered).**
- Commit / PR: [PR #4](https://github.com/kiotdstudios/shinobi-rush/pull/4); commit A 77273bd (order + report); commit B 3355115 (pipeline); fix commits: none; the report-only follow-up commit is the one that contains this text (its SHA is in the PR)

## Work completed
- Investigation (re-verified on 2026-10-18 07:07 -04:00): no `project.godot`, `.tscn`, `.gd` or `export_presets.cfg` on any branch; `orders/Aki` and `orders/Orcha` hold no orders on `main` (open PR #2 proposes an Aki order and a second Kiro order, which this job does not touch); GitHub Pages is enabled (Actions source; baseline read-only `gh api` GETs: `build_type=workflow`, `status=null`, the site answers HTTP 404, one `github-pages` environment with a main-only deployment branch policy; unchanged when this job ended); ruleset `Agent Rules` requires `validate-orders-and-project` (strict, GitHub Actions) with no bypass actors; open PRs #1, #2 and #3 (#3 is a draft from Codex adding mobile animation previews under `assets/characters/player/previews/mobile/` and two Codex reports; it was opened after the preflight) were left untouched and their files are disjoint from this change set.
- Owner decision (2026-10-17): asked whether Kiro should build a minimal real Godot project and playable scene, the project owner answered "yes". The bootstrap is therefore explicitly reassigned to Kiro (`orders/README.md` rule 4) and delivered as **stage 2**, a separate follow-up pull request after this one is merged: a minimal real Godot 4.7.x project **at the repository root** (the locked architecture, section 11 of `docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md`) and the first live deployment. This pull request is **stage 1** and still commits no Godot project, scene, GDScript file or `.gdignore`.
- GitHub Pages: Pages enabled by the orchestrator with the owner's authorization on 2026-10-18 (not by this PR/CI); still NOT DEPLOYED (no project yet). This job only read the Pages and environment settings (`gh api` GETs) and found them unchanged from the state the orchestrator reported; it changed no repository or admin setting. The owner also authorized the orchestrator to merge this pull request once all checks are green (Kiro does not merge).
- Central decision for stage 1: no game project, scene or placeholder was created, committed or deployed. Instead:
  1. **Pipeline** (`godot-ci.yml`) that discovers a project at run time, and until one exists reports NOT VALIDATED / NOT DEPLOYED loudly (annotations, job summaries, `godot-ci-gate`), never deploying.
  2. **Pipeline self-test** (`pipeline-self-test.yml`, `scripts/ci/selftest.py`) that generates throwaway projects in a temp directory at run time and proves positive and negative behaviour (list in the evidence table below), including a project at the root of a checkout next to non-game folders full of images.
  3. **Handoff** for stage 2 and whoever builds on it (`docs/development/GODOT_PROJECT_HANDOFF.md`: repository-root convention, the `.gdignore` list stage 2 adds, checklist) and **admin steps** (`docs/development/GODOT_CI_AND_DEPLOYMENT.md`).
  4. **Honest bookkeeping**: order status IN_PROGRESS with the note "stage 1 of 2 delivered"; every acceptance box stays unticked and annotated "pending stage 2" (the documentation and report boxes say what stage 1 delivered); this report states "Live deployment: NOT PERFORMED".
- Repository-root readiness (project root == repository root): discovery reports `project_dir=.`; every Godot step runs with `--path` on the root; the Web export is written outside the project tree (`$RUNNER_TEMP/web-export`; `godot_ci.py export` refuses an output inside the project); the `.godot/` import cache is git-ignored and not cached; the headless resource walker honours `.gdignore`, skips dot folders, `node_modules`, `exports`, `build/web` and `scripts/ci`, and is written to a temporary folder at run time, so no `.gd` file and no `.gdignore` is committed; rule `PRJ012` lists the folders that need an empty `.gdignore` in stage 2 (`docs`, `orders`, `skills`, `world`, `scripts/ci`, `assets/characters/player/references`).
- `repository-checks.yml`: job `validate-orders-and-project` keeps its id and meaning; detection now uses `scripts/ci/discover_project.py` (override `GODOT_PROJECT_DIR`, error on several projects, ignores `.git`/`.godot`/`node_modules`), runner pinned to `ubuntu-24.04`, `actions/checkout` pinned by SHA.
- Pinned toolchain (single pin file `scripts/ci/godot-version.env`): Godot 4.7.2 (editor and templates by SHA512), Node 24.22.0, Playwright 1.64.1, actionlint 1.7.12, runner `ubuntu-24.04`, every GitHub Action by full commit SHA (see `.github/workflows/*.yml`; bump procedure in `docs/development/GODOT_CI_AND_DEPLOYMENT.md`).
- Hardening beyond the reference implementation: the self-test's browser negative cases assert that the failed check names the injected fault (not only that some check failed), lint rule `WF019` forbids workflows from mentioning the self-test allow flag, `godot-ci-logs/` is git-ignored, and the readiness-hook states (ready, absent, defined but never true) are unit-tested because the stage 2 game will use the hook.
- Key engine findings (verified, Godot 4.7.2): `--import` and `--export` exit 0 on GDScript parse errors (so logs are scanned); release templates swallow GDScript runtime errors (so the live-test build uses the debug template); a missing main scene exports without any error (so the static validator is the only guard); a Forward+ desktop renderer exports and runs in the browser as Compatibility (the Web platform forces it), so that is a warning, not a CI decision; a `.gdignore` on `scripts/` passes import and resource validation but silently drops the game code from the export (so `PRJ013` rejects it statically); with the project at the repository root Godot neither imports nor exports the images inside a folder that has an empty `.gdignore` (self-test case `repo_shaped_layout`).

## Files changed
Exact `git diff --stat` of the working tree before the first commit (taken with `git add -N` on the owned paths, then `git reset -q` so nothing was staged; 46 paths, 6649 insertions, 27 deletions):

```text
 .gitattributes                                     |  18 +
 .github/workflows/godot-ci.yml                     | 276 ++++++++++++++
 .github/workflows/pipeline-self-test.yml           | 122 +++++++
 .github/workflows/repository-checks.yml            |  26 +-
 .gitignore                                         |  15 +
 docs/development/GODOT_CI_AND_DEPLOYMENT.md        | 240 +++++++++++++
 docs/development/GODOT_PROJECT_HANDOFF.md          | 166 +++++++++
 orders/Kiro/order_01.md                            |  32 +-
 .../2026-10-18-bootstrap-godot-ci-deploy-report.md |  75 ++++
 scripts/ci/check_workflows.py                      | 356 ++++++++++++++++++
 scripts/ci/ci_common.py                            | 229 ++++++++++++
 scripts/ci/discover_project.py                     | 101 ++++++
 scripts/ci/export_tools.py                         | 169 +++++++++
 scripts/ci/godot-log-allowlist.txt                 |  11 +
 scripts/ci/godot-version.env                       |  24 ++
 scripts/ci/godot_cfg.py                            | 124 +++++++
 scripts/ci/godot_ci.py                             | 288 +++++++++++++++
 scripts/ci/godot_log.py                            |  64 ++++
 scripts/ci/godot_walker.py                         | 150 ++++++++
 scripts/ci/install_godot.py                        | 237 ++++++++++++
 scripts/ci/pages_gate.py                           | 152 ++++++++
 scripts/ci/pins.py                                 | 152 ++++++++
 scripts/ci/selftest.py                             | 359 +++++++++++++++++++
 scripts/ci/selftest_project.py                     | 333 +++++++++++++++++
 scripts/ci/smoke/console-allowlist.json            |   4 +
 scripts/ci/smoke/lib/args.mjs                      |  69 ++++
 scripts/ci/smoke/lib/console-policy.mjs            |  90 +++++
 scripts/ci/smoke/lib/console-policy.test.mjs       | 101 ++++++
 scripts/ci/smoke/lib/harness.test.mjs              | 127 +++++++
 scripts/ci/smoke/lib/pixels.mjs                    |  59 +++
 scripts/ci/smoke/lib/report.mjs                    |  40 +++
 scripts/ci/smoke/lib/serve.mjs                     |  97 +++++
 scripts/ci/smoke/lib/steps.mjs                     | 138 +++++++
 scripts/ci/smoke/package-lock.json                 |  45 +++
 scripts/ci/smoke/package.json                      |  17 +
 scripts/ci/smoke/smoke-config.json                 |   8 +
 scripts/ci/smoke/smoke.mjs                         | 250 +++++++++++++
 scripts/ci/tests/helpers.py                        |  32 ++
 scripts/ci/tests/test_common_and_log.py            |  92 +++++
 scripts/ci/tests/test_export_gate_and_ci.py        | 289 +++++++++++++++
 scripts/ci/tests/test_install_godot.py             | 117 ++++++
 scripts/ci/tests/test_pins_and_discovery.py        | 158 ++++++++
 scripts/ci/tests/test_project_validation.py        | 397 +++++++++++++++++++++
 scripts/ci/tests/test_safety_and_harness.py        | 276 ++++++++++++++
 scripts/ci/tests/test_workflow_lint.py             | 173 +++++++++
 scripts/ci/validate_godot_project.py               | 378 ++++++++++++++++++++
 46 files changed, 6649 insertions(+), 27 deletions(-)
```

The stat was taken before this report was filled in, so the count on the report's own row (75) is lower than in the commit; `git diff --stat origin/main...HEAD` on the pull request shows the final numbers. Reason per group:
- `.github/workflows/` (3 files): `godot-ci.yml` (new: detect, build, pre-deploy smoke, deploy on `main` only, post-deploy smoke, `godot-ci-gate`), `pipeline-self-test.yml` (new: tooling lint and unit tests, then the end-to-end self-test on generated projects; never deploys), `repository-checks.yml` (modified: the job `validate-orders-and-project` keeps its id and validation step; runner pinned to `ubuntu-24.04`, `actions/checkout` pinned by SHA with `persist-credentials: false`, project detection delegated to `scripts/ci/discover_project.py`).
- `.gitattributes`, `.gitignore`: LF line endings for scripts and YAML; ignore `.godot/`, `/exports/`, `node_modules/`, `__pycache__/`, `godot-ci-logs/` and similar generated output so a project at the repository root never commits caches.
- `scripts/ci/` pin file and Python tooling (`godot-version.env`, `pins.py`, `ci_common.py`, `godot_log.py` + allowlist, `godot_cfg.py`, `discover_project.py`, `validate_godot_project.py`, `godot_walker.py`, `export_tools.py`, `install_godot.py`, `godot_ci.py`, `pages_gate.py`, `check_workflows.py`, `selftest.py`, `selftest_project.py`): the single pin file, the stdlib-only validation script (project and export-preset rules), the `.gdignore`-aware resource walker (GDScript text, written to a temp folder at run time), the SHA512-verifying Godot installer, the step runner used by the workflows, the Pages preflight and gate, the workflow lint and the self-test orchestrator with its throwaway-project generator. `scripts/ci/validate_orders.py` is untouched.
- `scripts/ci/tests/` (8 files): 125 stdlib `unittest` tests for the tooling above.
- `scripts/ci/smoke/` (13 files): the Playwright browser smoke test (exact Playwright 1.64.1 lockfile, local static server that mirrors GitHub Pages, console policy, readiness-hook verdict) and its 23 Node tests.
- `docs/development/` (2 new documents): `GODOT_CI_AND_DEPLOYMENT.md` (pipeline, admin-only steps, troubleshooting, bumping pins) and `GODOT_PROJECT_HANDOFF.md` (repository-root convention, the `.gdignore` list stage 2 adds, checklist).
- `orders/Kiro/order_01.md`: status `IN_PROGRESS` (stage 1 of 2), reassignment recorded, seven acceptance boxes unticked and annotated "pending stage 2", status log.
- `orders/Kiro/reports/` (this report).

Not touched: `orders/Aki`, `orders/Orcha`, `orders/Codex`, `assets/**`, `docs/visuals/**`, `docs/prototype/**`, `world/**`, `skills/three-quarter-game-art/**`, `.github/pull_request_template.md`, `scripts/ci/validate_orders.py`, and every file of the other open PRs (#1, #2, #3).

## Tests run before commit
Environment (local, 2026-10-18): Windows 11 Enterprise (NT 10.0.26200.0) with Windows PowerShell 5.1; Python 3.14.7; Node v24.19.0 and npm 11.17.0 (the CI pin is Node 24.22.0, so the pinned Node patch version has not been run yet); Git 2.55.0.windows.3; gh 2.100.0; Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, Windows console editor; the single-threaded Web debug template, plus the threaded one for a negative self-test case, both from the same 4.7.2 release); Playwright 1.64.1 with Chromium 156.0.8078.4 (headless shell); actionlint 1.7.12 with shellcheck 0.9.0 (`shellcheck-py` 0.9.0.6, the version of the ubuntu-24.04 runner). Nothing was run on Linux before the pull request; ubuntu-24.04 results come from the PR's own checks.

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python scripts/ci/validate_orders.py` (unchanged script, new order text) | PASS (exit 0, 1.7 s) | `Agent READMEs and order structure validated.` |
| `python scripts/ci/discover_project.py` on this repository | PASS (exit 0, 2.1 s); reports that no project exists | Warning `Godot project NOT FOUND - NOT VALIDATED - NOT DEPLOYED`: "No project.godot exists in this repository ... The project (at the repository root) is delivered by stage 2 of Order 01". The `project_found=false` step output is only written inside Actions (`GITHUB_OUTPUT`); it is asserted by the unit tests, not by this run. |
| `python -m unittest discover -s scripts/ci/tests -v` | PASS (125 tests, exit 0, 29.6 s) | `Ran 125 tests in 21.163s`, `OK`. Built up layer by layer while copying: 15 + 15 + 33 + 8 + 23 tests, then the whole suite (an earlier full run took 5.7 s). |
| `node --test` in `scripts/ci/smoke` (after `npm ci --ignore-scripts --no-audit --no-fund`: `added 2 packages`) | PASS (23 tests, exit 0, 1.9 s) | `tests 23`, `pass 23`, `fail 0` |
| `python scripts/ci/check_workflows.py` | PASS (exit 0, 3.4 s) | `check_workflows: OK - 0 problem(s)` |
| `python scripts/ci/pins.py check` | PASS (exit 0, 4.3 s) | `pins OK (10 keys, Godot 4.7.2)` |
| External pins re-checked: `gh release download 4.7.2-stable --repo godotengine/godot-builds --pattern SHA512-SUMS.txt`, and `gh api repos/<action>/compare/<default branch>...<pinned sha>` for each action | PASS | The three Godot SHA512 pins (Linux editor, Windows editor, export templates) equal the release's `SHA512-SUMS.txt`; all 8 pinned action commits resolve in their repositories (`actions/cache`, `actions/checkout`, `actions/upload-pages-artifact` are behind their default branch, the other five identical). |
| `actionlint -no-color` (v1.7.12, Windows build whose zip SHA256 equals the pin; shellcheck 0.9.0 on `PATH`) on the three workflows | PASS (exit 0, 14.9 s) | No findings. Check that shellcheck is really used: a deliberately broken temporary workflow (`run: echo $FOO bar`) was reported as `SC2086` with shellcheck on `PATH` and gave no finding with `-shellcheck=` (temporary file, deleted). |
| `python -m compileall -q scripts/ci` (bytecode sent to a temp folder with `PYTHONPYCACHEPREFIX`) and an AST parse of every module with the Python 3.10 grammar | PASS (exit 0, 2.5 s and 1.3 s) | `ast OK (3.10 grammar): 23 files`; no `__pycache__` under the repository. The runner has Python 3.12.3; the code was run on 3.14.7 locally. |
| `node --check <file>` on the 9 `.mjs` files of `scripts/ci/smoke` | PASS (9 of 9 exit 0) | no output |
| `python scripts/ci/install_godot.py verify` then `install --platform windows --dest <install folder outside the repository> --with-threaded-templates` | PASS (0.7 s and 1.0 s) | `verify: OK`; `cache hit: Godot 4.7.2 already installed and verified in <install folder>`; `GODOT_VERSION_STRING=4.7.2.stable.official.ed1daf0bf`. No new download in this run: it reused the install that `install_godot.py` itself downloaded and SHA512-verified earlier on 2026-10-18 (outside the repository); `verify` re-checks the manifest against the pins and the SHA256 of every installed file. The Linux editor was not run. |
| `npx playwright install --only-shell chromium` in `scripts/ci/smoke` | PASS (exit 0, 4.7 s) | No output: the headless Chromium shell was already installed (the smoke result records Chromium 156.0.8078.4, Playwright 1.64.1). |
| `python scripts/ci/selftest.py --godot-dir <install folder> --work-dir <temp>/selftest-work --evidence-dir <temp>/selftest-evidence` (all 16 cases, no `--cases`) | PASS (exit 0, 281.9 s) | `## Pipeline self-test (tooling verification, NOT the game, nothing deployed): PASS` and `all 16 cases ran; 36/36 expectations met`; per-case table below (`selftest-results.json`: 36 entries, 0 failed). |
| Screenshots of the self-test evidence, opened and looked at | PASS (viewed) | `good/smoke/screenshots/02-after-input.png`: four colour quadrants (blue, orange, green, purple), the label `PIPELINE SELF-TEST - NOT THE GAME   moves: 1` at the top left and a yellow square. `threads_enabled_export/smoke/screenshots/99-engine-start-failed.png`: the Godot error notice "The following features required to run Godot projects on the Web are missing: Cross-Origin Isolation ... SharedArrayBuffer ...", which is the expected failure of that negative case. |
| Pages and environment settings re-read, read-only: `gh api repos/kiotdstudios/shinobi-rush/pages`, `.../environments`, `.../environments/github-pages/deployment-branch-policies`, plus one HTTP GET of `https://kiotdstudios.github.io/shinobi-rush/` (at 2026-10-18 07:07 and again at 07:25 -04:00) | PASS: unchanged from the state the orchestrator reported (15 of 15 values equal both times) | `build_type=workflow`, `status=null`, `https_enforced=true`, `source=main:/`; one environment `github-pages` (id 24623790548, created 2026-10-18T09:40:24Z, `can_admins_bypass=true`, custom deployment branch policies) with exactly one policy `main`; the site answers HTTP 404 (nothing deployed). This job changed no setting. |
| CI run `Repository checks` on the PR | PASS: success on head 3355115 ([run 39123715862](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39123715862); the required check `validate-orders-and-project` passed in 4 s) | The job ran the unchanged order validation and then `discover_project.py`, which printed the warning annotation `Godot project NOT FOUND - NOT VALIDATED - NOT DEPLOYED` (read from the job's check-run annotations). |
| CI run `Godot CI` on the PR (expected: NOT VALIDATED, NOT DEPLOYED, green) | PASS: success on head 3355115 ([run 39123715926](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39123715926)) | `Detect Godot project` success (6 s) with the same NOT FOUND warning; `godot-ci-gate` success (6 s) with the warning annotation "NOT VALIDATED, NOT DEPLOYED: no Godot project exists, so no Godot check ran. This gate is green only because there is nothing to validate."; the four Godot jobs (`Import, validate, test and export (Web)`, `Pre-deploy browser smoke test`, `Deploy to GitHub Pages (main only)`, `Post-deploy live smoke test`) were skipped, as intended. The repository has 0 deployments afterwards. |
| CI run `Pipeline self-test` on the PR (Linux, ubuntu-24.04) | PASS: success on head 3355115 ([run 39123715912](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39123715912)) | `Tooling lint and unit tests` success (16 s): `check_workflows: OK - 0 problem(s)`, actionlint 1.7.12 archive SHA256 `OK`, `Ran 125 tests ... OK`, Node `tests 23`, `pass 23`, `fail 0`. `Self-test - positive and negative cases (throwaway project, never deployed)` success (2 m 30 s): `all 16 cases ran; 36/36 expectations met in 112s`; artifact `selftest-evidence` (about 160 KB), whose `summary.md` lists the same 16 cases as the local run. Recorded environment: Linux, Node v24.22.0, Playwright 1.64.1, Chromium 156.0.8078.4, `webgl2-available: pass`. No flag, allowlist entry, rerun or version step-down was needed. |

Self-test cases and expected outcomes (the run said `all 16 cases ran; 36/36 expectations met`; the table is built from the run's `selftest-results.json`; every project used here was generated in a temp folder at run time, outside the repository; none was committed):

| Case | Expectations | Result | What was asserted (and observed) |
| --- | --- | --- | --- |
| `good` | 8 | PASS | Positive case. `validate-project`, `import`, `validate-resources`, the tests step (none present: loud warning, exit 0), `export` + `finalize-export`, `check-export` (`kind=selftest`), the deploy guard (a self-test export is refused as `game`) and the strict browser smoke test all pass. |
| `forward_plus_base` | 5 | PASS | Positive case. A Forward+ desktop project passes with a `PRJ005` warning and no error; the Web export is forced to Compatibility; the strict smoke test confirms the runtime renderer. |
| `repo_shaped_layout` | 8 | PASS | Positive case. Project at the root of a checkout next to non-game folders with images and `.gdignore` files (steps listed below). |
| `threads_enabled` | 1 | PASS | `validate-project` must exit 1 with `EXP005`. |
| `missing_main_scene` | 1 | PASS | `validate-project` must exit 1 with `PRJ004`. |
| `no_main_scene` | 1 | PASS | `validate-project` must exit 1 with `PRJ003`. |
| `web_renderer_override` | 1 | PASS | `validate-project` must exit 1 with `PRJ006`. |
| `gdignore_scripts` | 1 | PASS | `validate-project` must exit 1 with `PRJ013`. |
| `selftest_fixture_refused` | 1 | PASS | Without the allow flag `validate-project` must exit 1 with `PRJ014`. |
| `parse_error` | 1 | PASS | `import` alone passes (Godot cannot see the orphan script); `validate-resources` must fail and name `broken.gd`. |
| `parse_error_referenced` | 1 | PASS | `import` must fail on `Parse Error` although Godot exits 0. |
| `startup_script_error` | 1 | PASS | Browser smoke must fail at `no-fatal-console` because of the injected fault, while `engine-start` and `canvas-visible` still pass. |
| `startup_error` | 1 | PASS | Same assertion for an injected startup error. |
| `page_error` | 1 | PASS | Same assertion for an injected page error. |
| `blank_canvas` | 1 | PASS | Browser smoke must fail at `canvas-not-blank`, while `engine-start`, `canvas-visible` and `no-fatal-console` still pass. |
| `threads_enabled_export` | 3 | PASS | The export step refuses a threaded export after the engine wrote it; `finalize-export` refuses it (`THREADED export`); the browser smoke test fails at `engine-start` with the missing Cross-Origin Isolation notice (no COOP/COEP headers, exactly like GitHub Pages). |

The eight `repo_shaped_layout` expectations (all PASS):
1. `validate-project` with the project at the repository root: no `PRJ012` and no `PRJ013`.
2. `import` succeeds.
3. `import` honoured the `.gdignore` files: the game art and the control image were imported, none of the ignored images was.
4. `validate-resources` walks exactly the 3 game scripts and 1 scene, and skips the ignored, dot, `node_modules`, `exports` and `scripts/ci` folders (invalid decoy scripts there are never loaded).
5. `export` + `finalize-export` succeed.
6. The exported pack contains the game code, the game art and the control image, and no ignored image, no ignored decoy script and nothing of `scripts/ci`.
7. Strict browser smoke test: the game code under `scripts/` loads at runtime.
8. `validate-resources` never walks `scripts/ci`, even after its `.gdignore` is deleted (an invalid script there is not loaded).

Not run, and why: the job bodies of `godot-ci.yml` (`build`, `smoke-predeploy`, `deploy`, `smoke-postdeploy`; skipped because no project exists, so the YAML glue between the scripts has never executed on a runner) and everything behind GitHub Pages (Pages is enabled, but nothing has ever been deployed, so the deploy path has never run). They are linted (actionlint, `check_workflows.py` incl. `WF014`/`WF017`) and the scripts they call are unit-tested and exercised end to end by the self-test with the same command lines, but the first real run is the stage 2 pull request (checklist: `GODOT_CI_AND_DEPLOYMENT.md`, "First run on a real project").

## Live deployment / URL and build evidence
- Live deployment: **NOT PERFORMED**. Reason: stage 2 (project bootstrap) not yet delivered, so no Godot project exists. GitHub Pages is enabled (2026-10-18, orchestrator, owner's authorization), but nothing was deployed.
- URL: none live (the site answers HTTP 404). Expected-but-UNVERIFIED pattern: `https://kiotdstudios.github.io/shinobi-rush/` (the `html_url` the Pages API reports; the real URL is the `page_url` output of the deploy step).
- Build ID / deployment SHA: none (no game build was produced). Self-test builds are tooling verification: `kind=selftest`, never deployed.

## Issues encountered
**Problems hit while implementing (this job)**
- No test, lint or self-test case failed while the tree was assembled and verified locally; every layer passed on its first run. Nothing was changed after the first local run except the order and this report.
- The shell used for the local runs sometimes returned before a long command had finished and dropped part of its output. No result was taken from such output: every gate was run through a small wrapper that writes a log file ending in the exit code and the duration, long runs were started in the background, and the logs were read in a later call. Machine load also made some runs slower than the same commands measured earlier (the full self-test took 281.9 s here; the Pages/environment read took 70 s once). No transient Godot engine crash (a single one, exit 4294967295 right after the banner, had been seen once under heavy parallel load in an earlier verification run of this job) occurred in this run.
- One read-only read of the Pages settings (made by the last pre-commit conformance run) failed with a network error and was reported as "could not read", not as a changed setting; the same check run again straight afterwards read all 15 values and found them unchanged.
- The tests' temp-folder cleanup is tolerant of a one-off Windows `WinError 32` (file in use) that had appeared under heavy parallel load while the tooling was first verified; it did not occur in this run.
- `scripts/ci/smoke/node_modules` and the Playwright browser are created locally by `npm ci` and `playwright install`; both are git-ignored or outside the repository, and `npm ci` left the lockfile byte-identical.
- The pinned Node is 24.22.0 (used by `actions/setup-node` in CI) but the local Node is v24.19.0, so the pinned patch version runs for the first time in CI.

**How the independent design review's eight minor findings were handled**
- F1, browser negative cases asserted less than documented: applied. Each browser negative case now requires the named check to fail with the injected fault in its recorded detail while the unrelated checks still pass; `parse_error` also requires `import` to exit 0 (in the self-test table above).
- F2, the status wording promised Linux results before the pull request existed: applied. Before the first CI run the text only said that ubuntu-24.04 results would be added later; this follow-up commit replaces it with the observed results.
- F3, the claim that referencing the `github-pages` environment makes GitHub create it: superseded by the later owner update. Enabling Pages created the environment (verified: one `github-pages` environment, main-only branch policy), so that claim and the "not verified" sentences are gone from `pages_gate.py`, the CI document and this report.
- F4, three text/code mismatches: they were in the planning text only; the committed documents do not contain them, so there is no repository change.
- F5, defence in depth: applied lint rule `WF019` (no workflow may mention `SHINOBI_ALLOW_SELFTEST_PROJECT`); declined extending `WF012` to branch filters, because the line-based lint is deliberately not a YAML parser (backlog).
- F6, procedure traps: applied. The PR body is filled in a temporary copy and checked for leftover markers, `godot-ci-logs/` is git-ignored, `gh auth status` must list the `workflow` scope before pushing workflow files, and long commands run in the background.
- F7, the self-test is advisory and an artifact round-trip job would exercise the artifact actions: declined (backlog). `Pipeline self-test` must never be a required check; a red self-test should block a merge by convention.
- F8, review size: declined. The pull request is large (46 files, most of the lines are tooling and tests under `scripts/ci`); the PR body says so and no split was offered because the owner authorized merging and speed matters. The tests and the documentation lint read the workflows and documents, so the parts belong together.

**CI findings on Linux (first run of this PR, nothing needed fixing)**
All three workflows were green on the first run of the pull request head, with no fix commit, no rerun and no workflow change. The risks that could only be checked on a runner turned out as follows (image `ubuntu-24.04`, release 20261012.334):
1. WebGL2 in headless Chromium on ubuntu-24.04: not a problem. Every browser smoke check of the CI self-test recorded `webgl2-available: pass` with Chromium 156.0.8078.4, and no Chromium flag was needed.
2. The Linux Godot binary: it ran in CI (SHA512-verified install, import, validation, Web export and all negative cases) and all 16 cases / 36 expectations were met; before that only the Windows editor had been run.
3. New action majors: `actions/checkout` v7.0.1, `actions/cache` v6.1.0, `actions/setup-node` v7.1.0 and `actions/upload-artifact` v7.0.2 were executed and worked. `actions/download-artifact` v8, `actions/configure-pages` v6, `actions/upload-pages-artifact` v5 and `actions/deploy-pages` v5 are only used by the skipped jobs, so they have still never run.
4. Python: the 125 unit tests (run in 1.7 s) and `check_workflows.py` also passed on the runner's system `python3`; locally the code ran on 3.14.7 and was parsed with the 3.10 grammar.
5. Node: the pinned Node v24.22.0 ran for the first time in CI (it is the version recorded in the smoke result) and the 23 Node tests passed.

**Known risks that remain**
1. The Godot job bodies of `godot-ci.yml` (`build`, `smoke-predeploy`, `deploy`, `smoke-postdeploy`) have never run on a runner (see "Not run, and why"); their first run is the stage 2 pull request.
2. The gdUnit4 command line in the test-detection step is unverified (no project with tests exists).
3. The repository-root layout is proven against generated projects in temp folders (Windows locally and Linux in CI), not against the real stage 2 project.

The checks of this follow-up commit itself are visible in the pull request's checks tab, because a report cannot record the result of its own commit.>

## Questions for project owner
**Resolved**
1. Who owns bootstrapping the real Godot 4 project? Resolved 2026-10-17: Kiro, by explicit reassignment (`orders/README.md` rule 4).
2. Should Kiro build a minimal real Godot project and playable scene? Resolved 2026-10-17: yes. It is delivered as stage 2, a separate follow-up pull request.
3. Where does the project live? Resolved by the locked architecture (section 11 of `docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md`): at the repository root, so `assets/` is inside `res://`.
4. Enable GitHub Pages? Resolved 2026-10-18: enabled by the orchestrator with the owner's authorization (Actions source; not by this PR/CI).
5. May the pull requests be merged once the checks are green? Resolved 2026-10-18: yes, by the orchestrator after every check is green and the review approved it. Kiro (the workflow agents) never merges.

**Still open**
6. After stage 2 passes `Godot CI`, add the new Godot check(s) (`godot-ci-gate`) to the `Agent Rules` required checks (manual admin step). Do not require `Pipeline self-test`.
7. Confirm the live-test build may use the debug export template (needed so script errors are visible to the smoke test).
8. Is Compatibility acceptable for the Windows build, or should the desktop renderer be Forward+/Mobile? (CI only warns; the Web build is always Compatibility.)
9. Optional: enable "Require actions to be pinned to a full-length commit SHA" and add Dependabot for `github-actions` (outside this order's file scope).

## Outstanding work / next steps
1. Stage 1: the orchestrator merges this pull request after every check is green and the review approved it (Kiro does not merge).
2. Stage 2 (separate pull request, Kiro): minimal real Godot 4.7.x project at the repository root with the `.gdignore` files listed in the handoff; then the first push to `main` with a project: verify `deploy`, `smoke-postdeploy`, record the real URL and `deploy-info.json`, tick the acceptance criteria and finish the order.
3. An administrator adds `godot-ci-gate` as a required check once stage 2 has proven it.
4. Optional improvements: release-template export as a separate artifact, gamepad emulation in the smoke test, scheduled weekly self-test run.
