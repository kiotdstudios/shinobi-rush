# Job report -- Add free Godot Asset Store plugins to make the game more dynamic
- Agent: Orcha
- Order: orders/Orcha/2026-10-23-asset-store-plugins.md
- Date: 2026-10-23
- Final status: DONE (pending PR merge + live deploy verification)

## Work completed
Added four of the five plugins from the earlier "worth considering" shortlist (Juicee, Dialogue
Manager, Weather FX Free, Breakable 2D Sprites). The fifth, Lit (2D Lighting Engine), was
investigated and NOT added: its own page states it requires the Forward+ renderer and does not
support Mobile/Compatibility, while this project's `project.godot` explicitly runs
`gl_compatibility` for both desktop and mobile -- Lit could not function here at all. A real 1-star
review on Lit's page also describes it as effectively irreversible once wired into scenes, which
would have made a wrong call expensive to undo.

For the four that shipped: found each one's real source (GitHub for two; the Asset Store's own
direct download URL, extracted from the raw page HTML, for the other two since they have no public
GitHub mirror), downloaded and verified each as a genuine zip, and scanned every file inside for
GDExtension/native binaries before copying anything into the repo -- zero found, all four are pure
GDScript/shaders/scenes. Confirmed Weather FX Free's CC BY 4.0 license requires an attribution
credit line and flagged it as an outstanding follow-up, since no credits screen exists in the
project yet to put it in.

## Files changed
- `addons/juicee/`, `addons/dialogue_manager/`, `addons/weather_fx/`, `addons/breakable_2d_sprites/`
  (new, vendored third-party addons).
- `project.godot`: `[editor_plugins] enabled=...` for the three real EditorPlugins; `Juicee` and
  `DialogueManager` autoload lines (the latter added by hand -- its own `_enable_plugin()` only
  fires on a UI toggle transition, not a project.godot text edit, so it would not have self-wired).
- `export_presets.cfg`: exclude filter extended to keep each addon's non-shipped demo/sample content
  out of the Web build.
- `tests/test_asset_store_plugins.gd` (new, 20 assertions), registered in `tests/run_tests.gd`.
- `orders/Orcha/2026-10-23-asset-store-plugins.md` (this order)

## Tests run before commit
| Test / command | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` (x2, to confirm autoload self-registration) | PASS | clean; `Juicee` autoload appeared after the first import, `DialogueManager` added by hand and confirmed surviving a second import |
| Full suite (run twice to rule out flakiness) | PASS | `SUMMARY: 2161 passed, 0 failed`, both runs identical (was 2141/0 at session start) |
| `test_asset_store_plugins.gd` (20 new assertions) | PASS | zero native binaries anywhere under `addons/`; export-filter exclusions present; every `plugin.cfg` exists/enabled/name-matches; Weather FX's missing `plugin.cfg` confirmed intentional; both autoloads present with expected methods; `WeatherFX.effects()` and `ItemShapeBreakableItem.take_hit()` directly callable |
| Real Web export + `controls-probe.mjs` | PASS (after re-run) | First run: one failure (`vision-hotkeys-removed`, node-count-off-by-one). Re-ran the identical unchanged export a second time: passed. Confirmed this is the SAME pre-existing bandit-vision-overlay flakiness already logged in `retro/issues.md` from a completely unrelated session earlier today -- not caused by this change. Final clean run: `VERDICT PASS`, 0 console errors |

## Issues encountered
1. **Branched from a stale local `main` ref.** Checked out what I believed was `origin/main`'s tip
   (`a5a7431`) to start this work, but a race in my own session meant that ref was actually one PR
   BEHIND the real tip (`6fdf275`, my own already-merged publish-to-github PR from earlier this
   session). This meant my new branch was silently missing `tests/test_publish_to_github.gd` and
   related files. Caught it because `tests/run_tests.gd` didn't reference that file where I expected
   -- re-fetched with `--force`, confirmed the real tip via `gh`/`git log`, stashed my uncommitted
   addon work, rebased onto the correct tip, and popped the stash back. Verified nothing was lost by
   re-running the full test suite before proceeding. This is the second time this exact class of
   stale-local-ref issue has happened this session; flagging it as a pattern to watch for -- always
   `git fetch origin main --force` and verify the tip via `git log --oneline origin/main` immediately
   before branching, not trust a ref that was fetched even a few tool-calls earlier.
2. Dialogue Manager's autoload did not self-register the way Juicee's did, because its
   `_enable_plugin()` only runs on an actual UI enable-toggle transition, not from editing
   `project.godot`'s `[editor_plugins]` list directly and reimporting. Diagnosed by reading its
   `plugin.gd` source directly rather than guessing, then added the equivalent autoload line by hand
   and confirmed it persists across reimports.
3. The first browser-smoke run showed a real-looking failure (`vision-hotkeys-removed`,
   node-count-off-by-one). Did not assume it was caused by the new plugins -- re-ran the identical,
   already-built export a second time with zero code changes, which passed, proving it was the
   pre-existing flaky bandit-vision-overlay issue (already logged separately) and not a regression
   from this work.

## Questions for project owner
- Lit (2D Lighting Engine) was in the original "worth considering" list but could not be added --
  see the order's Investigation section. If 2D dynamic lighting is still wanted, the project would
  need to move off the GL Compatibility renderer first, which is a much bigger decision than this
  order and not something to do as a side effect of a plugin request.
- Where should the Weather FX Free CC BY 4.0 credit line go? No credits screen exists in the project
  yet.

## Outstanding work / next steps
- Push, open/merge the PR through required CI checks, verify live deployment.
- None of the four plugins are wired into actual gameplay yet (confirmed deliberately out of scope
  for this order) -- they're installed, enabled, and verified functional, ready for a follow-up
  order to actually call them from gameplay code.
