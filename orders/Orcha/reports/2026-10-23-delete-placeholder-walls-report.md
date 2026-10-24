# Job report -- Delete all placeholder walls, replace with new temple wall art
- Agent: Orcha
- Order: orders/Orcha/2026-10-23-delete-placeholder-walls.md
- Date: 2026-10-23
- Final status: DONE (pending PR merge + live deploy verification)

## Work completed
Found two separate "placeholder wall" systems: the fixed arena's `WorldScale.BLOCKS` (9 boxes
rendered with a literal "PLACEHOLDER" caption) and the World Builder's already-shipped
`wall_kit_v2` temple wall art (Aki, diagonal isometric runs, built for free-form building, not
compatible with dropping onto the fixed arena's straight axis-aligned slots without changing the
blocked shape). Replaced the fixed arena's placeholder WALLS (the 4 `BLOCKS` entries at or above
the project's own existing "Wall" height threshold, 140 -- the same threshold the World Builder
already used to label them) with real tiled stone-and-trim wall art, palette-matched to the
already-shipped `wall_kit_v2` so both wall systems read as the same world. Rocks/crates (below the
threshold) are genuinely still placeholder and were left alone, since the request was specifically
about walls.

Collision, footprint, height and `BLOCKS` index values are completely untouched -- this is a
rendering swap only, confirmed by the full regression suite (including the Bandit's
choke-point/leash tests, which hardcode `BLOCKS[5]`/`[6]`) staying green with zero changes needed.

## Files changed
- `assets/environment/kosen_courtyard/walls/`: `wall_front.png`, `wall_side.png`, `wall_roof.png`,
  `walls.art.json`, `README.md` (new).
- `docs/visuals/walls/export_walls.py` (reproducible processing script, new), `wall-faces-contact.png`.
- `scripts/arena/training_arena.gd`: `WallArt`, `tile_segments()`, `draw_tiled_rect()`,
  `draw_tiled_quad()` (new); `Block`/`BlockRear` branch on `is_wall` to draw real art instead of the
  flat grey placeholder for height >= `WorldScale.WALL_ART_MIN_HEIGHT`.
- `scripts/world_scale.gd`: `WALL_ART_MIN_HEIGHT` constant (new, single source of truth).
- `scripts/editor/placed_objects.gd`: `def_of()`'s Wall/Block label now reads the shared constant.
- `tests/test_wall_art.gd` (new, 95 assertions), registered in `tests/run_tests.gd`.
- `orders/Orcha/2026-10-23-delete-placeholder-walls.md` (this order)

## Tests run before commit
| Test / command | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | PASS | clean |
| `godot_ci.py tests` (full suite) | PASS | `SUMMARY: 1937 passed, 0 failed` (was 1842 at session start; +95 new assertions, zero regressions) |
| `test_arena_sorting.gd` (139 assertions, generic over whatever `BLOCKS` contains) | PASS | unchanged, confirms sort/structure untouched |
| `test_bandit_robber.gd` (hardcodes `BLOCKS[5]`/`[6]` for the choke point) | PASS | unchanged, confirms collision/nav/AI untouched |
| Real Web export + `controls-probe.mjs` (full existing suite) | PASS | `VERDICT PASS`, 0 console errors |
| Real in-game screenshots (Playwright walk, ad hoc, not committed) | PASS | every height>=140 wall renders real tiled stone-and-trim art (front/east/roof); rocks/crates correctly still "PLACEHOLDER"; player stops correctly at the collision boundary; Bandit/patrol unaffected |

## Issues encountered
1. First AI-generated wall study image came out photoreal (kintsugi-gold-veined rock), not pixel
   art, and used gold trim matching the OLDER reference mockup rather than the actually-shipped
   `wall_kit_v2` (dark maroon). Regenerated with an explicit flat-pixel-art, maroon-trim prompt
   closer to the shipped kit's real style.
2. First palette-quantization attempt included shades BRIGHTER than anything `wall_kit_v2` actually
   uses, which pulled every near-white AI-generated highlight pixel up to those too-bright entries
   instead of down into the kit's real (darker, moodier) tonal range -- fixed by capping the
   palette at the actual sampled maximum and darkening the source crop before quantizing.
3. `draw_tiled_rect`/`draw_tiled_quad` call real Godot `CanvasItem` draw methods, which are an
   ENGINE ERROR (not a safe no-op) when called outside an active `_draw()` callback -- an early
   test draft called them directly and flooded the console with 52 "Drawing is only allowed
   inside..." errors (which the CI test runner correctly treats as a failure, not a hang -- it just
   took a while to print). Fixed by extracting the pure tiling math (`tile_segments`) into its own
   function so the boundary-case math can be unit-tested safely, while the real draw path is
   exercised by actually booting the scene (the correct way to test Godot drawing code).
4. A `replace_lines` edit left duplicate leftover code and a wrong-indentation line twice during
   this session; both caught via `git diff` re-review and fixed before committing -- the same
   recurring multi-line-edit hazard noted in prior reports.

No remaining known issues. No regressions in the 1842 pre-existing automated tests.

## Questions for project owner
None for this delivery. Noted in the order's Handoff: the Level 1 Bandit arena's two walls (indices
5, 6) now use the straight-panel wall art (matching their straight collision exactly); giving them a
true diagonal `wall_kit_v2` look instead would be a geometry/level-design change, not an automatic
extension of "replace the art."

## Outstanding work / next steps
- Push, open/merge the PR through required CI checks, verify live deployment, record deployed
  commit SHA.
- Rocks/crates/the lab stand remain placeholder by design (out of scope) -- flag if the owner wants
  those addressed next.
