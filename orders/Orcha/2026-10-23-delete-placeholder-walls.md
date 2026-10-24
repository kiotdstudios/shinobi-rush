# ORDER -- Delete all placeholder walls, replace with new temple wall art
- Agent: Orcha
- Status: DONE
- Priority: P0 -- direct owner request
- Owner: Orcha (environment art + integration)
- Branch/PR: orcha/delete-placeholder-walls
- Dependencies: assets/environment/kosen_courtyard/wall_kit_v2 (Aki, PR -- shipped palette reference); orders/Codex/2026-10-22-real-wall-art.md (QUEUED, superseded by this delivery -- see Handoff)

## Objective
Owner: "delete all placeholder walls and replace them with new temple wall assets."

## Investigation
Two separate "placeholder wall" systems exist in this project:
1. `WorldScale.BLOCKS` -- 9 fixed axis-aligned boxes in the starting arena, rendered by
   `TrainingArena.Block`/`BlockRear` as a flat grey polygon with a literal "PLACEHOLDER" caption.
   `PlacedObjects.def_of()` already labels the ones with height >= 140 "Wall" (vs "Block" for
   shorter rocks/crates) when shown in the World Builder.
2. `assets/environment/kosen_courtyard/wall_kit_v2` -- real temple wall art Aki already shipped,
   but only into the World Builder's free-form catalog (diagonal SE/SW isometric wall RUNS with
   vertex-snapped collision, built for player-drawn walls, not for dropping onto system 1's fixed
   axis-aligned slots without changing the blocked shape).

`orders/Codex/2026-10-22-real-wall-art.md` (QUEUED, never started) had already scoped exactly this
problem for system 1 -- "replace every gray PLACEHOLDER box... with real... pixel art... matching
the existing draw model (front face, east face, roof/top cap)... footprints stay compatible with
existing collision" -- but was superseded before anyone picked it up. This order completes that
original intent, using it as the acceptance bar, while matching the palette of the kit Aki actually
shipped (dark blue-grey stone + dark maroon trim) instead of the older reference mockup's gold trim,
so both wall systems read as the same world.

## Scope decision
"Wall" = any `WorldScale.BLOCKS` entry with height >= `WorldScale.WALL_ART_MIN_HEIGHT` (140, the
exact threshold `PlacedObjects.def_of()` already uses to label an object "Wall" vs "Block") --
indices 1, 4, 5, and 6 as of this delivery. Rocks, crates and the lab stand (height < 140) are
genuinely still placeholder and are UNCHANGED: the owner asked for walls, not every grey box, and
giving a rock flat temple-wall-panel texturing would look wrong.

## Deliverables
1. `assets/environment/kosen_courtyard/walls/`: `wall_front.png`/`wall_side.png`/`wall_roof.png`
   (one AI-generated stone study image, made horizontally seamless via wrap+feather blend,
   palette-quantized to colors sampled DIRECTLY from the shipped `wall_kit_v2/wall_se_6.png`, not
   independently guessed; side/roof are brightness-derived from front for guaranteed consistency,
   disclosed as such), `walls.art.json` manifest, `README.md`.
2. `scripts/arena/training_arena.gd`: `Block`/`BlockRear` now draw real tiled/stretched wall art for
   `is_wall` entries (height >= `WorldScale.WALL_ART_MIN_HEIGHT`) instead of the flat grey polygon +
   "PLACEHOLDER" caption. Shorter entries are completely unaffected. New `WallArt` (lazy texture
   loader), `tile_segments()` (pure tiling math), `draw_tiled_rect()`/`draw_tiled_quad()` (axis-
   aligned and sheared-parallelogram tiling, covering the front face and the east-face/roof
   respectively) are additive -- no existing function signature changed.
3. `scripts/world_scale.gd`: new `WALL_ART_MIN_HEIGHT` constant (single source of truth).
4. `scripts/editor/placed_objects.gd`: `def_of()`'s pre-existing Wall/Block label now reads from
   that same constant instead of its own hardcoded `140.0`, so the World Builder's label and the
   renderer's art choice can never silently disagree.
5. **Collision, footprint, height, and `WorldScale.BLOCKS` index values are completely untouched**
   -- this is a visual swap only. `ArenaNav`, the Level 1 Bandit's choke-point geometry/leash, and
   every test that reads `BLOCKS` by index all continue to work unmodified.
6. As a side effect of the height-based (not index-based) rule, the World Builder catalog's
   "wall_h"/"wall_v" placeholder entries (also height >= 140) now ALSO render as real temple wall
   art wherever a player places or moves one -- the SAME placeholder-wall problem, same fix, for
   free, via one shared mechanism.

## Acceptance Criteria / Tests
- New `tests/test_wall_art.gd` (95 assertions): the Wall/Block threshold stays in sync between
  `WorldScale` and `PlacedObjects`; wall-art textures load and are genuinely distinct files; the
  pure tiling math (`tile_segments`) is correct at the real `BLOCKS` width/depth range and at every
  boundary case (zero, sub-tile, exact-tile, one-tile-plus-remainder, zero tile_w); every
  `WorldScale.BLOCKS` entry gets the correct `is_wall` flag on its real scene nodes; collision
  shapes are byte-for-byte unchanged regardless of `is_wall`.
- Full suite: 1842 (session start) -> 1937/0, zero regressions. The pre-existing `test_arena_sorting`
  (139 assertions, generic over whatever `BLOCKS` contains) and `test_bandit_robber`'s hardcoded
  choke-point/leash assertions against `BLOCKS[5]`/`[6]` all pass unchanged, confirming the
  collision/nav/AI side is untouched.
- Real Web export + browser smoke (`controls-probe.mjs`, full existing suite): `VERDICT PASS`, 0
  console errors.
- **Real in-game screenshots** (ad hoc Playwright walk, not committed tooling): walked the player to
  each wall in turn. Every height>=140 BLOCKS entry renders with real tiled stone-and-trim wall art
  (front face, east face, roof) instead of a grey "PLACEHOLDER" box; rocks/crates/the lab stand
  correctly still show "PLACEHOLDER" (out of scope); collision confirmed intact (player stops at
  the wall); the Bandit, its patrol, and its own rock cover are all unaffected.

## Handoff / Notes
- `orders/Codex/2026-10-22-real-wall-art.md` is now superseded/closed by this delivery -- its exact
  acceptance bar (modular, matches the existing draw model, zero collision changes) is met, using
  the already-shipped `wall_kit_v2` palette instead of redoing art generation from the older
  reference mockup.
- If the owner later wants the Level 1 Bandit arena's two walls (indices 5, 6) to look like a true
  diagonal `wall_kit_v2` run instead of a straight textured panel, that is a geometry/level-design
  change (the kit's pieces are isometric-diagonal only, no straight-corridor variant exists yet) and
  would need its own decision, not an automatic extension of this order.
- `rock`/`crate` placeholders are intentionally untouched; flag if the owner wants those addressed
  next as a separate, explicit request.
