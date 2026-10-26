# Body Flicker Jutsu -- Aki Handoff

**From:** Orcha
**To:** Aki (gameplay mechanics, input mapping)
**Status:** SE proof pending owner approval. Do not wire gameplay until owner approves visual proof.

## What this is

Body Flicker (Shunshin) is extreme speed movement -- the ninja vanishes in a burst and reappears a short distance
away, ready to chain directly into kunai combat. It is NOT a teleport spell, a substitution log, or a slow arc.

## Art deliverables (SE proof, this PR)

10 frames at 192x192 RGBA, three separate VFX layers:

| Layer | Frames | Purpose |
| --- | --- | --- |
| vfx_departure | depart_000..002 | Anticipation, compression, burst at origin position |
| vfx_travel | travel_000..003 | Directional smear + ghost silhouettes between positions |
| vfx_arrival | arrive_000..002 | Reappear impact, skid dust, ready pose |

Foot anchor: (96, 141) in canvas. Matches player_128 foot_anchor y=116 with 25px canvas offset.

## Proposed traversal spec (Aki decides final values)

- **Traversal distance:** 56x + 40y world px in SE direction (~68px diagonal). Scales with direction for 8-way.
- **Total duration:** ~100-220ms (10 frames at 24fps = 417ms is the VFX window; gameplay traversal should
  feel snappier -- suggest 120ms actual body teleport with VFX playing over it, not a gradual movement tween).
- **Preferred mechanic:** instant body position change at `hide_player` event. Move `CharacterBody2D.global_position`
  to arrival point at that frame. VFX plays over the jump. Do NOT tween the body position -- Body Flicker is
  defined by reading as instant.

## Event markers (from manifest)

| Event | Frame | What Aki should do |
| --- | --- | --- |
| `flicker_start` | 0 | Begin jutsu, consume resource (chakra/stamina), lock normal input |
| `hide_player` | 1 | Set player visible=false, disable collision (1-frame grace after), teleport CharacterBody2D |
| `flicker_travel` | 2 | VFX travel layer starts playing at departure position |
| `reappear` | 7 | Set player visible=true, re-enable collision at arrival position |
| `recover` | 9 | End input lock, start cooldown timer, allow kunai chain or movement |

## Invincibility / i-frames suggestion

Brief i-frame window during travel (frames 2-7, roughly 20-60ms) is thematically correct for Body Flicker and
prevents getting hit mid-teleport. Recommend Aki expose this as a tunable so Chief can approve the exact window.

## Cooldown suggestion

100-600ms cooldown after `recover` event. Prevents spamming across the arena. Aki owns the final value.

## Kunai chain

Arrival ready pose (arrive_002) flows directly into a kunai throw or kunai strike. Codex owns the kunai
animation assets. No art changes needed from Orcha for the chain -- it is a state transition in Aki's controller.

## Collision during travel

Player CharacterBody2D position moves at `hide_player` event. Collision shape should be disabled for the 5 travel
frames to prevent wall collisions blocking the flicker. Re-enable at `reappear`. If the arrival position is inside
a wall, suggest nudging toward the nearest free cell rather than blocking the flicker outright.

## What Orcha does NOT own

- Input binding (which button triggers Body Flicker)
- Resource cost (chakra/stamina system)
- Cooldown UI
- Camera response to the flicker (Kiro / CombatCameraDirector.notify(JUTSU, ...) call -- Orcha's director
  already has JUTSU event kind ready; Aki wires the notify call when integrating)
- Kunai animation assets (Codex)
- Eight-direction expansion (pending owner approval of this SE proof)
