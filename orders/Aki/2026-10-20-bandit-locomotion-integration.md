# ORDER — Integrate approved red-scarf bandit locomotion
- Agent: Aki
- Owner: Aki (runtime); Codex (art)
- Status: QUEUED
- Priority: P1
- Branch/PR: Codex art branch codex/bandit-locomotion; runtime branch chosen by Aki
- Dependencies: Codex bandit art PR reviewed/accepted and integrated

## Objective
Replace the procedural bandit appearance with the owner's new masked red-scarf/topknot design using the delivered 128px idle, regular run and arms-back ninja sprint. No logos.

## Context / References
assets/characters/bandit/INTEGRATION_NOTES.md and bandit_128.art.json. Eight directions S/SE/E/NE/N/NW/W/SW, foot anchor [64,116], body height 104. Each clip carries FPS and authored-FPS metadata. Existing enemy behavior and camera remain owned by gameplay agents.

## Scope / Files owned
Aki owns BanditVisual integration and state-to-animation mapping. Keep the player's production sprite selection unchanged. SpriteLibrary scans *.manifest.json and first_valid sorts by id, so the new bandit data deliberately uses *.art.json for explicit binding. Do not rename it into auto-discovery without fixing/verifying actor-specific selection.

## Deliverables
Explicit enemy-only sprite binding, idle/approach mapping to idle/run, sprint support if existing enemy states need it, preserved hit flash/HP label and fallback for missing combat/death states. Do not invent combat clips from locomotion frames. Follow normal reviewed integration and live testing deployment workflow.

## Acceptance Criteria / Tests
Player still uses player_128, bandit uses its own art; eight directions/nearest filtering/common root and body scale correct. Inspect actor transitions at close gameplay zoom, stable collision/foot position, no feet sliding at runtime velocity, correct Y sorting, no missing textures/errors, hit/death fallback intact. Browser live smoke-test after integration and report build URL/SHA.

## Handoff / Notes
Art preview defaults to half-speed for inspection; proposed metadata speeds do not alter authoritative gameplay movement. Owner visual acceptance remains separate from import checks. Do not expand to attacks/hit/death art under this locomotion order.
