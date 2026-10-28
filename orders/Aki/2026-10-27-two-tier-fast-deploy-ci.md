# Aki — P0 Two-Tier GitHub Actions Deployment Optimization

**Owner:** Aki
**Priority:** P0 / developer iteration speed
**Status:** DONE — implementation delivered and audited; PRs #251/#245 integrated as 090d8688, main deploy/postdeploy and 28/28 canonical checks passed. See orders/Codex/reports/2026-10-28-open-pr-completion-report.md. CI speed aspiration remains a measured follow-up.

## Goal
Reduce routine commit-to-live deployment time from ~25 minutes to a **measured target of 7–10 minutes**, while retaining essential pre-deployment browser verification and live post-deployment smoke verification. Keep the complete browser regression suite available and running nightly, on demand, and before major releases.

## Evidence — actual run
https://github.com/kiotdstudios/shinobi-rush/actions/runs/40425073235

Approximate timing from timestamped job logs:
- Import, validate, GDScript tests, Web export: ~5m24s
- Pre-deploy browser smoke: ~1m26s
- `controls-probe.mjs`: ~11m53s
- `debug-probe.mjs`: ~2m07s
- GitHub Pages deployment: ~36s
- Post-deploy live smoke: ~1m48s
- Total ~25m15s, including setup/transition time.

Specific hotspot: `vision-repeat-toggle-stable` does 12 on/off cycles (24 toggles) in headless Chromium, consuming ~3m08s. Browser probe reports headless rendering as slow as ~4–9 FPS. **Do not prioritize Godot import caching** as the primary fix; observed import is ~21s and export ~7s.

## Inspect before modifying
- `.github/workflows/godot-ci.yml`
- `.github/workflows/repository-checks.yml` and any branch protection / required status checks
- `scripts/ci/smoke/controls-probe.mjs`
- `scripts/ci/smoke/debug-probe.mjs`
- `scripts/ci/smoke/smoke.mjs`
- `scripts/ci/pages_gate.py`
- Workflow and deployment documentation

## Required workflow: FAST (every push / PR as appropriate)
1. Retain existing project discovery, pinned tool validation, Godot import, resource/script validation, GDScript tests, and **single Web export**.
2. Retain the existing pre-deploy browser smoke check: launch Godot Web build, verify ready hook, visible/nonblank canvas, fatal console errors, and basic input response. If the existing smoke test doesn't assert player movement, add one **short bounded movement assertion** using published state or a comparable reliable observable.
3. Deploy **the exact exported bytes** that passed the pre-deploy smoke; retain build SHA checks.
4. Retain post-deploy live smoke and SHA propagation verification.
5. Remove the *comprehensive* controls and debug probes from the routine deployment's **blocking critical path**, not from the repository.
6. Keep permissions, concurrency controls, branch conditions, pinned versions, artifact integrity, and the existing gate semantics. Update gate logic safely so it expects only the checks applicable to each tier; never fake a PASS or mask a failure.
7. Do not skip mandatory tests required by branch protection without coordinating required-check changes. If necessary keep a stable gate status with meaningful fast-tier checks and separately named full-regression status.

## Required workflow: FULL REGRESSION
- Run the existing complete `controls-probe.mjs` and `debug-probe.mjs` unchanged at first, plus appropriate Web smoke tests.
- Trigger via `workflow_dispatch` (manual), nightly `schedule` (UTC; document local equivalent), and an explicit major-release workflow or clearly documented manual release gate.
- Run full regression on a built artifact associated with a known SHA. Never accidentally test an unrelated latest deploy.
- Full regression failures must be visible, actionable, and not silently ignored; upload screenshots, logs, and evidence artifacts.
- If workflow duplication is a concern, extract a reusable workflow/composite action or common test script; avoid divergent build configuration.
- Consider parallelizing independent controls and debug jobs after the export; compare wall time and GitHub Actions consumption. Do not remove tests simply to hit the timing target.

## Safety / rollout
1. Benchmark at least 3 recent runs and capture stage durations.
2. Implement FAST and FULL with explicit documentation and labels.
3. Validate on a feature branch. Ensure PR workflows do not accidentally deploy Pages.
4. Run a full regression against the same SHA used for a FAST validation before enabling the new default.
5. Merge only after green checks and an owner review of changed required checks.
6. Benchmark at least 5 routine deployments and compare median / p90 against baseline. If regressions occur, document and revert as needed.
7. Document the tradeoff: a fast deployment no longer guarantees that the full camera/vision/debug suite passed for that exact push. For major releases, require the full suite to pass first.

## Acceptance criteria
- [ ] Routine pushes run full Godot build/tests, essential browser smoke, deploy, and live smoke.
- [ ] Routine pushes do not wait for comprehensive controls/debug probes.
- [ ] Complete controls/debug probes run nightly and via manual trigger.
- [ ] Full regression can be run for a specific SHA and has clear failure reporting.
- [ ] Full regression is required by documented release procedure.
- [ ] No silent failures, skipped required checks, broken branch protection, or deployment of unverified artifacts.
- [ ] Aki reports before/after timings and confirms the deployed site SHA matches the tested export.
- [ ] CI configuration changes and test evidence are included in implementation PR.

**Important:** This document is an assignment. Implement and validate the workflows on this branch or a linked implementation PR; do not mark the order as proof that CI is already optimized.
