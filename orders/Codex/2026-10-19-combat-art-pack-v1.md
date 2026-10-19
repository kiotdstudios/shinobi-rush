# ORDER — Combat Art Pack V1
- Agent: Codex
- Owner: Codex; collaborator: Aki (gameplay timing and integration)
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/combat-art-pack-v1
- Dependencies: Aki's combat configuration and animation event contract

## Objective
Produce original katana combat art preserving the approved player design at native 128×128 RGBA, eight directions, anchor [64,116], no floor shadows. The owner's new combat instruction explicitly permits a katana for these clips, superseding older no-sword guidance within this order only.

## Context / References
Owner's Combat Art Pack V1 request; approved baseline turnaround; camera/art direction; current player_128 manifest; inventory and Aki handoff in reports/2026-10-19-combat-art-inventory-report.md.

## Scope / Files owned
Player combat sprites, independent VFX, animation metadata, previews, Codex reports. Do not edit Aki's combat state machine or Kiro's camera. Preserve approved locomotion assets.

## Deliverables
First PR: light_attack_1, light_attack_2, light_attack_3, dash_attack in S SE E NE N NW W SW, manifest, independent offensive VFX, previews and Aki integration notes. Follow-up PR: block_idle, perfect_parry, hit_reaction, guard_break, finisher, death and associated VFX.

## Acceptance Criteria / Tests
Inventory delivered to Aki before generation. Coordinate frame events/FPS with gameplay configuration. Verify native canvas, transparency, stable proportions/anchors, consecutive sword motion, purposeful unique poses, combo transitions, all directions, Godot import and browser preview. Report tests before committing; reviewed integration and live verification when runtime-visible.

## Handoff / Notes
Inventory complete against ce81f6d. No combat configuration exists on this main snapshot. Proposed IDs require Aki confirmation before runtime binding; production event indices remain unset until clips are inspected and gameplay timings agreed.

## Owner scope revision — modular proof first
Owner stopped full-pack expansion after the current sword animation. The southeast finisher is completed as a native128 comparison reference, with eight unique frames and no baked trail; the full southeast three-hit comparison contains24 frames. Further directions and weapon types are deferred until the modular proof passes. Existing queued generation results are source experiments only, not production-approved assets. New work: orders/Codex/2026-10-19-modular-weapon-art-poc.md on codex/modular-weapon-art-poc. This order is not marked DONE because the original eight-direction pack was not delivered.
