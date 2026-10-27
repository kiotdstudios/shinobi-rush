# ORDER — scheduled 3:40 AM open-PR review and integration
- Agent / Owner: Codex
- Status: DONE — all nine source PRs merged through PR231; 3876/0 native; main deployment/postdeploy passed; canonical exact-SHA gameplay and terrain verified.
- Branch: codex/2026-10-27-pr-integration
- Dependencies: current main, all nine open PR heads, required checks and deployment.

## Objective
Execute the owner's one-time October 27, 2026 3:40 AM America/New_York request: review remaining PRs, resolve questions from existing evidence, fix failures, push and integrate through the approved process.

## Context / References
Heartbeat `finish-open-shinobi-rush-prs`; PRs 35, 36, 176, 220, 226, 227, 228, 229, 230; AGENTS and orders README. Snapshot and exact heads: `docs/reviews/2026-10-27-open-pr-audit.json`.

## Scope / Deliverables
Review all open PRs, preserve source branches, integrate natural dirt parent before its transition child, archive isolated art studies without promoting unapproved art to gameplay, preserve story ideas as non-canon and Aki cliff specification as future work. Resolve gameplay conflicts and verified bugs, test combined native/Web build, publish a reviewed integration PR and verify exact canonical deployment. Never alter protection settings or fabricate checks.

## Acceptance criteria
Combined source imports and native tests pass, real Web input/visual checks pass, every source PR accounted for, normal required CI succeeds, merge reaches main and deploy/postdeploy pass. Canonical exact-SHA gameplay verification and complete report before DONE.

## Completion
[PR231](https://github.com/kiotdstudios/shinobi-rush/pull/231), merged `c4c336964e42e73a59b0b2984aa9aae57e4f15be`. [Main Godot CI 40477062807](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40477062807) passed including deploy and postdeploy. Canonical live checks: gameplay 7/7, natural path 9/9, path-to-dirt 4/4; no browser/engine errors. Evidence: `docs/reviews/2026-10-27-live-integration/`; full job report in `reports/2026-10-27-open-pr-integration-report.md`.
