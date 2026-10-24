# ORDER -- Fire pillar prop (stone lantern with detailed flame animation)

- Agent: Orcha
- Status: DONE
- Priority: P1 -- direct owner request
- Owner: Orcha (art + environment integration)
- Branch/PR: orcha/fire-pillar
- Dependencies: docs/visuals/wind-grass-nine (quality/frame-count precedent), blossom_trees (static-base + Node2D-per-instance precedent)

## Objective
Owner, from the shrine mockup screenshot's small cropped stone-lantern reference image: "can you
make this little fire pillar thingy, need a very detailed fire animation as always max frames to
get the quality matching the grass."

## Context / References
- Reference: the small cropped stone-pillar-with-fire image attached to the request (dark stone
  square pillar, raised cap, glowing embers/flame bowl at top), consistent with the lit lantern
  posts visible flanking the shrine platform in the larger mockup screenshot.
- Quality bar set by the owner's own comparison ("matching the grass"): `docs/visuals/wind-grass-nine`
  (144 shader phases over a handful of real painted tiles) and `blossom_trees` (96 shader phases).
  This project's established REAL PAINTED frame-count ceiling for any single animation is the player
  character's jump at 24 frames (idle/walk=16, run/sprint=20).

## Scope / Files owned
- `assets/environment/fire_pillar/`: `fire_pillar.art.json` manifest, `tiles/pillar_base.png`
  (static lantern body) + `tiles/flame_00..15.png` (16 real painted flame frames), `source/` (raw
  generated images, `.gdignore`'d out of the import scan, same convention as
  `blossom_trees/source/` and `kosen_courtyard/grass/source/`), `README.md`.
- `docs/visuals/fire-pillar/export_fire_pillar.py` (reproducible processing script) and
  `flame-16-contact.png` (QA contact sheet).
- `scripts/environment/fire_pillar.gd` (one instance: static pillar sprite, animated flame overlay,
  procedural glow pulse, procedural ember particles) + `fire_pillar_field.gd` (scene placer,
  mirrors `BlossomTree`/`BlossomGrove`'s two-tier split).
- `scripts/world_scale.gd`: new `FIRE_PILLAR_POSITIONS` (2 spots, south of spawn, clear of every
  wall/tree/bandit area).
- `scenes/arena/training_arena.tscn`: one additive `FirePillarField` node (same pattern as
  `WindGrassField`/`BlossomGrove`) -- no gameplay/collision/nav changes.
- `tests/test_fire_pillar.gd`, registered in `tests/run_tests.gd`.

## Deliverables
1. Stone lantern pillar, generated via built-in image_gen (no paid PixelLab generation), matching
   the reference crop's silhouette and warm-ember-in-a-stone-bowl look.
2. 16 real painted flame flicker key-pose frames (tall flare, calm, leaning left/right, forked tip,
   spike, etc.), ALSO built-in image_gen, matching/exceeding this project's established per-
   animation painted-frame ceiling (16-24). Extra flicker richness beyond these 16 frames --
   a continuously pulsing additive glow halo and a slow-rising ember particle stream, both
   procedural, no extra art -- is the SAME hybrid philosophy the grass/blossom-tree precedent uses
   (real frames + continuous procedural life on top), honestly documented as such, not claimed as
   additional painted frames.
3. `FirePillar` composites the flame precisely onto the pillar's own embers-window opening (anchor
   MEASURED from the actual painted pillar texture, not a guessed constant) and plays it as a
   looping `AnimatedSprite2D` at 14 fps.
4. Two instances placed additively in the live training arena, flanking the spawn, purely
   decorative (no collision/nav), same precedent as grass/blossom trees.

## Acceptance Criteria / Tests
- `tests/test_fire_pillar.gd` (26 assertions): manifest schema/content sanity, all 16 frame files
  exist and are genuinely distinct (unique SHA-256, not duplicated/stamped), real in-scene
  instantiation (`FirePillarField` exists in `scenes/main.tscn`'s `TrainingArena`, spawns at the
  correct `WorldScale` positions), the flame actually animates across real physics frames (frame
  index changes, not frozen), the glow actually pulses (scale varies over time), and
  `set_flame_enabled()` atomically shows/hides the flame+glow+embers together (no half-disabled
  state).
- Full suite: 1393/0, zero regressions.
- `validate_sprite_manifests.py` / `validate_orders.py`: clean (the new `.art.json` is intentionally
  out of that validator's `*.manifest.json` scope, same as `blossom_trees.art.json` / grass's
  `grass-nine.art.json` / Codex's `kunai-primary.art.json`).
- Real Web export + browser smoke (`controls-probe.mjs`, full existing suite): `VERDICT PASS`, 0
  console errors.
- **Real in-game screenshot** (ad hoc Playwright walk-to-pillar capture, not committed tooling):
  both fire pillars render correctly, lit and flickering, in actual live gameplay rendering
  alongside the player, trees, and placeholder walls -- confirmed visually, not just in an offline
  Pillow composite mock-up.

## Handoff / Notes
- Both generated source images required real debugging before they were usable, documented in
  detail in the implementation report (wrong-file background-removal bug on the pillar; two failed
  "no logs" prompt attempts before saturation-based pixel classification correctly separated the
  flame from a stubborn log/wood base the model kept drawing anyway; a first flame-scale attempt
  rendered the flame 2x too large, dwarfing the lantern roof, fixed by measuring the actual embers-
  window size from the painted pillar texture instead of guessing a fixed target height).
- No collision/nav was added -- if the owner wants the pillar to physically block movement later,
  that is a follow-up, not silently assumed here.
- No new owner questions. This closes the request as given.
