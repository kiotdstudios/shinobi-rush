---
name: multi-agent-integration
description: Safely coordinate parallel GitHub agent work, file ownership, PR review, tests, live deployment, and per-job reports for Shinobi Rush.
---
# Multi-agent integration

1. Read `AGENTS.md`, `orders/README.md`, your own inbox, and the exact assigned order. Start assigned QUEUED work immediately; mark IN_PROGRESS.
2. Identify owner, changed files, dependencies, and overlapping work before editing. Use dedicated branches named `agent/task-short-name`; never force-push main.
3. Commit only after running and documenting relevant tests. Include task identifier in PR and commit messages.
4. Merge/integrate through required review and CI. Do not bypass branch protections for speed.
5. Deploy integrated runtime changes to the actual live browser test game automatically and smoke-test; mark blocked if missing configuration or permissions.
6. Write `orders/<Agent>/reports/YYYY-MM-DD-task-report.md` after each job, with work summary, file list, actual test results, issues, questions, next steps, commit/PR, and deployment result.
7. Update order status to DONE only after acceptance checks, live verification where applicable, and report completion.
