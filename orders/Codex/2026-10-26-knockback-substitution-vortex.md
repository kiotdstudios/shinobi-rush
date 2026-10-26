# ORDER — Knockback impacts and substitution smoke vortex
- Agent: Codex
- Owner: Codex
- Status: REVIEW
- Priority: P1 — scheduled owner request at 2026-10-26 05:00 America/New_York
- Branch/PR: codex/impact-vortex (waterlife PR213 preserved separately).
- Dependencies: Existing damage and substitution presentation; preserve gameplay ownership.

## Objective
Add premium knockback VFX, readable impact frames and a smoke vortex wrapping the substitution log as it wobbles, drops, bounces and disappears.

## Context / References
Direct owner request repeated twice (one assignment). Existing 8-direction player/bandit knockback art and substitution log motion already exist; audit before replacement. Waterlife work began at the earlier scheduled time and remains active.

## Scope / Files owned
Art/VFX presentation only; preserve movement, combat timings, invulnerability, L2 tap substitution / hold charge and teleport behavior. Keep the log collider timing intact.

## Deliverables
Separate transparent VFX, integration metadata, contact sheets and normal/half-speed previews; tested PR, report and live verification for runtime changes.

## Acceptance Criteria / Tests
No visual glitches or gameplay regressions; consistent pixel scale/palette, smoke layered in front of and behind the log, distinct impact/settling/dissipation phases. Follow required native/browser checks and normal reviewed integration.

## Handoff / Notes
Do not duplicate this repeated request. Complete active waterlife delivery, then execute this assignment in a separate branch.
