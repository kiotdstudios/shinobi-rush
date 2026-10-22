# Job Report -- Dynamic Combat Camera Director (Rebased + Full Pipeline)
- Agent: Orcha
- Order: orders/Orcha/2026-10-18-dynamic-combat-camera.md
- Date: 2026-10-21
- Final status: REVIEW -- all local tests PASS; live Pages verification pending PR merge
- Branch: orcha/dynamic-combat-camera (rebased onto main 91cd0b1)
- Commits: 1fa72bf (implementation), e2516c8 (RESET fix), c44a572 (report update)

## What this PR adds

CombatCameraDirector -- event-driven Camera2D zoom director for Shinobi Rush.

Sits between CameraPreset (baseline) and CameraImpact (positional shake). Writes additive
zoom delta to Camera2D.zoom each frame. Never touches position, smoothing, limits, or
CameraImpact's offset.

### Architecture
- scripts/camera/combat_camera_director.gd: new director
- Priority stack: FINISHER(6) > JUTSU(5) > HEAVY_HIT(4) > LIGHT_HIT(3) > DODGE(2) > TAKE_DAMAGE(1)
- Lower-priority events silently ignored during active higher-priority effect
- Zoom envelope: quadratic ease-out; finisher: rise-hold-ease-out
- Exponential blend-back (BLEND_RETURN_SPEED=8.0/s)
- MAX_ZOOM_DELTA=0.30 caps any single effect
- CombatCameraDirector.notify(kind, payload) -- single call site, no node reference needed
- All provisional values marked PROVISIONAL with design-intent bands
- Accessibility: zoom_scale/shake_scale (0-1), ?camera_director=off/reduced/on URL param
- Reduced-motion browser preference -> "reduced" automatically
- reset() flushes to baseline for death/pause/scene transitions

### Integration points wired
- player_controller.gd: _check_attack_hits() -> notify LIGHT_HIT or HEAVY_HIT on confirmed contact
- player_controller.gd: _begin_dodge() -> notify DODGE
- Hit events also route to CameraImpact so both systems (zoom + shake) fire from one notify call
- scenes/player/player.tscn: CombatCameraDirector node added (load_steps 8)
- scripts/web/web_bridge.gd: apply_camera_director_query() in _ready(); cam_dir_* telemetry in _process()

### Not yet wired (pending gameplay systems)
- JUTSU: no jutsu system yet; Body Flicker will wire this when merged
- FINISHER: no finisher system yet
- TAKE_DAMAGE: player has no take_damage() path yet

## Files changed
| File | Change |
| --- | --- |
| scripts/camera/combat_camera_director.gd (+.uid) | NEW -- full director |
| scripts/player/player_controller.gd | +9 lines: DODGE notify, LIGHT/HEAVY_HIT notify |
| scenes/player/player.tscn | +3 lines: ext_resource, load_steps 7->8, node |
| scripts/web/web_bridge.gd | +11 lines: boot query, telemetry publish, static helper |
| orders/Orcha/2026-10-18-dynamic-combat-camera.md | Status QUEUED -> REVIEW |
| orders/Orcha/reports/2026-10-21-dynamic-combat-camera-report.md | This file |

## Tests run before commit (rebased on main 91cd0b1)
| Test | Command | Result | Evidence |
| --- | --- | --- | --- |
| Godot import | godot_ci.py import | PASS -- 0 errors, 0 warnings | Tool output |
| Godot test suite | godot_ci.py tests | PASS -- 764 passed, 0 failed (+6 vs main 758) | Tool output |
| Web export | godot_ci.py export + finalize-export | PASS -- 38 MiB, build-info.json written | Tool output |
| Browser smoke | smoke.mjs --serve-dir | PASS -- 11/11, 7 events, 4 warnings (WebGL ReadPixels only), 0 fatal | summary.md |
| Rebase onto main 91cd0b1 | git rebase origin/main | PASS -- clean rebase, no conflicts | git log |
| Diff vs main | git diff origin/main HEAD | Additive only -- no semantic conflicts with Aki/Kiro changes | Diff review |

## Issues encountered
1. Original commit included RESET in EventKind enum causing GDScript parse error -- fixed in e2516c8.
2. Rebase onto 91cd0b1 completed cleanly (Aki's player_controller changes and Kiro's animation_lab
   changes are additive and do not conflict with the camera director additions).

## Report to Chief

Chief --

The CombatCameraDirector is tested, exported, smoke-passed and ready to merge. Here is my full state report.

### What this does in the game right now
Every confirmed light attack hit fires a 4% zoom punch-in lasting 100ms. Every confirmed heavy/dash/air
attack hit fires an 8% zoom punch-in lasting 180ms. Every dodge fires a 3% zoom for 140ms. All effects
ease back quadratically. The zoom is additive on top of your current CameraPreset baseline so it does not
fight the wide/close preset switching.

### Three things I want your read on

1. **Feel during combat.** The provisional values (LIGHT_ZOOM_DELTA=0.04, HEAVY_ZOOM_DELTA=0.08) are
   conservative on purpose. If you want more punch -- like Hades-style impact -- I can raise them. If
   they are distracting, I can lower them. The order doc lists design-intent bands; I stayed at the low
   end of each band for the first pass. Let me know after you test in the live build.

2. **JUTSU event wiring.** The director has a JUTSU event kind ready. When Body Flicker (orcha/body-flicker-in-game-preview)
   merges, I will add one line: CombatCameraDirector.notify(JUTSU, ...) in animation_lab.gd's flicker_demo().
   No new work needed from you -- just confirming the plan so you know the two PRs connect.

3. **FINISHER and TAKE_DAMAGE.** Both event kinds exist in the director and are deliberately not wired --
   those gameplay systems do not exist yet. When Aki implements player damage, the wire is one notify()
   call. When finishers land, same. Nothing for you to approve on these now.

### One question
The director currently fires CameraImpact.light_hit() or CameraImpact.heavy_hit() automatically when
a hit event fires (so you get both the zoom from this director AND the positional shake from CameraImpact).
Is that the right behavior, or should the two systems be independent so you can tune them separately?
Current behavior: zoom and shake always fire together. Alternative: notify() only does zoom; callers
manually fire CameraImpact when they want shake too. Let me know your preference -- it is a 3-line change.

Ready for merge review.

-- Orcha
