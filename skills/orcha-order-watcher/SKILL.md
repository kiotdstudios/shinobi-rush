---
name: orcha-order-watcher
description: Check Orcha's GitHub work-order inbox every 10 minutes and surface actionable queued orders without pretending to wake an AI session.
---

# Orcha Order Watcher

## Purpose
Check `orders/Orcha/` for new work at 10-minute intervals. A GitHub Actions cron job is the scheduler; this SKILL.md tells Orcha how to consume the results. **GitHub Actions cannot wake or run an external AI agent without an explicitly connected agent runtime.**

## Source of truth
- Only `main` is an active order inbox. Orders on unmerged PR branches are not active.
- Read `orders/README.md` and `orders/Orcha/README.md` first.
- Read each `orders/Orcha/YYYY-MM-DD-*.md` and inspect `Status`, `Priority`, dependencies, and ownership.
- Ignore `README.md`, `reports/`, other agents' folders, and any `DONE` or `REVIEW` tasks.
- Treat `QUEUED` as actionable; `BLOCKED` as requiring resolution. `IN_PROGRESS` is already underway.
- Prioritize P0, then P1, then P2, then oldest dated order. Never execute duplicate or superseded assignments.

## Automation
Workflow: `.github/workflows/orcha-order-watcher.yml`
Script: `scripts/automation/orcha_order_watcher.py`
Schedule: `*/10 * * * *` (UTC, approximately every ten minutes; GitHub may delay or drop scheduled runs).
The workflow reads `main`, scans orders, and maintains **one deduplicated GitHub issue** titled `[Orcha Watcher] Queued orders`. It updates that issue only when its actionable content changes, and closes it when the queue empties. Manual `workflow_dispatch` is supported.

## When Orcha is active
1. At session start, check the issue and current `main` orders; do not trust a stale issue.
2. For the highest-priority `QUEUED` order, set status `IN_PROGRESS` on your implementation branch and start without another owner prompt.
3. Follow branch/PR, pre-commit tests, Godot Web smoke/playtest, report, merge/deploy/live verification rules from `orders/README.md`.
4. Never claim a task completed or deployed because the watcher saw it.
5. If the runtime supports an authenticated unattended-agent webhook in the future, that integration requires separate owner approval and secret management. Do not add credentials, unattended code execution, or self-triggering workflows here.

## Reliability and safety
- GitHub Actions schedules are best effort, not an exact 600-second timer.
- The GitHub issue is an alert/queue summary, not a work authorization beyond the original order.
- No force merges, branch protection bypass, paid PixelLab usage, or production gameplay changes from this watcher.
- Do not expose tokens in logs. Workflow uses built-in `GITHUB_TOKEN` with `contents: read`, `issues: write`.
- If repository issue creation is disabled or token permissions insufficient, the job fails visibly in Actions rather than falsely reporting success.
