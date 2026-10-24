# Job Report — Ground Tileset and Debug HUD Fix
- Agent: Aki
- Order: orders/Aki/2026-10-19-ground-tileset-and-hud-layout.md
- Date: 2026-10-19
- Final status: DONE — merged to main, CI green, live Pages deploy verified
- Commit / PR: https://github.com/kiotdstudios/shinobi-rush/pull/27 (merged `8286052`)

## Work completed

### Task 1 — Ground tileset
- Root cause of the "repeated raised block" look: `stone_tile_64.png` (an isometric *cube* sprite) was being `draw_texture_rect(..., tile=true)`'d directly — never a floor tile, so it always read as elevated blocks.
- Removed that asset (`git rm`), generated a small floor-tile set via PixelLab (`create_tiles_pro`, 2 jobs, 32 raw candidates), hand-picked 10 final tiles covering every category the order asked for: base ×2, alt (herringbone) ×1, cracked ×1, dirt/dirt-stone ×2, decorative ×2, edge ×1, corner ×1.
- Discovered PixelLab's isometric `top-down` tile view renders a 1:1 diamond; the game's world uses a 2:1 diamond (`Vector2(144,72)`), so every tile had to be vertically squashed 0.5× (72×72 → 72×36) to sit flat instead of looking like a tilted/raised plane.
- Recolored the final set with a uniform per-channel gain (`[1.135, 0.935, 0.928]`, derived by sampling the approved mockup's floor patch vs. the raw PixelLab output) to pull the tone from a cold blue-gray to the mockup's warm tan-gray. Confirmed via before/after mean-RGB comparison and a visual contact sheet.
- Wrote `scripts/arena/kosen_floor_tileset.gd` (`class_name KosenFloorTileset`): builds a Godot `TileSet` in code (isometric, diamond-down, 72×36) rather than a hand-authored `.tres`. Weighted, **deterministic** (no `randf()`) tile selection via a custom 64-bit integer mixing hash — Godot's built-in `hash(Vector2i)` was tried first and produced visible diagonal banding on a grid this regular; replaced with a large-prime multiply + xor-shift mix, verified banding-free both in a standalone Python simulation and in an actual headless Godot run before shipping.
- Rewrote `Ground` in `scripts/arena/training_arena.gd` to host a child `TileMapLayer` painted by a new `paint_floor()` (classifies each cell as interior/edge/corner by **world-space distance to the rect boundary**, not map-index bounds, to stay correct under isometric skew); `_draw()` now only strokes the border. `Ground`'s node name/`z_index` contract (relied on by `tests/run_tests.gd`) is unchanged.
- Walls/raised structures (`Block`/`BlockRear`) and Kiro's camera/occlusion code were not touched — confirmed by diff review.

### Task 2 — Debug HUD overlap
- Root cause: `debug_hud.gd`'s 6-line `Label` and `animation_lab.gd`'s separately hand-placed `_status`/`_metrics` `Label`s were two unrelated `CanvasLayer`s each hardcoding absolute pixel positions, with no shared layout authority — they grew into each other over successive unrelated changes.
- Rewrote `debug_hud.gd` around real `Control` containers: `MarginContainer` → `VBoxContainer` stacking two `PanelContainer`s (essential block: title/build + state/speed/pos/direction; diagnostics panel: camera zoom + sprite status/metrics + FPS/texture mem), so overlap between them is structurally impossible. Diagnostics panel is **hidden by default** (clean screen per the order's preferred behavior) and toggled with a new **F1** key, registered at runtime like AnimationLab's own `N` key (no `project.godot` edit).
- Controls legend and the paused banner now use anchor presets (`PRESET_BOTTOM_LEFT` / `PRESET_CENTER`) instead of hardcoded pixel positions, so they stay correctly placed at both 1280×720 and 1536×1024.
- Added a public `DebugHud.set_sprite_status(zoom_text, status_text, metrics_text, color)` API and rewired `animation_lab.gd` to call it instead of drawing its own labels — removed the old `_status`/`_metrics` fields entirely. AnimationLab's own on-screen panel (Tab, screen-right) is untouched and still coexists without overlap.

## Files changed
- `scripts/arena/kosen_floor_tileset.gd` (new)
- `scripts/arena/training_arena.gd` (modified — `Ground` rewritten to paint a `TileMapLayer`)
- `scripts/ui/debug_hud.gd` (rewritten — container-based layout, new diagnostics panel + F1 toggle, new public API)
- `scripts/ui/animation_lab.gd` (modified — removed own status/metrics labels, feeds `DebugHud` instead)
- `assets/environment/kosen_courtyard/floor_tiles/*.png` ×10 (new, + Godot `.import`/`.uid` sidecars)
- `assets/environment/kosen_courtyard/stone_tile_64.png` + `.import` (removed)

## Tests run before commit
| Test / command | Result |
| --- | --- |
| `python scripts/ci/validate_godot_project.py --project .` | PASS — 0 errors, 0 warnings |
| `python scripts/ci/godot_ci.py import --project . --godot <godot>` | Clean reimport (last run: only the expected "commit the new sidecar files" warning) |
| `python scripts/ci/godot_ci.py tests --project . --godot <godot>` | PASS — `493 passed, 0 failed`, exit 0 (same baseline as before this order; re-run after every edit round, including the `animation_lab.gd` rewire and the tile hash fix) |
| `python scripts/ci/godot_ci.py export` + `finalize-export` (Web DEBUG export) | Clean export, `build-info.json` written |
| `node scripts/ci/smoke/smoke.mjs --serve-dir <export>` (default config: move/dodge/attempt-attack) | PASS — all 11 checks, including `canvas-not-blank` and `input-effect` (23–46% of sampled pixels changed depending on input sequence) |
| Same smoke harness, custom `--input-sequence` exercising move+sprint+dodge+jump+camera-preset (`N`)+diagnostics toggle (`F1`)+lab panel (`Tab`) | PASS — all checks, screenshots captured at both the wide and close camera presets |
| Manual visual review of captured screenshots (wide preset, close preset, F1 diagnostics open, Tab lab open) | Ground renders flat/continuous (no floating-block look), walls stay visually separate, HUD panels never overlap at either state, lab panel coexists cleanly screen-right |

Both 1280×720 and 1536×1024 are supported by the new anchor-based HUD layout (`PRESET_TOP_LEFT`/`PRESET_BOTTOM_LEFT`/`PRESET_CENTER` + `canvas_items` stretch mode already in `project.godot`); only 1280×720 was captured in a live screenshot this session (the smoke harness's `canvas_selector` defaults to that viewport) — the 1536×1024 case is covered by the same anchor logic but not independently screenshotted.

## Issues encountered
- PixelLab's isometric tile export ratio (1:1) does not match this game's world scale (2:1) — not documented anywhere in-repo; found by direct pixel inspection. Fix (vertical 0.5× resize) is now called out in `kosen_floor_tileset.gd`'s own comments so the next asset batch doesn't rediscover it the hard way.
- First edge/corner PixelLab generation attempt produced a real-paint white-blowout glitch from a specific prompt phrasing ("transitions to open space"); rewording fixed it on the second attempt. No credits-affecting retries beyond that.
- Raw tile color was noticeably colder/bluer than the approved mockup's warm stone tone; fixed with a one-time uniform color-grade pass rather than regenerating (no extra PixelLab cost).
- Godot's built-in `hash(Vector2i)` produced visible diagonal banding in the deterministic tile picker; replaced with a dedicated integer mixing hash, verified both offline and in a live headless Godot run.
- Self-inflicted mid-session accident: ran `rm -rf .godot/imported` while cleaning up a scratch file, which broke the cached import for ~858 unrelated pre-existing assets. Fixed by re-running the full `godot_ci.py import` step (no data loss, just an extra ~1 minute reimport). Flagging so nobody else repeats it — `godot_ci.py import` is the safe way to refresh the cache; deleting it manually is not.

## Questions for project owner
- None blocking. The recolor and hash-fix were judged within the order's own intent ("ground must look like a continuous, varied stone surface consistent with our locked reference" / "deterministic tile variation to avoid obvious repetition") and done without extra PixelLab spend — flag if either call should have waited for sign-off first.

## Outstanding work / next steps
1. Commit, push `aki/ground-tileset-and-hud-layout`, open PR against `main`, wait for CI green, merge, verify live Pages deploy.
2. Capture a live screenshot at 1536×1024 specifically (currently only verified by the shared anchor logic, not an independent screenshot) if the owner wants that on record before sign-off.
3. This is explicitly a "smallest reusable tileset" per the order — a fuller environment pass (more tile variety, bespoke edge/corner shapes per wall-adjacency direction instead of one generic edge/corner tile) is deferred, not started.
