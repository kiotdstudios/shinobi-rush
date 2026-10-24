# ORDER -- Add free Godot Asset Store plugins to make the game more dynamic
- Agent: Orcha
- Status: DONE
- Priority: P2 -- direct owner request ("read the Godot Asset Store and see what free plugins we can use")
- Owner: Orcha (tooling/integration)
- Branch/PR: orcha/asset-store-plugins
- Dependencies: none

## Objective
Owner asked Orcha to read https://store.godotengine.org/ and recommend free plugins to make the
game more dynamic. Orcha surfaced a shortlist (Juicee, Lit, Dialogue Manager, Breakable 2D Sprites,
Weather FX Free) with compatibility/style caveats. Owner replied "add all under with considering" --
the five items in the "Worth considering" section of that shortlist.

## Investigation before touching anything
Re-fetched each asset's own detail page (not just the search-result summary) before downloading
anything, because the search-result blurb for Lit omitted a critical fact its own full page states
outright: **"Requires Godot 4.4+ on the Forward+ renderer. (Mobile/Compatibility aren't supported.)"**
This project's `project.godot` is explicit: `renderer/rendering_method="gl_compatibility"` for BOTH
desktop and mobile, and the file's own header comment says "Godot 4.7.2, GL Compatibility". Lit
could not function in this project at all, Web export or otherwise -- confirmed, not guessed, by
reading the renderer line in our own project.godot. There is also a real 1-star review on Lit's
store page describing it as effectively irreversible once wired into scenes ("infecting every
single node... manually remove every single reference"). **Lit was NOT added.** This narrows the
owner's "add all" instruction to the four that are actually viable: Juicee, Dialogue Manager,
Weather FX Free, Breakable 2D Sprites.

For each of the four, before copying anything into the repo:
1. Found the REAL source (GitHub repo for Juicee/Dialogue Manager; the Asset Store's own
   `/asset/.../download/<id>/` URL, found by reading the page's raw HTML for `data-url`, for Weather
   FX Free and Breakable 2D Sprites, which have no public GitHub mirror).
2. Downloaded the real zip, verified it is a genuine ZIP (`PK\x03\x04` header), extracted it.
3. **Scanned every file under each addon for `.gdextension`/`.dll`/`.so`/`.dylib`/`.wasm`** -- the
   decisive Web/WASM-export compatibility check, since GDExtension-based addons generally do not
   run in a Web export unless the publisher specifically built an emscripten target. Zero native
   binaries found in any of the four -- all pure GDScript + shaders/scenes/resources.
4. Read each `plugin.cfg` (or confirmed its absence) to know exactly what to enable.

## What shipped
- `addons/juicee/` (v2.0.0, MIT, https://github.com/Kelpekk/Juicee) -- game-feel toolkit: screen
  shake, hit-stop, squash/stretch, damage numbers, 117 effects. Registers its own `Juicee` autoload
  (it defensively self-registers from `_enter_tree()`, confirmed working by checking
  `project.godot` after an import pass).
- `addons/dialogue_manager/` (v4.1.0, MIT, https://github.com/nathanhoad/godot_dialogue_manager) --
  branching dialogue editor/runtime. Its autoload registration (`_enable_plugin()`) only fires on a
  UI toggle transition, not on an `[editor_plugins]` text-file edit, so the `DialogueManager`
  autoload line was added to `project.godot` by hand, mirroring exactly what `_enable_plugin()`
  does (`res://addons/dialogue_manager/dialogue_manager.gd`) -- confirmed present after reimport.
- `addons/weather_fx/` (v1.0.2, CC BY 4.0, via store.godotengine.org) -- rain/snow/fog as one-line
  shader effects (`WeatherFX.add(self, "rain")`). A plain `class_name` script, not an EditorPlugin
  (no `plugin.cfg`) -- confirmed this is intentional on the addon's side, not a mis-install, no
  enable step needed. **CC BY 4.0 requires an attribution credit line** (see below).
- `addons/breakable_2d_sprites/` (v1.0.0, MIT, via store.godotengine.org) -- traces a sprite's alpha
  silhouette, shatters it into Voronoi shards, builds a ready-to-place breakable scene. Editor-dock
  tool only, no autoload needed.
- `project.godot`: added `[editor_plugins] enabled=PackedStringArray(...)` for the three real
  EditorPlugins, plus the two autoload lines above.
- `export_presets.cfg`: extended `exclude_filter` to also exclude each addon's non-shipped demo/
  sample-art/example content (`addons/weather_fx/demo/*`, `addons/breakable_2d_sprites/test_scene/*`,
  `addons/dialogue_manager/example_balloon/*`) -- same existing convention the project already uses
  for character reference/preview/source/study folders, keeps the shipped Web build lean.
- `tests/test_asset_store_plugins.gd` (new, 20 assertions).

## Acceptance Criteria / Tests
- Full suite: 2141/0 (session start, after the publish-to-github PUBLISH-button PR merged) -> 2161/0,
  zero regressions. Re-ran the exact same commit twice to rule out flakiness noise: 2161/0 both times.
- New test suite covers: zero native binaries anywhere under `addons/` (the decisive Web-export
  safety check, scanned at the file-system level, not just trusted from the asset pages); the export
  filter actually excludes each addon's demo content; every `plugin.cfg` exists, is listed in
  `project.godot`'s enabled list, and its declared name matches; Weather FX's lack of a `plugin.cfg`
  is confirmed as the addon's own intentional design, not an integration oversight; both autoloads
  (`Juicee`, `DialogueManager`) are present and their expected methods exist; `WeatherFX.effects()`
  and `ItemShapeBreakableItem.take_hit()` are directly callable.
- Real Web export + browser smoke (`controls-probe.mjs`, full existing suite): first run showed one
  failure (`vision-hotkeys-removed`, a node-count-off-by-one); re-ran the probe against the EXACT
  SAME unchanged export a second time and it passed -- confirmed this is the same pre-existing,
  already-logged bandit-vision-overlay flakiness (see `retro/issues.md`, logged earlier this
  session from a clean `main` export with none of this change's code), not caused by the plugins.
  Final run: `VERDICT PASS`, 0 console errors, with all four plugins present and three enabled.

## Outstanding / required follow-up (not done here, flagged for the owner)
- **Weather FX Free's CC BY 4.0 license requires a credit line somewhere in the game or its
  credits**: `Weather FX Free by heyheythere - https://heyheythere.itch.io/weather-fx-free - CC BY 4.0`.
  No credits screen/file exists anywhere in the project yet, so this has nowhere to go yet -- flagging
  for the owner rather than inventing a new credits UI unprompted.
- None of these four plugins are wired into any actual gameplay system yet (no script anywhere
  calls `Juicee.*`, `WeatherFX.add(...)`, places a `BreakableItem`, or loads a `.dialogue` file).
  They are installed, enabled, and verified functional, ready to be called from gameplay code on
  request -- adding real usage (e.g. `Juicee.hit_spark()` on a kunai hit, a `BreakableItem` crate in
  the arena, a rain `WeatherFX` overlay) was out of scope for "add the plugins" and would be its own
  follow-up order with its own integration-risk review against the existing hand-built camera/hit-fx
  systems (see the original recommendation message for why Juicee in particular needs care there).

## Handoff / Notes
- Lit (2D Lighting Engine) was investigated and explicitly rejected -- see Investigation section.
  Do not re-add it without first getting this project off the GL Compatibility renderer, which is
  itself a much larger decision than this order.
## Fix-up (same PR, before merge): real CI caught two things local-only testing missed

Local verification had only run `godot_ci.py tests` (unit/integration GDScript tests) and the
browser smoke suite -- NOT the separate `godot_ci.py validate-resources` step
("Validate all scripts and scenes load" in the actual GitHub Actions job), which walks and loads
EVERY script/scene under res:// outside the editor. The first push to this PR failed real CI with
two genuine problems this walker alone catches:

1. **Dialogue Manager ships optional C# wrapper scripts/scenes.** This project has no Mono/.NET
   Godot build (pure GDScript, confirmed by the engine's own "No loader found for resource ...
   (expected type: Script)" error for every .cs file). Fix: deleted all 10 .cs/.cs.uid files across
   the four addons (9 in Dialogue Manager, 1 in Juicee) and the 3 scenes that specifically depended
   on one (`DialogueLabel.tscn`, `ExampleBalloon.tscn`, `SmallExampleBalloon.tscn`) -- their
   lowercase GDScript-only equivalents (`dialogue_label.tscn`, `example_balloon.tscn`,
   `small_example_balloon.tscn`) were confirmed clean and kept. `tests/test_asset_store_plugins.gd`
   now also scans for `.cs` anywhere under `addons/` (folded into the existing native-binary scan),
   so this can never silently regress on a future addon update.
2. **Breakable 2D Sprites' bundled `test_scene/breakable_sandbox.tscn` references
   `res://built_items/diamond.tscn` and `.../discoball.tscn` -- generated output files the addon's
   own editor dock tool would create, which do not ship in the zip and were never generated** (doing
   so would require a live interactive Godot editor session, out of scope here). Fix: deleted the
   entire `addons/breakable_2d_sprites/test_scene/` folder (the broken bundled demo scene and its
   sample art) -- the addon's real, importable classes (`ItemShapeBreakableItem`,
   `ItemShapeContourTracer`, `ItemShapeFracture`, already covered by the new test) are unaffected.
   Removed the now-dead `addons/breakable_2d_sprites/test_scene/*` entry from
   `export_presets.cfg`'s `exclude_filter` since the folder no longer exists.
3. **A third, subtler failure surfaced only after fixing the first two**: Dialogue Manager's own
   in-editor dock UI (`views/`, `components/`) is written as `@tool` scripts that call
   `EditorInterface` -- a singleton that only exists inside the actual Godot EDITOR process, not in
   plain `--headless` mode (which is exactly how both `validate-resources` and the shipped game
   run). This is not a bug in the addon; it genuinely cannot compile outside an editor session, by
   design. Patching vendored third-party code to work around this was rejected as too invasive.
   Fix: extended `scripts/ci/godot_walker.py`'s own `SKIP_DIR_PATHS` (the exact mechanism this
   project already uses to exempt `res://scripts/ci`) to also skip
   `res://addons/dialogue_manager/views` and `res://addons/dialogue_manager/components` from the
   walker specifically -- NOT a `.gdignore` (which would also block Godot's own editor/import
   pipeline from using these `.tscn` scenes, breaking the real in-editor dock). The actually-played
   game never touches these classes (only the real Godot editor's dock does), so this changes
   nothing about runtime behavior, only what the extra CI walker chooses to load-test.

Verified locally before re-pushing: `godot_ci.py validate-resources` -> `0 failures` (was 7, then 1
after the first two fixes); full test suite 2160/0; real Web export + browser smoke `VERDICT PASS`.

## Second fix-up (same PR, before merge): project.godot got silently rewritten

Running `godot_ci.py import` (which boots the actual Godot editor process to pick up the new
plugins) caused Godot's OWN ConfigFile serializer to resave the ENTIRE `project.godot` file in its
canonical format when persisting the plugin-enable transition. This silently reformatted every
existing section AND, far more seriously, **dropped two real settings**: `window/stretch/aspect="keep"`
and `[physics] common/physics_ticks_per_second=60`. Caught this before pushing by diffing the full
file against origin, not just trusting the targeted lines I intended to add.

Fix: reverted `project.godot` to the clean original file, then made ONLY the three intended
additions by hand as plain text edits (two autoload lines + one `[editor_plugins]` block) -- net
diff is exactly 7 inserted lines, zero deletions, zero reformatting. Juicee's autoload is now
written with plain path syntax (`res://addons/juicee/core/juicee.gd`) instead of the `uid://` form
Godot's own self-registration produced, matching this project's existing autoload convention
(WebBridge/DebugTelemetry/BrowserDebug all use path syntax) and avoiding ever needing Godot to
resolve/write a UID by itself again.

Re-verified the hand-edited file is sufficient WITHOUT ever letting Godot's editor process touch it
again: ran `tests`, `validate-resources`, `export`, and the browser smoke suite using only plain
`--headless --script`/export-template invocations (none of which go through EditorPlugin enable/
disable code paths), hashing `project.godot` before and after every single step -- the hash never
changed. All four plugins (including both autoloads) load and work correctly from the hand-written
file alone; the earlier editor-driven resave was never actually necessary.

**Lesson for any future addon-enabling work in this repo**: never run a Godot EDITOR process (even
just for an "import" pass) against a project.godot that was just hand-edited to add plugins/
autoloads, without diffing the ENTIRE file afterward -- not just the lines you expected to change --
before trusting it. Logged to `retro/decisions.md`.
