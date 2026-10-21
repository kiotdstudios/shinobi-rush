# Camera impact (hit kick): parameter guide and event contract

Owner: Kiro (camera only). Order: `orders/Kiro/2026-10-20-combat-camera-feedback-animation.md`. Job report: `orders/Kiro/reports/2026-10-20-combat-camera-feedback-report.md`.
Module: `scripts/camera/camera_impact.gd` (`class_name CameraImpact`). Tests: `tests/test_camera_impact.gd` (100 checks). Every number below is a PROVISIONAL starting value to tune in a playtest on a real GPU at 60 FPS; none of it has been felt yet.

**Nothing calls the module yet.** In normal play nothing moves: wide and close presets, follow, limits, the lab and the URL options behave exactly as before. The kick only plays when something calls `CameraImpact` (today: the lab demo keys; later: Aki's confirmed-hit code, see the contract).

## What it does

One procedural camera kick per confirmed hit. It writes `Camera2D.offset` and nothing else (never position, smoothing, limits, zoom or preset), eases back, and ends at exactly `Vector2.ZERO`.

- Envelope: a linear rise to EXACTLY the peak within one 60 Hz tick (16.7 ms: a kick, not a ramp), then a quadratic ease-out `(1 - u)^2` to EXACTLY zero at the duration (zero slope there). It is a pure function of the time since each impulse started: no integration, no drift, no randomness, any frame rate.
- Units: peak and duration are SCREEN px and ms. `Camera2D.offset` is in WORLD px (before zoom), so the module divides by the CURRENT zoom every frame. 5 screen px = 11.25 world px at the wide zoom (0.4444) and 4.13 world px at the close zoom of the 104 px art (1.2115). The kick looks the same size at either preset, at the lab's zoom steps (tested at the 1x step) and across a preset switch.
- Direction: along `dir` = attacker to target (the camera is pushed toward what was hit, `KICK_SIGN` +1). A zero direction is counted and moves nothing.
- Several impulses combine into one offset: the magnitude-weighted mean direction times the root-sum-square of the magnitudes (so same-direction hits do NOT add linearly, opposite hits cancel, one hit is exact), never longer than `MAX_TOTAL_PX`. At most `MAX_ACTIVE` impulses are alive; the oldest is dropped.
- Runtime: the first call creates ONE small helper node `CameraImpact` under the player's `Camera2D` (found through the `player` group), so no scene or controller needs an edit. It runs on frame time (`PROCESS_MODE_ALWAYS`): local hitstop (a per-entity timer, not `Engine.time_scale`) and pause do not freeze a kick half way. When nothing is alive its `_process` is off.
- Safe no-ops: no player or camera, called before the tree exists, `settings.enabled == false`, `scale == 0`, non-finite / zero / negative peak or duration. A disabled call does not even create the helper.

## Event contract for Aki (confirmed-hit integration)

### The call (static, one line)
```gdscript
CameraImpact.light_hit(dir)                          # 2.5 screen px, 80 ms
CameraImpact.heavy_hit(dir)                          # 5.0 screen px, 120 ms
CameraImpact.impulse(dir, peak_px, duration_ms)      # custom strength; peak in SCREEN px, duration in ms (max 5000)
```
- `dir`: world-space direction attacker to target, any length (it is normalised inside), `Vector2.ZERO` allowed (counted, no movement).
- When: ONCE per CONFIRMED contact, right after the hit is accepted (after `enemy.take_damage(...)`). Never per active frame, never on a whiff or on startup/recovery frames.
- Return value: none. The call cannot fail; it is a silent no-op in every unusable case (see above), so combat code and headless combat tests may call it freely. In a test with a player and camera in the tree the first call adds one child node `CameraImpact` under the `Camera2D`.
- Suggested mapping: `heavy_hit` when `_attack_def.hitstop_ms >= 70.0`, else `light_hit`. With today's table (main 91eb294: light1 40 ms, light2 45, light3 75, dash_attack 55, air_attack 40) only `light3` is heavy; tune the threshold or call `impulse` per attack in playtest.

### Paste-ready snippet
The confirm site is `PlayerController._check_attack_hits()` in `scripts/player/player_controller.gd` (lines 413-414 on main 91eb294; the numbers move with every combat PR, so search for `enemy.take_damage(`). Add the marked lines right after them; `to_enemy` is already in scope and is not normalised, which is fine:
```gdscript
		_hit_targets.append(enemy)
		enemy.take_damage(_attack_def.damage, to_enemy.normalized(), _attack_def.knockback, _attack_def.hitstop_ms)
		_hitstop_timer = maxf(_hitstop_timer, _attack_def.hitstop_ms / 1000.0)
		# Camera kick: ONE call per confirmed contact (docs/development/CAMERA_IMPACT.md).
		if _attack_def.hitstop_ms >= 70.0:
			CameraImpact.heavy_hit(to_enemy)
		else:
			CameraImpact.light_hit(to_enemy)
```
(An if/else on purpose: a one-line ternary of two calls trips GDScript's STANDALONE_TERNARY warning.) Checked by applying exactly these lines to a throwaway copy of main 91eb294 plus this PR, outside the repo: the project imports without errors and the whole suite stays at 722 passed, 0 failed (Aki's combat tests then run the call on every hit). A sweep that hits three enemies in one frame makes three calls; the combine rule turns three light hits into 4.33 px (2.5 x sqrt 3) and the cap holds the rest. For exactly one kick per swing, call once per swing instead (for example after the loop, with `facing8`).

### What Aki must NOT do
- Never write `camera.offset`, `camera.zoom`, `camera.position`, the limits or the smoothing for combat feedback. `CameraImpact` is the single writer of `Camera2D.offset` (it writes exactly zero when an effect ends); zoom belongs to `CameraPreset` and the lab.
- Never call it every frame of an attack, on a miss, or from `_physics_process` of a swing in progress.
- Do not scale the strength by `Engine.time_scale` or hitstop time, and do not add a second shake on the same event.
- Do not pass the player's position or the knockback vector as `dir` (it must be attacker to target).

### For Orcha and Codex
Any other event source (Lightning Clone contact, Chidori, an enemy hit on the player, a landing) calls the same API with a direction and, if its strength differs, `CameraImpact.impulse(dir, peak_px, duration_ms)`. Do not add another camera shake. A future camera director must not write `Camera2D.offset` either (the module writes zero at the end of an effect and would erase it): route through `CameraImpact`, or agree with Kiro on one combined writer first. Presets only set the BASELINE zoom (`CameraPreset`, `camera_baseline_changed`); the kick never touches it.

## Parameter guide

All tunables are `const` in `scripts/camera/camera_impact.gd`. "Band" is the order's starting target.

| Tunable | Default | Unit | Band from the order | Punchier | Calmer |
| --- | --- | --- | --- | --- | --- |
| `LIGHT_PEAK_PX` | 2.5 | screen px | 2-3 | up to 3 | down to 2 |
| `LIGHT_MS` | 80 | ms | 60-100 | longer (100) lingers | shorter (60) is snappier |
| `HEAVY_PEAK_PX` | 5.0 | screen px | 4-6 | up to 6 | down to 4 |
| `HEAVY_MS` | 120 | ms | 100-140 | longer (140) | shorter (100) |
| `MAX_TOTAL_PX` | 6.0 | screen px | top of the heavy band | raise only together with `HEAVY_PEAK_PX` (a stack can never exceed it) | lower to flatten pile-ups |
| `KICK_SIGN` | +1 | sign | direction not specified | +1 pushes toward the target (the hit lands "into" the frame) | -1 recoils away from the target |
| `RISE_S` | 1/60 | s | "a kick" | keep at one tick | a longer rise turns the kick into a push |
| `MAX_ACTIVE` | 8 | impulses | uncontrolled stacking | n/a | fewer drops the oldest sooner |
| `MAX_MS` | 5000 | ms | | longest accepted duration | |
| `REDUCED_SCALE` | 0.5 | factor | disable/reduce setting | | the "reduced" mode |
| `SLOW_MS` | 1500 | ms | demo only | | lab key 0: the heavy kick stretched so it can be watched and screenshotted (same peak) |

Switches (not tunables): `CameraImpact.settings.enabled` (true) and `.scale` (1.0; 0.5 = "reduced"; 0 = off; clamped to 0..1, it can only soften the effect). `CameraImpact.apply_mode("off" | "reduced" | "on")` sets both. Page URL `?camera_impact=off|reduced|on` is read once at boot by `WebBridge` the way `?camera=` is (the first occurrence wins, an unknown or empty value means `on`). With no URL option, a browser that reports `prefers-reduced-motion: reduce` starts in `reduced`; the URL still wins. A future settings menu only needs to set `settings.enabled` and `settings.scale`. Disabling mid-effect stops the kick on the next frame and puts the offset back to exactly zero.

### Tuning procedure
1. Run the game, press `Tab` (lab) and use `7` light, `8` heavy, `9` burst of three lights 40 ms apart, `0` slow heavy (5 px for 1500 ms: the direction and distance are visible; it kicks along the player's facing). The lab panel row "Cam kick  7 8 9 0" has buttons for the same four.
2. Judge strength with real hits at 60 FPS on a real GPU once the contract is wired. The CI browser renders only a few FPS (3 to 11 measured) and cannot show an 80 ms effect; use the telemetry there (below).
3. Change one constant at a time: peak first (strength), then duration (snappy against floaty), then the cap. Heavy should be clearly stronger than light and never read as a camera bug.
4. Stay inside the order's bands unless the owner agrees. `tests/test_camera_impact.gd` pins the defaults to the bands on purpose: change the band tests and this table together, never only the constant.
5. Check `?camera_impact=reduced` (everything x0.5; heavy 2.5 px) still reads as a hit but is calm.
6. Re-run the tests (the module's 100 checks) and the controls probe (bands in screen px at wide and close).

### Edge and limit behaviour
- Godot 4.7.2 adds `Camera2D.offset` AFTER smoothing and AFTER the limit clamp (measured in the real main scene: at the east limit an offset of +12 world px showed 12 px of void beyond the arena; the view always shifts by exactly the offset). A plain offset would therefore reveal the void at a wall. The module clamps per axis into `[limit_min - view_min, limit_max - view_max]` (the range always contains 0, it only ever shrinks the offset toward 0, never flips it). A kick toward a wall shrinks to the room that is left and is 0 while the camera is pinned at that wall; a kick away from the wall plays at full strength. The arena has no margin east and west (the figure already stands at the screen edge there), so a hit toward those walls shows no camera kick (deliberate: the order asks for no clipping at the screen edges). Watch this in the first playtest ("heavy hits at the wall feel dead"); `KICK_SIGN` -1 (recoil) always has room except at the opposite wall.
- The clamp uses the centre AFTER the write. `Camera2D.set_offset()` makes the engine run its camera update once more (`_update_scroll()` calls `get_camera_transform()`), which advances the position smoothing one extra step for the rendered frame and then restores the smoothing state (Godot 4.7.2 carries a FIXME about smoothing being applied more than once per frame). On a MOVING camera the view that is really rendered is therefore one frame of camera travel closer to a wall than the centre read before the write, and a clamp computed only from that earlier centre over-estimates the room. The module clamps, writes, reads the centre the engine reports now, clamps again from it and rewrites only when the result differs; the rewrite repeats the same update, so the second pass is exact. A single pass showed void at the screen edge for a few frames when a hit landed while the player ran into a wall (the independent review measured up to 5.7 world px walking and 6.9 sprinting at the wide zoom, 3.8 and 4.1 at the close zoom, i.e. up to the whole kick); a still camera is exact either way. `tests/test_camera_impact.gd` guards this with a player who walks into the east wall on real frames, with the helper in its automatic mode and a heavy hit every 7th frame, at close and at wide: the rendered view must be inside the limits on every frame. The manual `advance()` cases cannot see the defect, because a still camera has no smoothing step and a coroutine resumed at `process_frame` runs before the camera's own update.
- What the second pass does NOT remove (an engine quirk, documented, not a defect of the module): while an effect runs on a MOVING camera, the rendered frame is ahead of the no-kick camera path by up to one frame of camera travel, because of the same extra smoothing step. The independent review measured at most 5.69 world px walking and 8.78 sprinting (wide 2.5 and 3.9 screen px, close 6.9 and 10.6 screen px), constant while the effect runs and gone on the frame after it ends. The engine restores the persistent smoothing state, so nothing drifts (deviation from the no-kick path on the last frame after the effect: 0.000000), but the rendered frames during the effect are not the no-kick frames. Felt result: when running, the kick reads slightly larger in the direction of travel. Possible later improvement, not done: run the helper before the camera (a lower `process_priority` than the camera's) and use the centre after the write as the exact prediction of the camera's own update, which would remove the extra step.
- Drift: the effect is a pure function of time and ends with an exact `Vector2.ZERO` write, so `camera.offset`, `get_screen_center_position()`, `position`, smoothing, limits and `zoom == camera_baseline` are exactly as before after settling (tested after light, heavy, three rapid hits, 100 hits in one frame, a 200 ms frame, a preset switch mid-effect and a disable mid-effect).
- Frame time: a long frame is evaluated in 60 Hz sub-steps (at most 1 s per frame), so the telemetry peak is the same at 5 FPS in a browser and at 60 FPS; the camera itself shows the value at the end of the frame.
- Zoom pulse: LEFT OUT. The order's optional 1-2 % pulse was measured: at the east limit +1.5 % zoom moves the view 7.81 world px (9.6 screen px at 1.2115) toward the wall because Godot re-pins the view to the limit, which is more than the whole 5 px kick, and `refresh_camera_baseline()` cannot follow a pulsed zoom. The offset-only effect keeps `zoom == camera_baseline` by construction.
- Freeing the helper (or the camera) mid-effect puts the offset back to zero at once.

## Demo keys, telemetry and settings in the Web build

Lab keys (the lab must be open, `Tab`): `7` light, `8` heavy, `9` burst of three lights, `0` slow heavy; registered at runtime like `N`, active only while the lab is open. Digits, not the H / G / B of the first idea: the repo's key-collision tests compare physical keys only, and `H`, `G`, `B` are taken by the telemetry HUD's Ctrl+Alt chords.

`window.__SHINOBI_STATE__` gains seven additive fields (existing names unchanged); the kick offset is in SCREEN px:

| Field | Meaning |
| --- | --- |
| `cfx_enabled` | `settings.enabled` |
| `cfx_scale` | `settings.scale` (raw setting: 1, 0.5, 0) |
| `cfx_active` | an impulse is still running |
| `cfx_offset_x`, `cfx_offset_y` | offset applied this frame (WebBridge runs last in the frame, so it is the offset about to be rendered) |
| `cfx_peak_px` | largest length of the offset of the CURRENT or LAST effect (resets when a new effect starts while none runs) |
| `cfx_count` | accepted impulses since boot (a zero direction counts; disabled or invalid calls do not) |

Browser checks must read the telemetry, never sample the live trace: wait for `cfx_count` to increase, then for `cfx_active == false`, then read `cfx_peak_px` and assert `cfx_offset_x == cfx_offset_y == 0` and `zoom` equal to the preset baseline.

Measured on a local Web export (software-GL Chromium, 3 to 11 FPS): light 2.500 px, heavy 5.000 px at both the wide (0.4444) and the close (1.2115) preset; burst of three at 5 FPS 3.536 px (two hits landed in the same frame); `reduced` 1.250 and 2.500 px; `off` leaves `cfx_count` and `cfx_peak_px` at 0. A slow-kick screenshot pair matched the published offset to 0.04 px at close and 0.26 px at wide, and the world returned pixel-identical to the baseline afterwards. See the job report for the full table.

## Trace table (deterministic, from the in-engine test)

Screen px along the hit direction, sampled every 60 Hz tick of the pure core (`CFX_TRACE` in the test log). Light 2.5 px / 80 ms, heavy 5 px / 120 ms, "burst" = three light hits 40 ms apart, "rapid" = three heavy hits 50 ms apart.

| t (ms) | light | heavy | burst (3 light, 40 ms apart) | rapid (3 heavy, 50 ms apart) |
| ---: | ---: | ---: | ---: | ---: |
| 0.0 | 0.000 | 0.000 | 0.000 | 0.000 |
| 16.7 | 2.500 | 5.000 | 2.500 | 5.000 |
| 33.3 | 1.357 | 3.517 | 1.357 | 3.517 |
| 50.0 | 0.561 | 2.294 | 1.601 | 2.294 |
| 66.7 | 0.111 | 1.332 | 1.776 | 5.174 |
| 83.3 | 0.000 | 0.630 | 0.976 | 3.573 |
| 100.0 | 0.000 | 0.187 | 2.258 | 2.302 |
| 116.7 | 0.000 | 0.005 | 1.170 | 5.174 |
| 133.3 | 0.000 | 0.000 | 0.443 | 3.573 |
| 150.0 | 0.000 | 0.000 | 0.062 | 2.302 |
| 166.7 | 0.000 | 0.000 | 0.000 | 1.332 |
| 183.3 | 0.000 | 0.000 | 0.000 | 0.630 |
| 200.0 | 0.000 | 0.000 | 0.000 | 0.187 |
| 216.7 | 0.000 | 0.000 | 0.000 | 0.005 |
| 233.3 | 0.000 | 0.000 | 0.000 | 0.000 |

Reading it: the peak is reached on the first tick and never exceeded by a single hit; each effect is exactly 0 at its end; three heavy hits 50 ms apart peak at 5.17 px (root-sum-square of 5 and the decayed 1.33), below the 6 px cap; the burst of lights stays at or under the first hit's 2.5 px (its later bumps are 1.78 and 2.26 px). Three lights landing in the same frame, as happens at 5 FPS in a browser, give 2.5 x sqrt 3 = 4.33 px.

## Tests

`tests/test_camera_impact.gd` (one `run` line in `tests/run_tests.gd`), 100 checks: the pure core (envelope, peak within one tick, zero at the end, determinism, hostile inputs, stacking and cap, trace table, unit conversion at wide and close, the edge clamp incl. 500 random cases, URL parsing, the seven state fields) and real-scene checks with a real player and camera advanced at a fixed 1/60 s step (no hit, light, heavy, three rapid hits, 100 hits in a frame, a 200 ms frame, nonsense deltas, disabled and scale 0 and 0.5, each of the four limits toward and away from the wall, the lab's zoom step, a preset switch mid-effect, a free mid-effect, real frames during local hitstop, the lab keys and buttons), plus the moving camera on real frames, at close and at wide (4 checks: the player walks into the east wall at 5 world px per frame with the helper in its automatic mode and a heavy hit every 7th frame; the rendered view must be inside the limits on every frame, then the offset is exactly zero, the zoom is on the baseline and the published offset was the written one). The manual `advance(TICK)` cases do not reproduce the engine's frame order; the moving-camera case is the one that guards the edge clamp. Run them with the whole suite: `python scripts/ci/godot_ci.py tests --project . --godot <godot>`.
The tests were shown to go red under four temporary mutations of the production code (peak 2.5 to 7, the final zero offset never written, the edge clamp bypassed, the second clamp pass after the write removed); see the job report.

## Not verified

Real GPU rendering, the 60 FPS feel of the numbers above and Aki's integration (the contract is documented, not wired). The browser checks run on software GL at only a few FPS and read telemetry. The edge behaviour on a moving camera (the second clamp pass and the engine quirk above) was verified headless, on real frames and with the independent review's fixed-60-FPS probes, not in a browser.
