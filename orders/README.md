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
