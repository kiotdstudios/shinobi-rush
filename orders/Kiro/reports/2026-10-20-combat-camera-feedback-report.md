# Job Report — Combat camera feedback: one procedural camera-impact module
- Agent: Kiro
- Order: `orders/Kiro/2026-10-20-combat-camera-feedback-animation.md`
- Date: 2026-10-21
- Final status: REVIEW. The PR is open and NOT merged; the order is NOT DONE. Nothing calls the module yet (Aki wires the documented call), and the deployed build has not been checked (after the merge the orchestrator does that).
- Commit / PR: branch `kiro/combat-camera-impact`, PR #50 (https://github.com/kiotdstudios/shinobi-rush/pull/50). Code verified on commit `e2b3114` (step-1 commit `7537ac8`, the probe checks `2d4a604`, `origin/main` 91eb294 merged in two steps, docs). The module, lab, web-bridge, test and probe files are byte-identical (empty `git diff`) to the first export commit `2d4a604`, on which the telemetry cases and the screenshot pairs below were measured; the local export and the controls probe were re-run on `e2b3114` after the second merge of main. Later commits only change the order status, this report and the PR number.

Labels: VERIFIED = I ran it and read the output. ASSUMED = reasoned or derived, not run. Evidence files are local to the build machine (`C:\tmp\shinobi-order01\camfx\evidence\`) and are not in the PR.

## Work completed

Kept small, as the chief asked: one module, its tests, a parameter guide, an event contract for Aki, one local export check.

- **Module** `scripts/camera/camera_impact.gd` (`class_name CameraImpact`): `light_hit(dir)`, `heavy_hit(dir)`, `impulse(dir, peak_px, duration_ms)`. It writes `Camera2D.offset` only and ends at exactly `Vector2.ZERO`.
- **Design (5 lines).** (1) Envelope: a pure function of the time since each impulse started: linear rise to EXACTLY the peak in one 60 Hz tick (16.7 ms), then quadratic ease-out `(1-u)^2` to EXACTLY 0 at the duration. (2) Stacking: unit direction x magnitude per impulse, combined as the magnitude-weighted mean direction x root-sum-square of the magnitudes (same-direction hits are sub-linear, opposite hits cancel), hard cap `MAX_TOTAL_PX` 6, at most 8 live impulses. (3) Runtime: a lazy helper node under the player's `Camera2D` (found by the `player` group), frame time with `PROCESS_MODE_ALWAYS` so local hitstop and pause do not freeze it, screen px divided by the CURRENT zoom. (4) Edge clamp (needed, measured): Godot 4.7.2 adds `Camera2D.offset` after smoothing AND after the limit clamp, so the module keeps the view inside the camera limits itself; a kick toward a pinned wall shrinks to the room left. (5) Lab keys, `?camera_impact=`, telemetry; no zoom pulse.
- **Tunables and numbers** (PROVISIONAL, order bands in brackets): light 2.5 screen px / 80 ms (2-3 px, 60-100 ms), heavy 5.0 px / 120 ms (4-6 px, 100-140 ms), cap 6.0 px, rise 1/60 s, 8 live impulses, longest 5000 ms, reduced = x0.5, slow demo 1500 ms. The full table with "punchier / calmer" columns is in `docs/development/CAMERA_IMPACT.md`.
- **Settings:** `CameraImpact.settings.enabled` / `.scale` (0..1; 0.5 = reduced; 0 = off); page URL `?camera_impact=off|reduced|on` parsed once in `WebBridge` like `?camera=` (first value wins, garbage = on); default `reduced` when the browser reports `prefers-reduced-motion: reduce` (the URL still wins).
- **Demo trigger (my files only):** lab keys `7` light, `8` heavy, `9` burst (three lights 40 ms apart), `0` slow heavy (5 px peak stretched to 1500 ms), active only while the lab is open, plus a "Cam kick  7 8 9 0" button row. They kick along the player's facing.
- **Telemetry** in `__SHINOBI_STATE__` (additive; screen px): `cfx_enabled`, `cfx_scale`, `cfx_active`, `cfx_offset_x`, `cfx_offset_y`, `cfx_peak_px`, `cfx_count`.
- **Docs:** `docs/development/CAMERA_IMPACT.md` (parameter guide, tuning procedure, edge behaviour, trace table, the event contract for Aki with a paste-ready snippet, a line for Orcha/Codex), a bullet in the camera section of `GODOT_PROJECT_HANDOFF.md`, one line in `TESTING.md`.
- **Default experience unchanged (VERIFIED):** nothing calls the module in normal play. With no demo key pressed the telemetry stays at `cfx_count` 0, `cfx_peak_px` 0, offset (0, 0) in the wide and the close preset (10 frames observed on each), and all 16 pre-existing controls-probe checks (walk, sprint, wall, lab zoom, `?camera=` presets) still pass on the export.
- **Zoom pulse: left out.** VERIFIED by measurement (Godot 4.7.2 headless, real main scene): at the east limit a +1.5 % zoom moves the view centre 7.81 world px = 9.6 screen px at 1.2115, toward the wall, more than the whole 5 px kick, and `refresh_camera_baseline()` cannot follow a pulsed zoom. The offset-only effect keeps `zoom == camera_baseline` by construction.

## Files changed
`git diff --stat origin/main...HEAD` at the time of writing: 13 files, +1315 / -5, only allowed files, no screenshots or capture files.
- New: `scripts/camera/camera_impact.gd` (+ `.uid`), `tests/test_camera_impact.gd` (+ `.uid`), `docs/development/CAMERA_IMPACT.md`, this report.
- Edited: `scripts/ui/animation_lab.gd` (demo actions, button row, help line), `scripts/web/web_bridge.gd` (URL option, seven state fields, `process_priority = 1`), `tests/run_tests.gd` (one include line), `scripts/ci/smoke/controls-probe.mjs` (six new checks), `docs/development/GODOT_PROJECT_HANDOFF.md` (+1 bullet), `docs/prototype/TESTING.md` (+1 line), the order file (status log).
- Decisions: digits `7 8 9 0` instead of the brief's `H G B Shift+G` (see Issues); `process_priority = 1` on WebBridge so the published offset is the one about to be rendered. Not touched: `scripts/player/**`, `scripts/combat/**`, `scripts/enemy/**`, sprites, arena, `project.godot`, presets, occlusion, follow, other agents' orders.

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` and `validate-resources` on the final tree | VERIFIED exit 0; 38 scripts, 6 scenes, 0 failures | `evidence/logs/export2/` |
| `godot_ci.py tests` baseline, clean main 9826590 | VERIFIED 534 passed, 0 failed (the brief guessed 493) | `evidence/logs/tests0.out.txt` |
| `godot_ci.py tests` with the module, before merging PR #43 | VERIFIED 630 passed, 0 failed (+96) | `evidence/logs/final1/` |
| `godot_ci.py tests` after merging PR #43 (main 63bbd6c) | VERIFIED 644 passed, 0 failed | `evidence/logs/final2/tests-builtin.log` |
| `godot_ci.py tests` on the final tree (main 91eb294 merged: PRs #43, #45, #47) | VERIFIED 722 passed, 0 failed; 96 `impact` checks PASS; only the pre-existing intentional `t_badsheet` warning. Baseline for main 91eb294 is 626 = 722 - 96 (ASSUMED, derived, not run on a clean main) | `evidence/logs/final4-tests/tests-builtin.log` |
| RED PROOF 1: `LIGHT_PEAK_PX` 2.5 -> 7.0 | VERIFIED on the 630-check tree of step 1: 618 passed, 12 FAILED (defaults/bands, light peak, exact single impulse, sub-linear stacking, trace table, scene light peak, telemetry peak, 200 ms frame, ...) | `evidence/logs/mut1d/` |
| RED PROOF 2: the final zero offset never written (residual displacement) | VERIFIED (same tree): 607 passed, 23 FAILED (every scene check that needs offset == ZERO and the camera back exactly) | `evidence/logs/mut2/` |
| RED PROOF 3: edge clamp bypassed | VERIFIED (same tree): 625 passed, 5 FAILED (the four limits and the 3 px room case, each shows 11.25 world px of void) | `evidence/logs/mut3/` |
| Restore after the mutations | VERIFIED file hash identical to the verified clean copy, `grep MUTATION` in `scripts/` and `tests/` = 0 | step-1 notes |
| ONE local Web export of `e2b3114` like CI: `import`, `validate-resources`, `export` (GITHUB_SHA = commit), `finalize-export`, `check-export` (an earlier export of `2d4a604` was built the same way, exit 0, and is the one the cases and pairs below were measured on) | VERIFIED all exit 0, 38 MiB, `build-info.json` commit `e2b3114`, 1007 sprite PNG import records in the PCK | `evidence/logs/export2/`, `evidence/logs/export1/` |
| `node --check scripts/ci/smoke/controls-probe.mjs`, then the probe against the export of `e2b3114` | VERIFIED syntax OK; 22/22 PASS (16 existing + 6 new), 0 console errors, 102 s. The same probe on the export of `2d4a604` was 22/22 too (96 s) | `evidence/probe2/run.log`, `evidence/probe1/run.log` |
| Telemetry of every demo case in the browser (table below), export of `2d4a604` | VERIFIED | `evidence/verify-cases.log` |
| Baseline vs mid-effect screenshot pair, wide and close, plus `after` == `baseline` (below), export of `2d4a604` | VERIFIED | `evidence/pair-close/`, `evidence/pair-wide/` |
| The paste-ready snippet for Aki applied to a throwaway copy of the final tree (main 91eb294 + this PR, outside the repo): import, then the whole suite | VERIFIED imports without errors, 722 passed, 0 failed | `evidence/logs/snippet/` |
| Not run locally on purpose (CI runs them): `smoke.mjs`, `debug-probe.mjs`, the occlusion matrix | CI | PR checks |

### Browser telemetry (local export, software-GL Chromium, 3 to 11 FPS, 5 to 6 rendered frames per effect)
Every row ended with `cfx_active` false and `cfx_offset` exactly (0, 0). The zoom never changed except in the case that switches presets on purpose, the player position never changed, and there were 0 console errors.

| Case (key) | Count | `cfx_peak_px` (screen px) |
| --- | --- | --- |
| wide (0.4444): no hit, 10 frames | 0 | 0 |
| wide: light (7) x2 | +1 each | 2.500, 2.500 |
| wide: heavy (8) x2 | +1 each | 5.000, 5.000 |
| wide: burst (9) x2 | +3 each | 3.536, 3.536 (at 5 FPS two hits land in one frame: 2.5 x sqrt 2) |
| wide, lab at the 1x step (Z): heavy (8) | +1 | 5.000, zoom stays 1.0000 |
| wide: slow kick (0), then N at once | +1 | 5.000; ends on the close baseline 1.2115, offset 0 |
| close (1.2115): no hit; light x2; heavy x2; burst x2 | 0; +1; +1; +3 | 0; 2.500; 5.000; 3.536 (same screen px as wide) |
| `?camera_impact=off`: 7, 8, 9 | 0, 0, 0 | 0 (`cfx_enabled` false) |
| `?camera_impact=reduced`: 7, 8 | +1 each | 1.250, 2.500 (`cfx_scale` 0.5) |
| `?camera_impact=bogus`: 8 | +1 | 5.000 (garbage = on) |
| `?camera_impact=off&camera_impact=on`: 8 | 0 | 0 (first value wins) |
| `prefers-reduced-motion: reduce`, no query: 8 | +1 | 2.500 (`cfx_scale` 0.5) |
| `prefers-reduced-motion: reduce`, `?camera_impact=on`: 8 | +1 | 5.000 (the URL wins) |

### Screenshot pair (slow kick, key `0`: 5 px peak, 1500 ms)
A Playwright screenshot takes about 1 s on this software-GL browser (the game renders about 10 frames meanwhile), so it cannot be tied to one published state. The scratch script instead registers a `requestAnimationFrame` callback after the engine's own and, whenever `state.frame` changed since the previous callback (published in that same iteration, before the draw), reads `canvas.toDataURL()`: the PNG is exactly the frame the state describes. The shift of the ground between `baseline.png` and each mid-effect frame was fitted on four ground-only crops (HUD, lab panel, figures and blocks excluded) with a sub-pixel search, and compared with the published `cfx_offset_y`:

| Preset | Frames | Published offset (px) | Measured ground shift | Max / mean error over 28 measurements |
| --- | --- | --- | --- | --- |
| close 1.2115 | 30-36 | 3.890, 3.134, 2.462, 1.872, 1.377, 0.934, 0.615 | 3.90, 3.16, 2.48, 1.86, 1.38, 0.94, 0.60 | 0.037 / 0.013 px |
| wide 0.4444 | 29-35 | 4.149, 3.366, 2.674, 2.125, 1.562, 1.074, 0.719 | 3.96, 3.16, 2.48, 1.96, 1.32, 0.96, 0.72 | 0.262 / 0.160 px (measured is smaller by 0.16 px on average) |

- Direction VERIFIED: the player faces down, so the camera moves down and the world moves UP on screen.
- Return VERIFIED: `after.png` (taken after the effect) equals `baseline.png` pixel for pixel on all eight ground crops (0 of 665,090 pixels differ): no residual displacement. HUD and legend text pixels are identical between baseline and mid-effect (0 differing), so only the world moves.
- The wide error is larger because the 2D ground texture is sampled with the project's nearest filter (`default_texture_filter=0`) while minified 2.25 times, so the aliased image does not translate smoothly. That cause is ASSUMED (not isolated); the error stays under 0.3 px.
- Pictures opened, one per call. Close baseline: lab open at the close preset, State IDLE, Pos (0, 135); the "Cam kick 7 8 9 0" row is in the lab panel; stand, player and bandit stand on brick paving, the bandit label is at y 245 and the big block's top edge at y 524. Close mid-effect (frame 30, +3.89 px): the whole world sits about 4 px higher (label y 241, block edge y 520) while the HUD, lab panel and key legend are on the same pixels; no void at any edge. Wide baseline: wide preset, five placeholder blocks, small figures near the centre. Wide mid-effect (frame 29, +4.149 px): the world is about 4 px higher (the bottom block's lower edge y 500 -> 496, the left block's label y 189 -> 185) and the HUD text is unchanged.

### Trace table (deterministic, pure core, printed by the in-engine test `CFX_TRACE`)
Screen px along the hit direction at every 60 Hz tick. Burst = three lights 40 ms apart, rapid = three heavy 50 ms apart.

| t (ms) | light 2.5 px / 80 ms | heavy 5 px / 120 ms | burst | rapid |
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

Peaks stay inside the order's bands (light 2.5 in 2-3, heavy 5.0 in 4-6), each effect is exactly 0 by its duration (light by 100 ms, heavy by 140 ms), three rapid heavy hits never pass 5.17 px (cap 6) and end at exactly 0.

## Issues encountered
- **The brief's demo keys `H G B Shift+G` break existing tests.** VERIFIED by running them: 3 failures (`dt: new actions do not reuse any existing key`, `bd: dbg_* keys do not collide with each other`, plus my own digit check) because the repo's key-collision tests compare physical keys only and `H G B` are the telemetry HUD's Ctrl+Alt chords. Used the digits `7 8 9 0` next to the overlay digits 1-6.
- **Godot 4.7.2 applies `Camera2D.offset` after the limit clamp** (VERIFIED, measured): an unclamped kick east at the east limit showed 12 px of void. The module clamps; consequence: no camera kick toward a wall while the camera is pinned there (deliberate, matches the order's "no clipping at screen edges").
- **Three hits can land in one frame at low FPS.** At 5 FPS the burst's later hits fire in the same frame and stack as a root-sum-square (3.536 px for two lights); at 60 FPS they are 40 ms apart (trace table). The cap holds either way.
- **`origin/main` moved twice while I worked** (PR #43 Aki's Combat Fluidity Milestone A; then PRs #45 and #47: the bandit art and the jump launch fix). Both merged without conflicts; `tests/run_tests.gd` (the one shared file) auto-merged next to the other agents' include lines. Aki's confirmed-hit site moved from lines 357-358 to 394-395 and then to 413-414 of `player_controller.gd` (same code, search for `enemy.take_damage(`); PR #43 adds `air_attack` (hitstop 40 ms = light). The contract and the snippet were re-checked against the final main. I forgot `godot_ci.py import` once after the second merge: the new bandit PNGs were not imported yet, so the first test run failed with 96 "cannot load" engine errors; after the import it is 722 passed, 0 failed (my slip, not a code defect).
- **`process_priority = 1` on `WebBridge`** is a small semantic change: it publishes the state last in the frame. The other fields are read after the other nodes' `_process` instead of before. Harmless for the probes (they wait on state), but note it.
- **Wide-zoom screenshot error up to 0.26 px** (above): texture minification with a nearest filter, not a module defect (ASSUMED).
- **Tooling:** earlier mutation runs "timed out after 900 s" three times in unrelated existing tests while the same run later finished in 39 s, and the wall clock jumped about an hour between two tool calls; I treat these as host stalls (another agent runs Godot test jobs on the same machine), not code. Everything in this report was re-run clean afterwards.
- No other bugs, blockers or regressions found.

## Findings about other agents' work and hazards
- **Single writer of `Camera2D.offset`.** The module writes exactly zero when an effect ends, so a second writer (for example Orcha's future camera director) would be erased. Documented in the guide and the handoff; the director should send impulses through `CameraImpact` or agree on one combined writer with Kiro first.
- **Aki's integration is a contract only.** One call per confirmed contact next to `enemy.take_damage(...)`; the snippet was proved to compile and to leave Aki's whole suite green (722 passed) on a throwaway copy of the final tree. With today's attack table only `light3` (75 ms) counts as heavy under the suggested `hitstop_ms >= 70` rule.
- **Hitstop** is a local per-entity timer, so the effect keeps ticking during it (VERIFIED in-engine: "real frames during local hitstop").

## Judgment calls the chief may overturn
1. Lab keys `7 8 9 0` instead of `H G B Shift+G` (forced by the collision tests).
2. No zoom pulse (measured: it moves the view more than the kick at a wall). Reversible by adding it later.
3. `KICK_SIGN` +1: the camera is pushed toward the target (the hit lands into the frame). `-1` recoils away; one constant.
4. Root-sum-square stacking and cap 6 px; light 2.5 px / 80 ms, heavy 5 px / 120 ms (mid-band starting values).
5. Telemetry peak is sampled on 60 Hz sub-steps so a 200 ms browser frame still records the real kick.
6. `prefers-reduced-motion` defaults to `reduced` (about 10 lines; the URL overrides).
7. Six probe checks, each on a fresh page (about +60 s on the controls probe).

## Not verified
- Real GPU rendering and the 60 FPS feel of every number (they are starting values; the CI browser renders 3 to 11 FPS and shows an 80 ms effect in 0 or 1 frames).
- Aki's integration at the confirmed-hit site (not wired: documented contract).
- Other browsers (Firefox, Safari), touch devices, and `prefers-reduced-motion` on a real OS setting (only the Chromium emulation was run).
- The deployed live build (after the merge the orchestrator verifies it).
- `smoke.mjs`, `debug-probe.mjs` and the rest of CI: left to the PR checks.

## Questions for the project owner / chief
1. Which attacks count as heavy? Today only `light3` passes `hitstop_ms >= 70`. Recommendation: wire the suggested rule first and let Aki tune the threshold in the first playtest.
2. Toward the target or recoil away? Recommendation: keep `KICK_SIGN` +1 for the first playtest and flip the constant if it reads wrong.
3. One call per enemy hit or one per swing? Recommendation: per enemy (the cap absorbs a sweep); switch to per swing if multi-hit sweeps feel too strong.
4. Is a zoom pulse wanted after all? Recommendation: leave it out until a playtest asks for it; it needs a baseline-aware design, not a small add-on.
5. Who owns `Camera2D.offset` once a camera director exists? Recommendation: `CameraImpact` stays the single writer and the director sends impulses.

## Outstanding work / next steps
1. Independent review, then the orchestrator merges; verify the deployed build (`?camera_impact=...`, lab keys `7 8 9 0`, `cfx_*` telemetry, controls probe).
2. The orchestrator hands the event contract (`docs/development/CAMERA_IMPACT.md`, section "Event contract for Aki") to Aki; Aki adds the five lines after `enemy.take_damage(...)` in `_check_attack_hits()` (`player_controller.gd` lines 413-414 on main 91eb294).
3. Playtest on a real GPU at 60 FPS and tune the constants (one at a time, inside the order's bands).
4. Chief report and index entry are the orchestrator's job; this job does not write them and does not set the order to DONE.

## Where to look
- Guide and contract: `docs/development/CAMERA_IMPACT.md`; module `scripts/camera/camera_impact.gd`; tests `tests/test_camera_impact.gd`; probe `scripts/ci/smoke/controls-probe.mjs`.
- Order: `orders/Kiro/2026-10-20-combat-camera-feedback-animation.md`. PR: [#50](https://github.com/kiotdstudios/shinobi-rush/pull/50).
