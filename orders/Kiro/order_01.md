# ORDER 01 — Bootstrap Godot CI and Live Browser Deployment

- **Agent:** Kiro
- **Status:** IN_PROGRESS — Stage 1 of 2 delivered (CI/deploy pipeline). Stage 2 = minimal real Godot project at the repo root + first live deployment, separate PR. (ubuntu-24.04 CI results are pending until the first run of this PR; the report-only follow-up commit replaces this text) See [Status log](#status-log)
- **Priority:** P0
- **Owner:** Kiro
- **Branch/PR:** `kiro/order-01-godot-ci-deploy` — pull request pending (it is opened right after this commit; the report-only follow-up commit adds its number and link) — stage 1 of 2
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
- [ ] Actual Godot project and export preset identified. — **NOT MET (pending stage 2):** none exists on any branch (searched for `project.godot`, `.tscn`, `.gd`, `export_presets.cfg`). Discovery runs at CI time and will identify the project, at the repository root, the moment stage 2 lands it.
- [ ] Real engine CI runs and passes on the project. — **NOT MET (pending stage 2):** `godot-ci.yml` is implemented, but its Godot jobs (`build`, `smoke-predeploy`, `deploy`, `smoke-postdeploy`) have never run on a runner at all: they are skipped while no project exists. The pipeline self-test passes on generated throwaway projects (Windows locally; ubuntu-24.04 results are pending until the first run of this PR and are added by the report-only follow-up commit); that is tooling verification, not this criterion.
- [ ] Web export artifact is produced and validated. — **NOT MET (pending stage 2):** the self-test exported and validated throwaway fixtures only; no game export exists.
- [ ] Deployment publishes to a known test URL after passing checks. — **NOT MET (pending stage 2):** nothing was deployed. GitHub Pages is enabled (2026-10-18, by the orchestrator with the owner's authorization, not by this PR/CI) but the site answers HTTP 404 until the first deployment, which needs the stage 2 project. The expected-but-unverified URL is `https://kiotdstudios.github.io/shinobi-rush/`.
- [ ] Live browser smoke test verifies actual game startup. — **NOT MET (live part pending stage 2):** there is no game and no live URL. The harness itself (local server, Playwright, readiness hook, console policy) was verified against throwaway fixtures only.
- [ ] Documentation explains branch protection/status check setup and any admin-only steps. — **STAGE 1 DELIVERED; left unticked, pending stage 2:** [GODOT_CI_AND_DEPLOYMENT.md](../../docs/development/GODOT_CI_AND_DEPLOYMENT.md) and [GODOT_PROJECT_HANDOFF.md](../../docs/development/GODOT_PROJECT_HANDOFF.md) (repository-root convention and `.gdignore` list included). Documentation only: no admin step was executed or verified; the live part (Pages enabled, required check added) is pending stage 2.
- [ ] Job report in `orders/Kiro/reports/` includes exact commands, results, commits, issues, questions, and URL/build evidence. — **PARTIAL (stage 1 delivered; URL/build evidence pending stage 2):** [2026-10-18-bootstrap-godot-ci-deploy-report.md](reports/2026-10-18-bootstrap-godot-ci-deploy-report.md) has the commands, results, commits, issues and questions of stage 1; URL/build evidence cannot exist until stage 2 deploys something, and the report states "Live deployment: NOT PERFORMED" explicitly.

## Mandatory process
Start immediately on reading. Test before committing. Prepare the job report, commit through the reviewed workflow, publish and verify the live test build without waiting for another prompt, then update the report and order status. If blocked by missing project/permissions, record the blocker and request the specific dependency rather than claiming success.

## Status log
**2026-10-18 — IN_PROGRESS: stage 1 of 2 delivered (CI/deploy pipeline). Live deployment: NOT PERFORMED (stage 2, the project bootstrap, is not yet delivered).**
- Delivered on branch `kiro/order-01-godot-ci-deploy` (the pull request is opened right after this commit; its number and link are added by the report-only follow-up commit): pinned Godot 4 CI (`.github/workflows/godot-ci.yml`), a pipeline self-test (`pipeline-self-test.yml`), shared tooling and unit tests (`scripts/ci/`), a Playwright browser smoke test, and two documents. Without a project every Godot job is skipped and `godot-ci-gate` reports **NOT VALIDATED, NOT DEPLOYED** loudly; deployment can never run. Those skipped jobs have never executed on a runner, so their first real run is the stage 2 pull request. Stage 1 commits no Godot project, scene, GDScript file or `.gdignore`.
- **2026-10-17 — bootstrap reassigned to Kiro (project owner):** asked "Do you want me to build a minimal real Godot project and playable scene?", the project owner answered "yes". That satisfies `orders/README.md` rule 4 (explicit reassignment). **Stage 2** (separate follow-up PR, after stage 1 is merged): a minimal real Godot 4.7.x project at the repository root (the locked architecture, section 11 of `docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md`), GL Compatibility, a single-threaded Web export preset named `Web`, the first live deployment and its smoke test. Layout and `.gdignore` list: [GODOT_PROJECT_HANDOFF.md](../../docs/development/GODOT_PROJECT_HANDOFF.md).
- **2026-10-18 — GitHub Pages enabled and merge authorized (project owner, via the orchestrator):** Pages enabled by the orchestrator with the owner's authorization on 2026-10-18 (not by this PR/CI); still NOT DEPLOYED (no project yet). The `github-pages` environment exists with a main-only deployment branch policy ([admin steps](../../docs/development/GODOT_CI_AND_DEPLOYMENT.md#admin-only-steps)). The owner also authorized the orchestrator (not the workflow agents) to merge this pull request once every check is green and the review approved it.
- Still open (job report): adding the new Godot check(s) to the required status checks after stage 2 has proven them (manual admin step).

**Definition of DONE for this order:** the seven unchecked criteria above are ticked by someone who has seen the evidence (stage 2): a real project passed `Godot CI` on a pull request, a push to `main` deployed it, and the post-deploy smoke test confirmed the live URL serves that commit.

## Handoff / notes
- Reports: `orders/Kiro/reports/`.
- Not touched by this order (other agents' areas): `orders/Aki`, `orders/Orcha`, `orders/Codex`, `assets/`, `docs/visuals/`, `docs/prototype/`, `world/`, `skills/three-quarter-game-art/`, `.github/pull_request_template.md`, and the files of the other open PRs (#1, #2, #3).
