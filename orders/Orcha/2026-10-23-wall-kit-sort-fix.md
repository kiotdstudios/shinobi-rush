# ORDER -- Fix: player glitches through temple wall instead of being hidden behind it
- Agent: Orcha
- Status: DONE
- Priority: P0 -- direct owner bug report (screenshot)
- Owner: Orcha (runtime/rendering)
- Branch/PR: orcha/wall-kit-sort-fix
- Dependencies: assets/environment/kosen_courtyard/wall_kit_v2 (Aki, already shipped), scripts/editor/placed_objects.gd (World Builder, nominally Aki's domain -- fixed here because the bug is a generic runtime y-sort correctness issue, not a content/authoring change)

## Objective
Owner, with screenshot: a long temple wall piece (wall_kit_v2, placed via the World Builder) should
hide the player when they stand behind it, but the player visibly draws OVER the wall instead.

## Root cause
`PlacedObjects._make_wall()` drew a whole diagonal wall run (e.g. "Wall SE x6", up to 254x224px) as
ONE Sprite2D with ONE Godot y-sort key, placed at the run's ground-position MIDPOINT (explicit in
the removed comment: "the sprite sorts at the MIDDLE of its ground run (one key for a long diagonal
piece)"). Godot's y-sort only compares one position per node. A single midpoint key can only be
locally correct AT the midpoint -- everywhere else along the run (worst at the two ends, exactly
where the screenshot shows the player standing) the real local "in front of or behind" answer
diverges from what that one key says, and the player draws through the wall.

Verified analytically before writing any code: for kit_se_6 (run (216,108)), a player standing at
local y=100 near the far end (where the TRUE local wall edge is also ~108, so the player should be
hidden) sorts against the midpoint key (54) instead -- 100 > 54 means Godot draws the player OVER
the wall, exactly the reported glitch.

## Fix
Slice the wall texture into N vertical segments (N = run length in `kit.json`'s own 36px cell grid,
recovered from the catalog's `col` vector with no hardcoded per-id table), each as its own Sprite2D
with its own y-sort key, linearly interpolated from the run's near-corner y to its far-corner y --
the same idea as `TrainingArena.Block`/`BlockRear`'s two keys (front edge, back edge), generalized
from 2 keys to N because a diagonal edge isn't a single constant-y line the way an axis-aligned
box's edges are.

Verified safe before implementing (not guessed): the kit's own build script
(`tools/gen_wall_kit_v2.py`) unshears the source art (shift column x up by x//2), builds the run,
then reshears it (shift column x DOWN by x//2) -- a strictly linear, content-independent mapping
from image column to world position for EVERY column of the final PNG, including the non-uniform
end-cap regions. That means slicing evenly by pixel column (no need to know the kit's internal
cap/panel pixel layout) still gives a proportionally correct world position, and therefore sort
key, per slice.

`position_i + offset_i` is solved per slice to reproduce the EXACT same final screen pixels as the
original single sprite (verified algebraically, then checked in the real engine's own Vector2 math
by the new test suite) -- the only thing this changes is sort-key granularity; the baked-in art is
pixel-identical to before. Collision is untouched (a single thin parallelogram along the whole run,
same as before) -- this is a visual-sort fix only.

## Scope note
This fix lives in `scripts/editor/placed_objects.gd`, which is nominally Aki's World Builder/content
domain. It was fixed here because the bug is a generic runtime y-sort correctness issue (the same
class of problem `TrainingArena.Block`/`BlockRear`/`ArenaSort` already solve for axis-aligned
blocks), not a content/authoring change, and the owner reported it directly. `move()` was also
updated (previously hardcoded `nodes[0]`/`nodes[1]` for walls, now handles N slices + 1 body) so
dragging a placed multi-cell wall in the World Builder keeps correct per-slice sort keys instead of
collapsing back to a stale single key.

## Deliverables
1. `scripts/editor/placed_objects.gd`: `CELL_UNIT`, `_wall_slice_count()`, `_wall_slice_transform()`
   (new, pure functions); `_make_wall()` rewritten to emit N slice sprites + 1 body instead of 1
   sprite + 1 body (N=1 for point pieces -- pillar/ruin -- is byte-identical to the old single-sprite
   path, zero behavior change there); `move()` updated to re-derive each slice's position/offset
   from stashed `x0`/`w` metadata instead of assuming exactly 2 nodes.
2. `tests/test_wall_kit_sort.gd` (new, 28 assertions): slice-count recovery from the catalog's `col`
   vector for every shipped piece (kit_se_2..6, kit_sw_2..6); the exact algebraic screen-pixel-
   identity invariant per slice; sort-key monotonicity and the exact far-end-vs-old-midpoint
   divergence that reproduces the reported bug; real `placed.add()`/`move()` calls against a booted
   scene confirming slice count, contiguous texture coverage, monotonic real sort keys, untouched
   collision, and correct behavior after a move.
3. `tests/test_world_editor.gd`: updated the pre-existing "wall kit" block's hardcoded
   `nodes.size() == 2` / `nodes[1] is StaticBody2D` assumptions (no longer true for multi-cell
   pieces) to use the shared `_wall_slice_count()`/last-index pattern instead.

## Acceptance Criteria / Tests
- Full suite: 1985/0 (session start, after the retro-skill PR) -> 2013/0, zero regressions.
- Real Web export + browser smoke (`controls-probe.mjs`): two PRE-EXISTING failures found
  (`vision-button-toggles-on-off`, `vision-repeat-toggle-stable`, an off-by-one bandit-vision-overlay
  node count unrelated to this change) -- confirmed present on a clean `main` export WITHOUT this
  fix's changes before shipping, so they are not a regression from this work. Every other probe
  assertion passes; flagged separately, not fixed here (out of scope, different system).
- **Real visual proof, closing the loop on the reported screenshot**: booted the real engine, placed
  a `kit_se_6` wall at a known position, computed the exact far-end "behind" point (should be hidden)
  and "front" point (should be visible) from the catalog's own anchor/col/size, moved the player to
  each, and captured real rendered frames. At the "front" position the player renders normally,
  clearly visible. At the "behind" position (the exact case from the screenshot) the player is
  completely hidden by the wall -- the bug is fixed.

## Handoff / Notes
- Pre-existing bandit-vision-overlay off-by-one node-count bug (confirmed on clean `main`, unrelated
  to this fix) is a separate issue; logged to `retro/issues.md` for follow-up, not fixed in this PR.
- Process note: hit real resource contention mid-session from a concurrent CI run in a different
  worktree (`.aki/tmp/wt-hud`) competing for CPU on the same machine, which repeatedly stalled test
  runs; resolved by identifying and killing only my own stuck process by exact command-line match,
  never the other agent's. Also made one over-broad `taskkill /F /IM chrome.exe` call while chasing
  a separate Playwright hang, which could have affected other unrelated browser processes on the
  machine -- flagged to the owner directly, not hidden.
