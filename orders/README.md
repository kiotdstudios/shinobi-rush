# Agent Orders — Shinobi Rush

This directory is the **single source of truth for agent work orders**. Each agent has a dedicated inbox:

- [Aki](./Aki/README.md) — `orders/Aki/`
- [Orcha](./Orcha/README.md) — `orders/Orcha/`
- [Kiro](./Kiro/README.md) — `orders/Kiro/`

## Operating rules
1. Put each new task in the assigned agent's folder as a separate Markdown file named `YYYY-MM-DD-short-task-name.md`.
2. Every order must specify **Objective, Context/References, Scope, Deliverables, Acceptance Criteria, Dependencies, and Status**.
3. Agents should read this README and their folder README before starting work.
4. Agents must not implement tasks assigned to another agent unless explicitly reassigned. Flag overlapping files or systems before editing.
5. Status values: `QUEUED`, `IN_PROGRESS`, `BLOCKED`, `REVIEW`, `DONE`. Update the order when work changes status; include PR/commit links and test evidence.
6. Keep work on dedicated branches/PRs when multiple agents are active. Avoid direct concurrent edits to `main`. Only merge after review and testing.
7. Respect locked gameplay/visual decisions. Read [Codex player handoff](../docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md), [baseline character](../docs/prototype/BASELINE_PLAYER_CHARACTER.md), and the latest [world/gameplay rules](../world/maps/MVP_WORLD_MAP.md) where relevant.
8. **Do not assume an order is active merely because it exists.** Work begins only when explicitly assigned.
9. When a task spans multiple agents, designate one owner and list collaborators and handoff artifacts.
10. Never overwrite another agent's work or mark an untested feature complete.

## Order template
```md
# ORDER — Task title
- Agent: Aki / Orcha / Kiro
- Status: QUEUED
- Priority: P0 / P1 / P2
- Owner: agent name
- Branch/PR:
- Dependencies:

## Objective

## Context / References

## Scope / Files owned

## Deliverables

## Acceptance Criteria / Tests

## Handoff / Notes
```


## Mandatory pre-commit testing and post-job report

**These rules apply to Aki, Orcha, Kiro, and any future agent on every job.**

### Before committing any implementation
1. Review the assigned order, its acceptance criteria, and affected systems.
2. Run the relevant automated tests and build/export checks. For gameplay changes, actually launch and playtest the feature, including the Godot Web build when the task affects browser playability.
3. Check for regressions, console/runtime errors, broken controls, missing assets, and related functionality.
4. Record exact commands, environment, observed results, and any tests that could not be run. Never claim a test passed if it was not executed.
5. Fix failures and retest **before committing**. If a test cannot be performed or a known failure remains, mark the order `BLOCKED` or `REVIEW` as appropriate, document the limitation, and request approval before committing incomplete work. Do not silently commit broken code.
6. Commit only tested changes; reference the order in the commit/PR. Re-run checks after integration if merge introduces changes.

### Required report after EVERY job
Create a report in **your own agent folder** at `orders/<Agent>/reports/YYYY-MM-DD-task-name-report.md`. The report is required even for a blocked or incomplete job. It must include:
- **Order / Agent / Date / Final status**
- **Work completed:** detailed description of what was built, changed, removed, or configured
- **Files changed:** paths and important implementation decisions
- **Tests performed BEFORE commit:** exact commands or manual steps, pass/fail results, browser/playtest observations, and evidence (logs/screenshots if available)
- **Issues encountered:** bugs, blockers, regressions, workarounds, remaining risks; explicitly write "None" if there were none
- **Questions for the project owner:** decisions or clarifications needed; explicitly write "None" if there are none
- **Outstanding work / recommended next steps**
- **Commit SHA / PR link** (or "Not committed" and why)

Write the report **before the implementation commit** with the test evidence, then add the commit SHA/PR link as a follow-up report-only update if needed. Do not mark the order `DONE` until the report exists and the work has passed its acceptance checks. Reports must be honest, actionable, and easy for another agent to read.

### Report template
```md
# Job Report — Task title
- Agent:
- Order:
- Date:
- Final status:
- Commit / PR:

## Work completed

## Files changed

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |

## Issues encountered
None / details

## Questions for project owner
None / details

## Outstanding work / next steps
```
