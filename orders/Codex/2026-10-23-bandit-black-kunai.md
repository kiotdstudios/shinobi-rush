# ORDER — Use real black kunai for bandit throws
- Agent: Codex
- Owner: Codex, direct owner assignment
- Status: DONE
- Priority: P0
- Branch/PR: codex/bandit-black-kunai / https://github.com/kiotdstudios/shinobi-rush/pull/134
- Dependencies: existing assets/weapons/kunai/black_kunai.png

## Objective
Replace the silver/white bandit projectile placeholder with the existing approved black kunai.
## Context / References
Owner2026-10-23 requests real asset. Shared black kunai authored previously for both characters; source blade points +X.
## Scope / Files owned
Bandit projectile presentation only, native scale/nearest sampling, travel-direction rotation at existing hand-height lift. Do not change speed, damage, collision, throw timing or substitution.
## Deliverables
Real texture bound to thrown projectile, tests/browser evidence, own report and reviewed PR/live verification.
## Acceptance Criteria / Tests
Black asset visible and aligned to travel; no old procedural silver blade. Existing flight/hit/evade/substitution/wall/range and throw tests pass; Godot import/Web export; browser playtest and deployed build verification.
## Handoff / Notes
No new generated art needed. Approved existing asset reused.

Mergedb53651d; Pages deployment succeeded and exact live SHA/normal-play bandit throw verified2026-10-23 13:15EDT.2092native checks passed; see own report and live screenshot evidence.
