# ORDER — Combat System V1 — Milestone A (Offensive Combat)
- Agent: Aki
- Status: IN_PROGRESS
- Priority: P0 — Core Gameplay
- Owner: Aki
- Branch/PR: aki/combat-v1-milestone-a / (PR TBD)
- Dependencies: fluid movement + action chaining (PR #29), dust-puff VFX (PR #30)

## Objective
Build the skill-based katana combat system described in the full "SHINOBI RUSH — COMBAT SYSTEM V1"
order (Hades fluidity + Ghost of Tsushima weight + Sekiro timing), split into three milestones per
the order's own instruction not to withhold a playable build until all three land. This order covers
**Milestone A only: offensive combat** — the 3-hit light combo, dash attack, movement-to-attack
chaining, and a Basic Bandit enemy that can take damage and die. Block/parry/posture (Milestone B)
and polish/debug-tools (Milestone C) are separate, later orders.

## Context / References
Full order text (Hades/Tsushima/Sekiro combat philosophy, required state list, frame-count tuning
table, dodge/dash-attack timing, block/parry/posture spec, hitstop targets, Basic Bandit spec, asset
audit requirement, playtest overlay, 10 delivery milestones, 10 acceptance tests) is preserved
verbatim in this session's own history; summarized decisions below.

## Scope / Files owned
- `scripts/combat/attack_def.gd` (new) — per-attack tuning data, matches the order's frame table.
- `scripts/player/player_controller.gd` — attack state machine (LIGHT1/2/3, DASH_ATTACK), combo
  chaining, dodge-cancel, dash-attack trigger windows, manual hit-arc check, local hitstop.
- `scripts/enemy/bandit.gd`, `scripts/enemy/bandit_visual.gd`, `scenes/enemy/bandit.tscn` (new) —
  Basic Bandit, Milestone A scope (idle/approach/hit-react/die only).
- `scripts/world_scale.gd` — added shared `snap8()` helper (was a private static on PlayerController).
- `scripts/arena/training_arena.gd` — spawns one Bandit near the player's spawn point.
- `tests/test_combat.gd` (new), `tests/run_tests.gd` — registration.
- Do not touch: block/parry/posture (none exist yet, by design), Kiro's camera code (impulse hook is
  Milestone C), production character artwork.

## Key decisions
- **No Area2D/collision-layer hitboxes.** Each attack's hit check is a manual geometric test (reach +
  forward arc around `facing8`) run during the attack's ACTIVE phase against the "enemy" group. Pure
  math, directly testable, and satisfies "hitboxes register accurately in every supported direction"
  by construction (the arc is defined in the same facing8 every other system already uses).
- **Local-only hitstop**, not `Engine.time_scale`. A `_hitstop_timer` on both the player and the
  Bandit pauses that entity's own velocity/position integration; buffers and attack timers elsewhere
  are untouched, per the order's explicit ban on a global freeze that would desync input buffering.
- **Combo chaining**: a buffered/fresh `attack_light` press within `combo_window` seconds of an
  attack's recovery starting cuts the remaining recovery short and begins the next hit (wraps
  light3 -> light1, no light4). Facing is locked for the whole combo once light1 begins; a fresh
  light1 (not a continuation) re-aims to current input, matching "run -> attack" chaining.
- **Dash attack** triggers two ways: pressing attack in the last `dash_attack_late_window` seconds of
  an active dodge (cancels the dodge outright), or within `dash_attack_post_grace` seconds after a
  dodge ends. Both are short (0.08s / 0.15s) so a deliberate plain light1 thrown a beat later is
  unaffected — required for the "ATTACK -> DODGE -> ATTACK" sequence to land a plain light1, not a
  dash attack, after the dodge has clearly finished.
- **Dodge-cancel**: once an attack's recovery has committed past `dodge_cancel_from`, a buffered/fresh
  dodge press cancels the remaining recovery and begins a normal dodge (velocity preserved).
- **Zero new art required.** `PlayerVisual.play_action()` already falls back to the procedural
  placeholder when an animation id is missing, so Milestone A ships gameplay-complete with
  placeholder visuals for every new player action and for the Bandit (which has no character art of
  any kind yet). See the matching Codex art request filed alongside this order.
- Player does not yet take damage / have HP — out of scope per the order's own milestone split (the
  Bandit doesn't attack until Milestone B).

## Deliverables
- PR with the above files, CI green (import + full test suite, baseline 514 + new combat coverage).
- Browser-playable export + smoke test.
- Codex art request for all missing combat animations (player + Bandit).
- This order + its completion report.

## Acceptance Criteria / Tests
Of the order's 10 acceptance tests, Milestone A covers (new tests in `tests/test_combat.gd`):
1. Run -> 3-hit combo -> run, no idle pause.
2. Dodge -> dash attack without stopping.
3. Dodge-cancel an eligible attack's recovery without bypassing collision.
7. Attack hitboxes register via the same forward-arc check regardless of facing direction.
8. Repeated/mashed inputs don't restart the active attack or skip ahead.
9. Movement/jump/dodge remain functional (existing 514-test baseline, unchanged).
Plus: a Bandit takes exactly one hit per swing and dies at 0 HP; ATTACK -> DODGE -> ATTACK sequence.
Tests 4-6 (parry/posture/guard-break) and 10 (camera/occlusion unchanged, informally verified not
regressed) are Milestone B/C scope.

## Handoff / Notes
See the matching report in `orders/Aki/reports/` for file-by-file detail, test results, and the
Codex art request this order produced.
