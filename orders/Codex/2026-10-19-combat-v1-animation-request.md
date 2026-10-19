# ORDER — Combat System V1 Animation Request (Milestone A art dependencies)
- Agent: Codex
- Status: QUEUED — start when read
- Priority: P1 (gameplay is live and playable with placeholders; this unblocks the real look)
- Owner: Codex (art)
- Dependencies: [Order 01](./order_01.md) locked art standard (128x128 RGBA, ~100-112px standing
  height, fixed foot anchor, 8-direction coverage, 24fps authored). Gameplay owner: Aki
  (`orders/Aki/2026-10-19-combat-system-v1-milestone-a.md`).

## Objective
Milestone A of the combat system order ("SHINOBI RUSH — COMBAT SYSTEM V1") is live and fully
playable, but every new combat action currently renders through the procedural placeholder visual
(`PlaceholderVisual`/`BanditVisual`) because no matching animation exists yet. This order lists
exactly what's missing so real art can replace the placeholders without blocking further gameplay
work. Gameplay logic is intentionally decoupled from this — `PlayerVisual.play_action()` already
falls back cleanly to the placeholder for any animation id it doesn't find, so nothing breaks while
this order is in progress, and nothing needs to be re-coded once frames land (drop them into the
manifest under the ids below and they pick up automatically).

## Missing: Player character (`assets/characters/player/`)
Add to the existing `player_128.manifest.json` (same 128x128/8-direction/24fps standard as `idle`,
`walk`, `jump`, `dodge` already in that file):
- `light1` — fast first combo hit. ~0.3s total (5 startup + 4 active + 9 recovery frames @ 60 tps
  reference timing — reauthor at 24fps to the same felt duration, not frame-for-frame). Quick,
  snappy, least committed-looking of the three.
- `light2` — second combo hit. ~0.35s total (6+4+11 frames @ 60tps reference). Slightly heavier than
  light1.
- `light3` — third/finishing combo hit. ~0.48s total (9+5+15 frames @ 60tps reference). Visibly the
  heaviest and most committed swing of the three — this is the one that should read as a "finisher".
- `dash_attack` — a forward-lunging thrust/slash, big forward travel baked into the pose readability
  (the lunge itself is velocity, not a position offset in the sprite, but the pose should sell "I just
  closed a lot of distance"). ~0.4s total (6+5+13 frames @ 60tps reference).
All four need the same 8-direction coverage as `dodge`/`jump`. Reference inspiration per the parent
order: Ghost of Tsushima's weighty katana strikes — deliberate, not flurrying.

Not required for Milestone A, flagged for awareness (Milestone B will request these formally once
that order starts): `block` (held defensive pose), `parry_success` (brief flash/pose), `hit_react`,
`death`.

## Missing: Basic Bandit enemy (new character, `assets/characters/bandit/` suggested path)
There is **zero art of any kind** for this enemy yet — not even a base idle/walk. It currently
renders as a fully procedural placeholder (`scripts/enemy/bandit_visual.gd`): a simple colored
limb/torso figure with an HP bar and state label, no character design at all.
**Owner decision needed before this is produced:** does the Bandit get a real character design now,
or does Milestone A's placeholder stay as the enemy's look for longer (e.g. until more enemy types
are planned and a batch of enemy art makes more sense)? Flagging rather than assuming. If the answer
is "yes, design it now", minimum Milestone A coverage would be: idle, approach/walk, hit-react, die
(4 states, 8 directions, 128x128, same standard as the player) — attack/block/guard-break poses are
Milestone B and can follow once that order starts.

## Integration requirements
- Animation ids must match exactly: `light1`, `light2`, `light3`, `dash_attack` (player manifest);
  Bandit ids TBD pending the owner decision above, but should mirror the player's naming style
  (`idle`, `walk`, `hit_react`, `death`) if/when produced.
- Foot anchor and body-height-px must match the existing player sprite set exactly, or the camera
  baseline zoom (keyed off figure height) will shift when the sprite set reloads mid-animation.
- `PlayerController._begin_attack()`/`_process_attack_state()` call `visual.play_action(id, facing8)`
  every physics frame for the duration of the attack — frame timing within a single played-once
  animation does not need to match the 60tps startup/active/recovery split exactly; the gameplay
  timing is already authoritative and independent of animation length (see
  `AttackDef`/`player_controller.gd`). Looping/holding behavior should match `dodge`/`jump`'s existing
  non-looping one-shot convention.
- Test in Godot and the browser build before marking done, same as every prior Codex order.

## Deliverables
- Updated `player_128.manifest.json` (+ sprite sheets) with the four new animation ids, 8 directions.
- Owner decision captured (and, if "yes", Bandit base art) before closing this order.
- Report in `orders/Codex/reports/` per the standard workflow, including which ids were added and a
  note confirming placeholder fallback is no longer needed for those ids.
