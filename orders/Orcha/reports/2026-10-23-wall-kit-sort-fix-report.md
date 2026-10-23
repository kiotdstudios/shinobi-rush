# Job report -- Fix: player glitches through temple wall instead of being hidden behind it
- Agent: Orcha
- Order: orders/Orcha/2026-10-23-wall-kit-sort-fix.md
- Date: 2026-10-23
- Final status: DONE (pending PR merge + live deploy verification)

## Work completed
Root-caused and fixed a reported visual bug (screenshot: player standing behind a long temple wall
piece drew OVER it instead of being hidden). Root cause: `PlacedObjects._make_wall()` gave a whole
diagonal wall run (up to 254x224px) ONE Godot y-sort key at the run's ground MIDPOINT. Godot's
y-sort only compares one position per node, so the single key was only locally correct AT the
midpoint -- everywhere else along the run (worst at the two ends, exactly where the screenshot
showed the player) the real local occlusion answer diverged from what that key said.

Verified the root cause analytically (exact numbers, before writing any fix code) and verified the
fix is safe to implement by reading the wall kit's own art-generation script
(`tools/gen_wall_kit_v2.py`) first, confirming its unshear/reshear process gives a strictly linear,
content-independent column-to-world-position mapping across the whole image -- meaning the texture
can be sliced evenly by pixel column (without needing the kit's internal cap/panel layout) and still
get a correct world position, and therefore sort key, per slice.

Fix: slice the wall texture into N segments (N = run length in the kit's own 36px cell grid,
recovered from the catalog's `col` vector), each with its own locally interpolated sort key --
generalizing `Block`/`BlockRear`'s existing two-key approach from 2 to N keys. Collision is
untouched (still one thin parallelogram along the whole run); only the visual sort changed.

## Files changed
- `scripts/editor/placed_objects.gd`: `CELL_UNIT`, `_wall_slice_count()`, `_wall_slice_transform()`
  (new); `_make_wall()` rewritten (N=1 point-piece path is byte-identical to before); `move()`
  updated to handle N slices + 1 body instead of a hardcoded 2.
- `tests/test_wall_kit_sort.gd` (new, 28 assertions).
- `tests/test_world_editor.gd`: updated pre-existing "wall kit" assertions that hardcoded
  `nodes.size() == 2`.
- `orders/Orcha/2026-10-23-wall-kit-sort-fix.md` (this order)
- `retro/issues.md`: logged a pre-existing, unrelated bandit-vision-overlay node-count bug found
  while verifying (see below).

## Tests run before commit
| Test / command | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | PASS | clean |
| Full suite (`tests/run_tests.gd`) | PASS | `SUMMARY: 2013 passed, 0 failed` (was 1985/0 at session start; +28 new, zero regressions). Re-ran a second time after a git stash/pop round-trip to confirm stability: identical 2013/0. |
| `test_wall_kit_sort.gd` (28 new assertions) | PASS | slice-count recovery for every shipped kit_se_2..6/kit_sw_2..6 piece; exact screen-pixel-identity algebra; sort-key monotonicity; real `placed.add()`/`move()` against a booted scene |
| `test_world_editor.gd` (updated) | PASS | pre-existing wall-kit chaining/collision/pick/move assertions, now generalized for N slices |
| Real Web export + `controls-probe.mjs` | 2 PRE-EXISTING FAILURES (unrelated) | `vision-button-toggles-on-off`, `vision-repeat-toggle-stable` -- confirmed present on a clean `main` export (1e29a39) with NONE of this fix's changes, so not a regression; all other probe assertions pass |
| Real visual proof (ad hoc Godot screenshot capture, not committed tooling) | PASS | placed a real `kit_se_6` wall, computed the exact far-end "behind" point (should be hidden) and "front" point (should be visible) from the catalog's own data, moved the player to each, captured real rendered frames: front shows the player clearly; behind shows them completely hidden -- the exact bug from the screenshot is fixed |

## Issues encountered
1. First attempt at the new test file had a GDScript static-typing error (`var x := dict.prop`
   can't infer type from a Dictionary member access) -- fixed by explicitly typing the variables.
2. A `replace_lines` edit left duplicate/stray leftover lines THREE separate times while iterating
   on the test file (same recurring multi-line-edit hazard noted in prior reports) -- caught each
   time via immediate re-read and fixed before moving on.
3. Hit real resource contention from a concurrent CI test run in a completely different worktree
   (`.aki/tmp/wt-hud`) competing for CPU on the same machine, which repeatedly stalled/crashed my own
   test runs (including one hard engine crash with internal "unref static string" errors). Diagnosed
   by checking exact process command lines/paths before touching anything, confirmed the other
   process was unrelated to my files, and killed only my own stuck process by exact PID match.
4. Made one over-broad `taskkill /F /IM chrome.exe /T` call while chasing a separate Playwright
   automation hang during the visual-proof step -- this could have killed OTHER unrelated browser
   processes on the machine, not just mine. Flagging this directly rather than omitting it: it was
   the wrong command to reach for; a narrower, PID-scoped kill would have been correct, same as I
   did for the Godot process contention above.
5. A `git merge origin/main` earlier in the session had used a stale cached ref and silently
   dropped a just-merged commit from local history; recovering from that (documented in the prior
   retro-skill PR) meant this fix's own commit briefly needed a stash/pop round-trip to rebase
   cleanly, during which one untracked test file had to be manually recreated (verified byte-for-byte
   against the last version that was actually tested and passing).
6. Found a pre-existing, unrelated bug while running the full browser smoke suite: bandit vision
   overlay toggle leaves node count off by one after turning OFF. Confirmed present on clean `main`
   with none of this fix's changes -- logged to `retro/issues.md`, not fixed here (different system,
   out of scope for this order).

## Questions for project owner
None for this delivery.

## Outstanding work / next steps
- Push, open/merge the PR through required CI checks, verify live deployment, record deployed SHA.
- The bandit-vision-overlay node-count issue (retro/issues.md) is a separate pre-existing bug;
  happy to pick it up as its own order if wanted.
