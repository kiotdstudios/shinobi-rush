# Godot CI, Web export and live-test deployment

Owner: Kiro (Order 01, stage 1 of 2). Audience: anyone who merges to `main`, whoever builds the Godot project, and repository administrators.

## Status: read this first

- **Stage 1 of 2.** This document describes the CI and deployment pipeline delivered by stage 1 of Order 01. The first minimal real Godot project (at the repository root) and the first live deployment are **stage 2**, a separate follow-up pull request that the project owner reassigned to Kiro on 2026-10-17. Order 01 stays IN_PROGRESS until stage 2 is merged and verified.
- **There is no Godot project in this repository yet.** Until `project.godot` lands, every Godot check reports `NOT VALIDATED` and the deploy step reports `NOT DEPLOYED`. A green check in that state only means "there was nothing to validate". It does not mean the game builds, passes tests, is deployed or starts in a browser.
- **Live deployment: NOT PERFORMED** (stage 2, the project bootstrap, is not delivered yet). GitHub Pages was **enabled on 2026-10-18 by the project's orchestrator with the project owner's explicit authorization** (the Actions source; not by this pull request and not by CI): the Pages API reports `build_type=workflow`, the site answers HTTP 404 because nothing has been deployed, and the `github-pages` environment exists with a main-only deployment branch policy (details and the re-check commands: [Admin-only steps](#admin-only-steps)).
- **Expected live URL, NOT live yet:** `https://kiotdstudios.github.io/shinobi-rush/`. This is GitHub's `<owner>.github.io/<repo>/` naming convention and the `html_url` the Pages API reports. The authoritative URL is the `page_url` output of the deploy step, recorded in `deploy-info.json`; the first deployment can only happen after stage 2 (a real project) is merged to `main`. Never copy the expected URL into a report as if it were verified.
- **The pipeline self-test builds throwaway projects, never the game.** They are generated at run time in a temporary folder, are never committed or deployed, and every file says "PIPELINE SELF-TEST - NOT THE GAME".
- **The Godot jobs of `godot-ci.yml` (`build`, `smoke-predeploy`, `deploy`, `smoke-postdeploy`) have never run on a runner.** They are skipped until a project exists. What has run: `detect`, `godot-ci-gate`, every script they call (unit tests plus the end-to-end self-test on throwaway projects, with the same command lines), and actionlint. What has not: the YAML glue between those scripts (environment variables, artifact hand-over, cache steps) and the Pages path. See [First run on a real project](#first-run-on-a-real-project).
- What the project has to provide, the repository-root convention and the `.gdignore` list: [GODOT_PROJECT_HANDOFF.md](GODOT_PROJECT_HANDOFF.md).

## What exists

| Path | Purpose |
| --- | --- |
| `.github/workflows/repository-checks.yml` | Required check `validate-orders-and-project` (orders, instructions, project discovery). Unchanged semantics. |
| `.github/workflows/godot-ci.yml` | Godot pipeline: detect, build, pre-deploy smoke, deploy (main only), post-deploy smoke, `godot-ci-gate`. |
| `.github/workflows/pipeline-self-test.yml` | Tooling verification (lint, unit tests, positive and negative end-to-end cases). Never deploys. |
| `scripts/ci/godot-version.env` | The single pin file (Godot, Node, Playwright, actionlint, runner image). |
| `scripts/ci/*.py` | Python standard-library tooling used by the workflows and by local runs. Unit tests: `scripts/ci/tests/`. |
| `scripts/ci/godot_walker.py` | Holds the GDScript text of the headless resource walker (loads every script, scene and resource in the project). `godot_ci.py` writes it to a temporary folder outside the project each time, so no `.gd` file is committed. |
| `scripts/ci/smoke/` | Node + Playwright browser smoke test (pinned, lockfile). |

## Job graph (godot-ci.yml)

```text
pull_request | push to main | workflow_dispatch
        |
     detect ------------- no project.godot ------------> godot-ci-gate: NOT VALIDATED, NOT DEPLOYED (green, loud annotation)
        | project found
      build  install pinned Godot + templates (cached, SHA512-verified)
             -> headless import
             -> validate project settings and Web export preset
             -> validate every script and scene loads
             -> run GUT / gdUnit4 tests if present (warning if absent)
             -> export Web (debug template, single-threaded, Compatibility) + build-info.json
        |
  smoke-predeploy   real Chromium against a local static server (no COOP/COEP, like Pages); runs on PRs too
        |
     deploy         ONLY push to main / dispatch from main; Pages preflight, configure, upload, deploy
        |
  smoke-postdeploy  real Chromium against the real URL; waits until build-info.json shows THIS commit
        |
  godot-ci-gate     always runs; the single status to require once a project exists
```

Nothing is published from pull requests. The `deploy` job has `pages: write` and `id-token: write`; no other job has any write permission.

## Gates

| Gate | Fails when | Evidence |
| --- | --- | --- |
| Pins and workflow hygiene (`check_workflows.py`) | a pin is malformed, an action is not SHA-pinned, a runner is `*-latest`, a write permission leaks, docs show a stale pin | job log annotations |
| Project discovery | several projects without `GODOT_PROJECT_DIR`, or an invalid override | `detect` job summary |
| Headless import | Godot exits non-zero, times out, or prints `ERROR:` / `SCRIPT ERROR:` (Godot exits 0 on a script parse error, so the log is scanned) | `logs/import.log` |
| Project and preset validation | any rule in the table of [GODOT_PROJECT_HANDOFF.md](GODOT_PROJECT_HANDOFF.md) reports an error | `project-validation.json` |
| Script and scene validation | a `.gd` file cannot compile, a scene cannot load, a dependency is missing (orphan scripts included) | `logs/validate-resources.log` |
| Tests | GUT or gdUnit4 reports a failure (absence only warns) | `logs/tests-*.log` |
| Web export | export fails, prints engine errors, produces a threaded build, or files do not match `build-info.json` | `logs/export.log`, `build-info.json` |
| Pre-deploy smoke test | engine does not start, canvas missing or blank, fatal console / page / network error, wrong commit | `smoke-predeploy/` |
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
# 5. once a real project exists (it is the repository root, so <project> is "."; run from the repository root):
$env:GODOT_BIN = (python scripts/ci/install_godot.py print-bin --platform windows --dest "$env:LOCALAPPDATA\shinobi-rush-ci\godot")
python scripts/ci/godot_ci.py import --project <project>
python scripts/ci/validate_godot_project.py --project <project>
python scripts/ci/godot_ci.py validate-resources --project <project>
python scripts/ci/godot_ci.py tests --project <project>
python scripts/ci/godot_ci.py export --project <project> --out "$env:TEMP\web-export"
python scripts/ci/godot_ci.py finalize-export --project <project> --out "$env:TEMP\web-export" --kind game
cd scripts\ci\smoke; node smoke.mjs --serve-dir "$env:TEMP\web-export" --out-dir "$env:TEMP\smoke-evidence" --expected-sha (git rev-parse HEAD); cd ..\..\..
```

The import step creates `.godot/`, `*.uid` and `*.import` files in the project folder, exactly like opening the editor. Commit the `.uid` and `.import` files; never commit `.godot/`. To play an export by hand, serve the folder with `node scripts/ci/smoke/lib/serve.mjs "$env:TEMP\web-export" 8080` and open `http://127.0.0.1:8080/` (not `file://`).

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

## Admin-only steps

These need repository administrator rights. Neither Order 01's pull requests nor any workflow performs them; steps 1 and 2 were done once, by hand, as described below.

1. **Enable GitHub Pages with the GitHub Actions source** (required before the first deploy). **DONE on 2026-10-18** by the project's orchestrator with the project owner's explicit authorization (not by Order 01's pull request and not by CI). Settings > Pages > Build and deployment > Source: **GitHub Actions**. CLI equivalent, kept here as the reproducible / disaster-recovery instruction (forks, re-enabling): `gh api -X POST repos/kiotdstudios/shinobi-rush/pages -f build_type=workflow`. Verified state after the change (read-only `gh api repos/kiotdstudios/shinobi-rush/pages`): `build_type=workflow`, `html_url=https://kiotdstudios.github.io/shinobi-rush/`, `public=true`, `https_enforced=true`, `status=null` (nothing deployed yet) and the site answers HTTP 404 until the first deployment. Without Pages, the `deploy` job on `main` would fail with "GitHub Pages is NOT enabled" (the honest outcome, but a red `main`); the preflight message stays for forks.
2. **The `github-pages` environment: VERIFIED.** Enabling Pages created it (2026-10-18) with a main-only custom branch policy: `can_admins_bypass=true`, `deployment_branch_policy={protected_branches: false, custom_branch_policies: true}` and exactly one branch policy `{name: "main", type: "branch"}`, so only `main` may deploy. Re-check with `gh api repos/kiotdstudios/shinobi-rush/environments/github-pages` and `gh api repos/kiotdstudios/shinobi-rush/environments/github-pages/deployment-branch-policies`. Optionally add required reviewers (Settings > Environments > github-pages) if deployments should need approval.
3. **Optional repository variables** (Settings > Secrets and variables > Actions > Variables): `GODOT_PROJECT_DIR` only if the repository ever contains more than one Godot project; `PAGES_ALLOW_CUSTOM_DOMAIN=true` only if a custom domain on this Pages site is intended (the preflight refuses to deploy a test build over a custom-domain site by default).
4. **Require the Godot gate** after a pull request has run `Godot CI` once (GitHub only offers checks it has seen in the last 7 days): Settings > Rules > Rulesets > **Agent Rules** > Require status checks to pass > Add checks > `godot-ci-gate` (source: GitHub Actions). Keep `validate-orders-and-project` and keep "Require branches to be up to date before merging" (strict) as it is; the ruleset currently enforces both. Do this only once a real project exists and `godot-ci-gate` has passed on it; before that the gate only says NOT VALIDATED.
5. **Do not require** `Pipeline self-test` or its jobs.
6. Optional hardening: Settings > Actions > General > "Require actions to be pinned to a full-length commit SHA" (all workflows here already comply), and a `.github/dependabot.yml` for the `github-actions` ecosystem (not added by Order 01 because it is outside the order's file scope).

### Why a workflow-level `paths:` filter must not be used on a required check

If a workflow is skipped because of path filtering, branch filtering or a commit message, the checks it would have produced stay **Pending**, and a pull request that requires them can never merge. A job skipped by a job-level `if:` reports success instead. That is why `repository-checks.yml` and `godot-ci.yml` have no `paths:` filter and decide inside the workflow (`detect` job and `if:` conditions), and why `godot-ci-gate` runs with `if: always()` and checks the upstream results explicitly: a required check on a downstream job would count as passed when the upstream job fails and the downstream one is skipped.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `NOT VALIDATED, NOT DEPLOYED` | No `project.godot` exists. Expected until stage 2 (the first real project, at the repository root) lands. |
| `Multiple Godot projects` | Set the repository variable `GODOT_PROJECT_DIR`. |
| `SHA512 mismatch for ...` | The pin does not match the download. Re-run the bump procedure; never edit one hash alone. |
| Import log shows `SCRIPT ERROR: Parse Error` | A script does not compile. Open the project in the pinned editor. Godot exits 0 here; the pipeline fails on the log text. |
| `EXP005 ... thread_support` | Threads need COOP/COEP headers that GitHub Pages cannot send. Set Thread Support = Off in the Web preset. |
| Smoke test: `status notice shown: ... features required to run Godot projects on the Web are missing` | Threaded export, no WebGL2, or an insecure origin. The local server uses `127.0.0.1`, which is a secure context. |
| Smoke test exit code 3, `webgl2-available` fails | The runner's headless Chromium has no WebGL2. This is an environment problem, not a game defect. Try `SMOKE_CHROMIUM_ARGS="--use-angle=swiftshader"`, then `"--use-gl=angle --use-angle=swiftshader"` in the workflow `env`. |
| `no-fatal-console` fails on a harmless engine message | Godot `WARNING:` blocks never fail. Plain `console.error`, `ERROR:` and `SCRIPT ERROR:` do. Fix the cause; only as a last resort add a justified entry to `scripts/ci/smoke/console-allowlist.json` or `scripts/ci/godot-log-allowlist.txt` in a reviewed PR. |
| `GitHub Pages is NOT enabled` | Admin step 1. |
| `... is not empty and was not created by this tooling` | The self-test refuses to delete a directory it did not create. Point `--work-dir` at a new or empty folder. |
| `PRJ012 ... Add an empty .gdignore file to: ...` | The project is the repository root and a folder without game resources has no `.gdignore`, so Godot would import its images and export them. Create the empty file in each listed folder (`docs`, `orders`, `skills`, `world`, `scripts/ci`, `assets/characters/player/references`). |
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

The first pull request that adds a `project.godot` (stage 2) is the first time the Godot jobs run on a runner. Expect to look at these in order, and treat any failure there as a pipeline defect to fix in the same PR (not as a reason to disable a check):

1. `Godot CI / detect` summary: `project_found=true` and `project_dir=.` (the repository root).
2. `build`: cold cache (the first run downloads the 1.28 GB templates archive and installs two files from it); the `Install pinned Godot` step prints `SHA512 verified`; `Load pinned tool versions` and `Prepare working directories` wrote the environment variables the later steps use (`GODOT_BIN`, `EVIDENCE_DIR`, `EXPORT_DIR`, `PROJECT_DIR`).
3. `build` artifacts: `web-export` (with `build-info.json`) and `godot-ci-build-evidence` exist.
4. `smoke-predeploy`: `webgl2-available` passes (exit code 3 means the runner's headless Chromium has no WebGL2; see Troubleshooting).
5. `godot-ci-gate` summary says `VALIDATED (not deployed: only main deploys)` on the PR.
6. After the stage 2 PR is merged to `main` (Pages and the `github-pages` environment are already set up): `deploy` and `smoke-postdeploy` on `main`, then `deploy-info.json` in the post-deploy artifact.

Uploads use `overwrite: true`, so "Re-run all jobs" replaces an artifact of the same name instead of failing (from the action's documentation; not observed on this repository).

## Known limitations

- The deploy path (`configure-pages`, `upload-pages-artifact`, `deploy-pages`) and the post-deploy smoke test cannot run until a real project exists (Pages itself is already enabled). They are linted (actionlint), their decision logic is unit-tested, and `check_workflows.py` checks every script name and option used in a `run:` step (`WF017`), but they have never executed end to end. The same holds for the YAML glue of the other three Godot jobs (see the Status section).
- Gamepad input cannot be automated in the browser smoke test. The "input effect" check uses keyboard events only and warns (does not fail) unless `require_input_effect` is set in `scripts/ci/smoke/smoke-config.json`.
- The pixel check proves that the canvas is not uniform. It cannot prove that the picture is correct.
- The live build uses the debug template (slower than release). A separate release export is out of scope for Order 01.
- GUT is verified against Godot 4.7.2; the gdUnit4 command line is taken from its sources and is unverified against a real project.
