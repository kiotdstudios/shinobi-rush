# ORDER — Level 1 Bandit robber AI, ninja locomotion, arena walls and distant spawn
- Agent: Aki
- Owner: Aki (gameplay/AI)
- Status: DONE
- Priority: P0
- Date: 2026-10-21
- Dependencies: Coordinate with Codex (bandit sprite/animation ownership) and Orcha (Body Flicker visual API). Do not overwrite their work.

## Objective
Turn the Bandit from a stationary stare-and-sprint target into a believable **low-intelligence Level 1 ninja highway robber** who patrols on the far side of the training map, detects the player, approaches to threaten/rob, attacks with simple kunai logic, retreats with an imperfect Body Flicker, and searches briefly after losing line of sight. Add **placeholder collision walls** that create actual cover, paths, and navigation choices. The Bandit must remain intentionally beatable and readable.

## Existing files to inspect first
- `scripts/enemy/bandit.gd`, `scripts/enemy/bandit_visual.gd`, `scenes/enemy/bandit.tscn`
- `scenes/arena/training_arena.tscn`, `scripts/arena/training_arena.gd`
- `scripts/ci/smoke/bandit-probe.mjs`
- Player controller, kunai combo implementation/PR, and Orcha Body Flicker branch/PR #61. Do not assume unmerged branches are live.

## Scope and requirements
1. **Arena:** Keep player spawn where it is. Move the single Bandit to the **opposite/far side of the actual navigable arena**. Add several obviously temporary but attractive wall/rock/tree-trunk collision blockers creating at least two routes, a choke point, and cover to break sight. Ensure walls don't block spawn, goal, or lock player/enemy in. Validate camera, nav/pathing and collision; don't add final art or replace world layout.
2. **Bandit state machine:** `PATROL -> NOTICE -> APPROACH -> THREATEN -> ATTACK -> REPOSITION/RETREAT -> SEARCH -> RETURN`, with sensible transitions and cooldowns. Start patrolling/looking around, not staring at player from across map. Only acquire within sight range and clear line of sight; a short suspicion delay is okay. Approach intelligently enough to navigate around placeholder walls; don't blindly run into geometry.
3. **Robber identity:** On first close encounter, show a short non-blocking threat such as “Hand over your ryo!” (placeholder text/UI only). If player disengages, Bandit pursues a limited distance; if the player escapes sight, investigate last seen position briefly then return to patrol. No currency theft/inventory or economy modifications yet.
4. **Combat:** Give him a basic readable **two-hit kunai combo** and a **double backward Body Flicker retreat** as a rare, telegraphed disengage option; mirror the player's attack/retreat language, but deliberately worse timing, slower reactions, missed attacks, longer recovery, and cooldowns. Coordinate Orcha's visual integration; if unavailable, use safe temporary VFX and explicitly report dependency. Never automatically fire the player's retreat without player input (separate user-facing combat design decision).
5. **Ninja motion:** No static mannequin idle and no awkward sprint/lunge. Face actual movement/target direction, use existing 128x128 8-direction bandit idle/run sprites with correct playback, stop-to-turn transitions and believable patrol/wait/alert poses. Codex owns **new sprite art**; request an art handoff if current frames cannot achieve the desired look. No scale/foot-anchor regressions.
6. **Level 1 intelligence data:** Add configurable `intelligence_level = 1` (or a small reusable profile) driving perception/reaction/pursuit/attack decisions; keep design extensible for future levels without implementing a whole AI leveling system now. Make it observable in debug logs/HUD or test harness. Level 1: narrow awareness, predictable attacks, occasional overcommit, slow re-acquisition, no sophisticated flanking, bounded chase. Not inert or glitchy.
7. **Combat balance:** Player can evade, counter and escape; no unavoidable long-distance lock-on or instant hits through walls. Attack tells and collision must be fair.

## Deliverables
- Updated Bandit behavior, animation integration, enemy scene, arena scene and/or arena script; limited supporting reusable AI profile only if justified.
- At least 3 placeholder blockers with real collisions and clear route around them.
- Updated deterministic Bandit smoke/behavior probes covering patrol, acquisition, LOS blocked, wall navigation, threat, attack, retreat, loss of sight/search, return, far spawn and no stuck states.
- Report `orders/Aki/reports/2026-10-21-bandit-level1-robber-arena-report.md` with actual test commands, results, screenshot or clip of live play, outstanding issues, commit/PR and deployed SHA.

## Acceptance criteria
- In live browser build, player spawns near start and Bandit **visibly far away**; Bandit patrols until it spots player.
- Walls obstruct both movement and detection; Bandit navigates around them or abandons chase safely.
- Bandit displays robber intent, attacks, sometimes double-flickers backward, and searches/returns after losing player.
- Animation reads like ninja movement, not a mannequin or lunge.
- Level 1 intelligence tunable; all existing gameplay controls remain intact.
- Automated Godot tests, Web export, real browser smoke, hands-on combat playtest, integration PR, deployment and live version verification complete before DONE.

## Rules
Read `orders/README.md` and `orders/Aki/README.md` before work. Start immediately on discovering QUEUED. Own gameplay only; coordinate art with Codex and Body Flicker with Orcha. Do not silently alter persistent-world RPG progression, save rules, or unrelated camera systems. Pre-commit tests and honest job report mandatory. Push an implementation PR, respect branch protection, deploy to the live shared testing build and verify it yourself; if blocked, mark BLOCKED/REVIEW and give a precise reason. No paid tools without approval.
