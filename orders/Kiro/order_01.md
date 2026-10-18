# ORDER 01 — Bootstrap Godot CI and Live Browser Deployment

- **Agent:** Kiro
- **Status:** QUEUED — begin immediately when read
- **Priority:** P0
- **Owner:** Kiro
- **Dependencies:** Coordinate with gameplay owner and Codex; avoid modifying their assigned art assets.

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
- [ ] Actual Godot project and export preset identified.
- [ ] Real engine CI runs and passes on the project.
- [ ] Web export artifact is produced and validated.
- [ ] Deployment publishes to a known test URL after passing checks.
- [ ] Live browser smoke test verifies actual game startup.
- [ ] Documentation explains branch protection/status check setup and any admin-only steps.
- [ ] Job report in `orders/Kiro/reports/` includes exact commands, results, commits, issues, questions, and URL/build evidence.

## Mandatory process
Start immediately on reading. Test before committing. Prepare the job report, commit through the reviewed workflow, publish and verify the live test build without waiting for another prompt, then update the report and order status. If blocked by missing project/permissions, record the blocker and request the specific dependency rather than claiming success.
