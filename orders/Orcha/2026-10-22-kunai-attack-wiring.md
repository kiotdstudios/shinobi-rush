# ORDER -- Wire Codex's kunai strike art to the real attack_light input (controller Square / keyboard J)
- Agent: Orcha
- Status: DONE
- Priority: P0 (direct owner instruction)
- Owner: Orcha
- Branch/PR: orcha/kunai-attack-wiring
- Dependencies: orders/Codex/2026-10-21-player-kunai-flicker-combat-rework.md (art source), Combat System V1 (attack_light binding + AttackDef timing, pre-existing)

## Objective
Owner asked Orcha to check whether Codex's kunai attack art was committed and synced to Square on
controller, then directed: "wire it to the controller."

Investigation found: `attack_light` was already correctly bound to keyboard J and gamepad button 2
(Square on PlayStation, X on Xbox) in `project.godot`, and already drove a real, damage-dealing
combo (light1/light2/light3) with hitbox/knockback/hitstop via `scripts/combat/attack_def.gd` and
`PlayerController._check_attack_hits()`. But Codex's kunai BODY ART (`kunai_poc/`, `kunai_primary_se/`)
was never present in the production manifest the real player loads
(`assets/characters/player/player_128.manifest.json`) -- only `idle/walk/run/sprint/jump/dodge`
existed there. Codex's own report confirms this: "This is a playable art harness, not integrated
player combat." So pressing Square triggered a real attack mechanically, with zero visible kunai art
and no weapon rendering at all (no weapon-compositing layer exists anywhere in the production
pipeline; the kunai texture is explicitly `"independent"` of the body art per Codex's own schema).

## Root cause / blocker found mid-task
Wiring the art in naively would have broken the ENTIRE player's visuals. `SpriteSet._check_cardinals()`
requires every animation to cover all 4 cardinal directions (N/E/S/W) or the WHOLE SpriteSet becomes
invalid, and `SpriteLibrary.first_valid()` returns null for an invalid set -- which would make
`idle/walk/run/sprint/jump/dodge` (all already working, all already full 8-direction) disappear too,
since Codex's kunai art is deliberately SE-only (proof-stage; the order gates the other 7 directions
behind separate owner approval, not yet given).

## Deliverables
1. `scripts/sprites/sprite_set.gd` + `scripts/ci/validate_sprite_manifests.py`: new opt-in
   `"allow_partial_directions": true` flag, read per-animation. Default false, so every pre-existing
   production animation keeps today's strict full-coverage requirement -- cannot silently weaken an
   already-shipped animation. Set true only on the 4 new kunai animations.
2. `assets/characters/player/player_128.manifest.json`: added `light1`, `light2`, `light3`,
   `dash_attack`, SE-only, pointing at Codex's existing `kunai_poc/body/` and
   `kunai_primary_se/body/{light2,light3,dash_attack}/` frame files (no new art produced). fps per
   animation chosen so total duration matches the authored art exactly, which in turn matches
   `AttackDef`'s own startup+active+recovery total EXACTLY for all 4 (300/350/483.33/400 ms) -- these
   were clearly designed to already line up 1:1.
3. `scripts/combat/weapon_rig.gd` (new): per-frame kunai hand position/angle/layer for the 4 SE
   animations, copied verbatim from Codex's authored
   `kunai_primary_se/kunai-primary.art.json` (same numbers Codex's own verified proof scene already
   renders). SE-only by construction; `supports()`/`pose()` are the only API surface.
4. `scripts/player/player_visual.gd`: a real kunai `Sprite2D` (grip+blade, same placement math as
   Codex's verified `kunai_primary_proof.gd`: `grip.position = hand_px - foot_anchor`,
   `grip.rotation = angle_deg`, `blade.position = -grip_pivot_px`) now actually renders during
   light1/light2/light3/dash_attack, synced to the body's exact current frame via a new
   `SpriteActor.current_frame()` getter.
5. **Direction gating (deliberate, not a bug):** `play_action()` only plays the kunai body art and
   shows the weapon when the attack's facing resolves to a literal `"SE"` -- never via SpriteSet's
   normal nearest-neighbor fallback. Facing any of the other 7 directions during an attack keeps
   EXACTLY today's pre-existing behavior (whatever locomotion pose was last shown stays frozen for the
   attack's duration, no visible kunai). This matches the order's explicit SE-first-then-approve gate;
   silently falling back to the SE pose for every direction would have shipped a visibly wrong-facing
   attack animation.
6. `scripts/web/web_bridge.gd`: added `player_attack_anim` / `player_weapon_visible` telemetry fields
   for testability/future browser verification.

## Acceptance Criteria / Tests
- New `tests/test_kunai_attack_wiring.gd` (registered in `tests/run_tests.gd`): (a) the real
  production SpriteSet stays valid and every pre-existing animation is untouched; (b) light1/2/3 and
  dash_attack are now real SE-only animations; (c) `WeaponRig` data sanity (supports/pose/clamp); (d)
  booting the real main scene, facing SE and pressing `attack_light` actually plays the kunai body art
  AND shows the weapon overlay, which then hides again once the attack ends; (e) facing N during the
  same attack never shows the weapon and never snaps the body to the SE pose.
- Full suite: 1337 (session start, after Aki's PR #89) -> 1379/0 (+27 new assertions, zero
  regressions). Pre-existing combo test (`test_combat.gd`, East-facing) still passes unchanged.
- `python scripts/ci/validate_sprite_manifests.py`: 0 errors (was 16 errors before the
  `allow_partial_directions` fix in the Python validator -- it independently re-implements the same
  cardinal check as the GDScript side and needed the identical opt-out).
- `python scripts/ci/validate_orders.py`: clean.
- Real Web export + browser smoke (`controls-probe.mjs`, full existing suite): `VERDICT PASS`, 34/34,
  0 console errors.
- **Live keyboard verification (ad hoc, not committed tooling):** launched the real export, held D+S
  (face SE) and tapped J (physical key bound to `attack_light`, same action as controller Square/X) --
  `window.__SHINOBI_STATE__.player_weapon_visible` went true during the attack. Held D only (face E)
  and tapped J again -- weapon never appeared. Zero console errors either way.

## Handoff / Notes
- Only SE is wired. The other 7 directions remain exactly as before (mechanically functional attack,
  no visible kunai) until Codex/owner approves expanding the art to all 8 directions -- per the
  order's own gate, not a limitation introduced here.
- `air_attack` has no Codex art yet (confirmed, no directory exists) and is unaffected by this order.
- No unrelated files touched; `tests/test_health_flicker.gd.uid` appeared as an untracked stray file
  from a prior merge's incomplete commit (unrelated), left untouched/uncommitted per scope discipline.
