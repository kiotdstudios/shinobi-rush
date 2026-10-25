# ORDER — Recoverable physical kunai pickups
- Agent: Codex
- Owner: Codex
- Status: IN_PROGRESS
- Priority: P1
- Branch/PR: codex/recoverable-kunai
- Dependencies: approved black kunai, gourd pickup/inventory, player and bandit projectiles

## Objective
Make kunai obtainable like gourds/paper tags with white glow and recoverable after misses or accessible surface impacts.

## Context / References
Direct owner request: character hit applies damage and consumes projectile without pickup; wall/tree hit briefly embeds then recovers only on accessible ground; miss falls, tumbles, bounces once/twice, clinks and rests as collectible. Use existing isometric black kunai asset, no redesign.

## Scope / Files owned
Explicit requested item integration in HealthGourd/GourdPickupFx, player/bandit projectile outcomes, new physical recovery visual, builder entry and isolated review. Preserve attack/AI/controller systems and current damage/evade/substitution decisions.

## Deliverables
White-glow kunai pickup, physical miss/surface recovery, metallic sound, accessible-ground checks, regression tests, preview, reviewed PR and verified canonical deployment.

## Acceptance Criteria / Tests
No drops on character damage. Recoverable misses refund one ammo only once, never respawn. Surface recovery cannot place inside/through collision or on unreachable ground. Authored builder kunai shares normal pickup effect/respawn. Verify actor-vs-wall hit order, range clamping, bounce/settle, both projectile owners, full bag, collection sound/glow, native and Web tests.

## Handoff / Notes
Reuse approved PNG with code-driven nearest-filtered rigid-body motion; no new AI bitmap generation required. This owner request supersedes unrelated historical queued art orders.
