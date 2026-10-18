# ORDER 01 — Bootstrap Godot CI and Live Browser Deployment

- **Agent:** Kiro
- **Status:** IN_PROGRESS — stage 2 of 2: PR open, first deployment pending. Stage 1 (CI/deploy pipeline) is merged ([PR #4](https://github.com/kiotdstudios/shinobi-rush/pull/4), merge commit 5dcad32). Stage 2 = minimal real Godot project at the repo root (placeholder art only) + first live deployment, separate PR. The status is set to DONE by the orchestrator after it has verified the live build, not by this step. See [Status log](#status-log)
- **Priority:** P0
- **Owner:** Kiro
- **Branch/PR:** stage 1: `kiro/order-01-godot-ci-deploy` — [PR #4](https://github.com/kiotdstudios/shinobi-rush/pull/4) (merged). Stage 2: `kiro/order-01-stage2-godot-project` — PR link is added in a report-only follow-up commit once the PR exists.
- **Dependencies:** Coordinate with gameplay owner and Codex; avoid modifying their assigned art assets. **Resolved 2026-10-17:** the project owner answered "yes" to building a minimal real Godot project and playable scene, so the bootstrap is explicitly **reassigned to Kiro** (`orders/README.md`, rule 4) and delivered as **stage 2** in a separate follow-up PR after stage 1 is merged. Codex keeps the art under `assets/`; Kiro does not modify it.

## Objective
Turn Shinobi Rush's existing repository checks into a **real automated Godot 4 validation → Web export → live browser deployment → smoke-test** pipeline. No additional prompt is needed. This is infrastructure work; do not invent a working game or live URL.

## Existing baseline
- `.github/workflows/repository-checks.yml` validates repo instructions and checks for a Godot project.
- `scripts/ci/validate_orders.py` validates agent order structure.
- `.github/pull_request_template.md` captures testing and deployment evidence.
- [GitHub workflow recommendations](../../docs/development/GITHUB_WORKFLOW_RECOMMENDATIONS.md).
- [Godot browser testing skill](../../skills/godot-browser-testing/SKILL.md).

## Scope
1. Inspect the repository thoroughly for the **actual** Godot project root, Godot version, main scene, Web export preset, current hosting, and existing deployment pipeline. Do not assume a location.
2. If the game project does not yet exist, coordinate with the gameplay agent to bootstrap a minimal real Godot 4 project and playable scene, or mark the dependency BLOCKED with exact handoff needed. **Do not deploy a fake placeholder as the game.**
3. Add CI that imports the real project headlessly, validates scenes/scripts, runs available tests, and produces a **single-threaded Compatibility-renderer Godot Web export**. Pin engine version and export templates together.
4. Add live-test deployment on successful integration to main using the **existing host if one is configured**; otherwise propose GitHub Pages as the default and document the required Pages/permissions setup. Never overwrite a separate production site without explicit authorization.
5. Add a real browser smoke test: open the deployed URL, verify canvas/game startup, controls where automatable, and no fatal console errors. Store evidence/logs and deployment SHA.
6. Ensure failing tests block deployment; never mark the job done when the project is missing, CI skipped, or deployment unverified.
7. Preserve PR reviews/branch protections and minimal permissions; do not force-push main or expose tokens.

## Acceptance criteria
- [x] Actual Godot project and export preset identified. — **MET (local evidence):** `project.godot` and `export_presets.cfg` (preset `Web`, single-threaded) are at the repository root. `python scripts/ci/validate_godot_project.py --project c:\shinobi-rush --repo-root c:\shinobi-rush` reported PASS, 0 errors, 0 warnings (engine 4.7.x), and the export used that preset (stage 2 report, tests table). The CI `detect` job confirming `project_dir=.` is pending the CI run.
- [ ] Real engine CI runs and passes on the project. — **NOT MET (pending CI run):** locally, on Windows with Godot 4.7.2, import, resource validation (11 scripts, 3 scenes, 0 failures) and the project's tests (123 passed, 0 failed) pass. The jobs have not yet run on a GitHub runner against the project: run URLs are added by the CI step; no box is ticked on local evidence alone.
- [ ] Web export artifact is produced and validated. — **NOT MET (pending CI run):** produced and validated locally (`godot_ci.py export`, `finalize-export --kind game`, `check-export` all rc=0, 36 MiB). The GitHub-run artifact is pending.
- [ ] Deployment publishes to a known test URL after passing checks. — **NOT MET (first deployment pending):** nothing is deployed. GitHub Pages is enabled (2026-10-18, by the orchestrator with the owner's authorization, not by this PR/CI) and the site answers HTTP 404 until the push-to-`main` run after the merge. The expected-but-unverified URL is `https://kiotdstudios.github.io/shinobi-rush/`.
- [ ] Live browser smoke test verifies actual game startup. — **NOT MET (live part pending):** `smoke.mjs` and the controls probe passed in real Chromium against the local export (VERDICT PASS both), which is not the live URL. The post-deploy smoke test has not run.
- [ ] Documentation explains branch protection/status check setup and any admin-only steps. — **DOCUMENTED; left unticked, pending the admin step:** [GODOT_CI_AND_DEPLOYMENT.md](../../docs/development/GODOT_CI_AND_DEPLOYMENT.md) and [GODOT_PROJECT_HANDOFF.md](../../docs/development/GODOT_PROJECT_HANDOFF.md) are updated for the real project (`.gdignore` files, test runner, manifest validator, controls probe, failing-job meanings, first deployment, rollback). Adding the Godot gate to the ruleset's required checks is still a manual administrator step, recommended after the first green `main` run.
- [ ] Job report in `orders/Kiro/reports/` includes exact commands, results, commits, issues, questions, and URL/build evidence. — **PARTIAL (URL/build evidence pending):** [2026-10-18-minimal-godot-project-and-first-deploy-report.md](reports/2026-10-18-minimal-godot-project-and-first-deploy-report.md) (stage 2) has the local commands and results; run URLs, PR link, SHAs and the live URL/build evidence are added later. It states "Live deployment: PENDING". Stage 1: [2026-10-18-bootstrap-godot-ci-deploy-report.md](reports/2026-10-18-bootstrap-godot-ci-deploy-report.md).

## Mandatory process
Start immediately on reading. Test before committing. Prepare the job report, commit through the reviewed workflow, publish and verify the live test build without waiting for another prompt, then update the report and order status. If blocked by missing project/permissions, record the blocker and request the specific dependency rather than claiming success.

## Status log
**2026-10-18 — IN_PROGRESS: stage 2 of 2: PR open, first deployment pending. Live deployment: PENDING (deploys on merge to `main`; verified separately by the orchestrator).**
- **Stage 2 (this pull request, branch `kiro/order-01-stage2-godot-project`):** a minimal real Godot 4.7.2 project at the repository root with **placeholder art only**, the sprite drop-in contract for Codex (128x128 is the documented production default), the built-in test runner, the sprite manifest validator, the controls probe and the PCK content check, plus stage 1 review follow-ups. The only file under `assets/` is the empty `assets/characters/player/references/.gdignore`. Not verified: controller hardware, DualSense in browsers, Safari/mobile, real art, 60 FPS on a real GPU. Details and local evidence: [stage 2 report](reports/2026-10-18-minimal-godot-project-and-first-deploy-report.md).
- The orchestrator, not this order's agent, sets DONE after it has verified the live build.

**Earlier entry — 2026-10-18, stage 1 (PR #4, merged): CI/deploy pipeline delivered, live deployment NOT PERFORMED at that time (no project yet).**
- Delivered in [PR #4](https://github.com/kiotdstudios/shinobi-rush/pull/4): pinned Godot 4 CI (`.github/workflows/godot-ci.yml`), a pipeline self-test (`pipeline-self-test.yml`), shared tooling and unit tests (`scripts/ci/`), a Playwright browser smoke test, and two documents. Without a project every Godot job is skipped and `godot-ci-gate` reports **NOT VALIDATED, NOT DEPLOYED** loudly; deployment can never run. Those skipped jobs have never executed on a runner, so their first real run is the stage 2 pull request. Stage 1 commits no Godot project, scene, GDScript file or `.gdignore`.
- **2026-10-17 — bootstrap reassigned to Kiro (project owner):** asked "Do you want me to build a minimal real Godot project and playable scene?", the project owner answered "yes". That satisfies `orders/README.md` rule 4 (explicit reassignment). **Stage 2** (separate follow-up PR, after stage 1 is merged): a minimal real Godot 4.7.x project at the repository root (the locked architecture, section 11 of `docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md`), GL Compatibility, a single-threaded Web export preset named `Web`, the first live deployment and its smoke test. Layout and `.gdignore` list: [GODOT_PROJECT_HANDOFF.md](../../docs/development/GODOT_PROJECT_HANDOFF.md).
- **2026-10-18 — GitHub Pages enabled and merge authorized (project owner, via the orchestrator):** Pages enabled by the orchestrator with the owner's authorization on 2026-10-18 (not by this PR/CI); still NOT DEPLOYED (no project yet). The `github-pages` environment exists with a main-only deployment branch policy ([admin steps](../../docs/development/GODOT_CI_AND_DEPLOYMENT.md#admin-only-steps)). The owner also authorized the orchestrator (not the workflow agents) to merge this pull request once every check is green and the review approved it.
- Still open (job report): adding the new Godot check(s) to the required status checks after stage 2 has proven them (manual admin step).

**Definition of DONE for this order:** the unticked criteria above are ticked by someone who has seen the evidence: a real project passed `Godot CI` on a pull request, a push to `main` deployed it, and the post-deploy smoke test confirmed the live URL serves that commit.

## Handoff / notes
- Reports: `orders/Kiro/reports/`.
- Not touched by this order (other agents' areas): `orders/Aki`, `orders/Orcha`, `orders/Codex`, `assets/` (single exception: the empty marker `assets/characters/player/references/.gdignore`), `docs/visuals/`, `docs/prototype/`, `world/`, `skills/three-quarter-game-art/`, `.github/pull_request_template.md`, and the files of the other open PRs (#1, #2, #3).
