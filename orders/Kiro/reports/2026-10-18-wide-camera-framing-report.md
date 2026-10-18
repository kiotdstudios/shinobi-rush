# Job Report — Restore wide gameplay camera framing (PR #12)
- Agent: Kiro
- Order: [orders/Kiro/2026-10-18-restore-wide-camera-framing.md](../2026-10-18-restore-wide-camera-framing.md)
- Date: 2026-10-18
- Final status: REVIEW (pushed to PR #12 and tested locally; PR CI results are on the PR checks page; live build not yet verified; DONE is set only by the orchestrator after the live build is verified)
- Commit / PR: PR [#12](https://github.com/kiotdstudios/shinobi-rush/pull/12), branch `fix/restore-wide-camera-framing`. Pushed commits: `4ec5757` (fix), `b7b1752` (tests), `c2baa65` (foot room), `0754d0b` (docs, order, report), plus the review-fix commit that follows it (see `git log` on the branch). Live URL for the later check: https://kiotdstudios.github.io/shinobi-rush/ (serves `main`; not checked by this report).

## Work completed
The owner asked for the previous wider arena view back while keeping 128x128 production sprites. PR #12 as opened (head `14e6ae8`) adds a Camera2D zoom of 0.444444 to `player.tscn` and was untested. I measured it, kept its idea, and fixed what the review found.

**Old/new comparison (W1 measurement).** Three web exports from separate temp worktrees, screenshotted by one Playwright script at 1280x720, default spawn, no input, 8 s wait.

| | (a) pre-scale `d651078` | (b) main `9d68b18` | (c) PR head `14e6ae8` |
|---|---|---|---|
| Spawn (state) | (0, 60) | (0, 135) | (0, 135) |
| Camera zoom | 1.0 | 1.0 | 0.4444 |
| Visible world rect | 1280x720 | 1280x720 (569x320 in pre-scale units) | 2880x1620 (1280x720 in pre-scale units) |
| Share of arena visible | 51.2% | 10.1% | 51.2% |
| Tile size on screen | 64x32 | 144x72 | 64x32 |
| Tiles across x down | 20.0 x 22.5 | 8.9 x 10.0 | 20.0 x 22.5 |
| Blocks visible | 5 | 3 (partly) | 5 |
| Figure on screen (w x h px) | 18x57 | 36x109 | 16x48 |

- (c) matches (a) in visible arena area, tile size, spawn framing and player visibility. All five obstacles have pixel-identical bounding boxes (for example 180x80 at (440,420)).
- Mean absolute RGB difference per pixel outside the HUD and hint text: 2.85 for (a) vs (c), 35.9 for (a) vs (b).
- The owner's complaint is real: main shows only 10.1% of the arena.
- Two mismatches in (c): the figure is 48 px against 57 px (0.842x) because `BODY_HEIGHT` 108 x 0.4444 = 48 while the old procedural figure was 57 px at scale 1, so the figure scales 1.895x while the world scales 2.25x. Whether to change that is left as an owner decision (not changed). The `PLACEHOLDER` captions were unreadable (about 3.5 px) at the new zoom.

**Final camera setting.** Zoom is `WorldScale.CAMERA_BASE_ZOOM := 1.0 / SCALE` = 0.4444 at SCALE 2.25, giving a 2880x1620 visible world rect in a 1280x720 window. It follows SCALE if SCALE changes. `player_controller.gd` `_ready` sets it; the literal in `player.tscn` was removed.

**Fixes beyond the PR's one line**
1. Single source of truth for the zoom (above).
2. Animation lab zoom is now `[base, 1, 2, 3, 4]`. The panel label reads `wide 0.44x` at the baseline and `1x` to `4x` otherwise (native 1:1 pixels at `1x`). Opening the lab leaves the camera alone, `Z` and the wheel use the same list and wrap to the baseline, and closing with `Tab` restores the baseline.
3. World-space captions are sized from the camera zoom (target at least 8 screen px, `WorldScale.MIN_CAPTION_SCREEN_PX`). Trade-off: the block caption starts at a font size of 18 world units (the 8 px floor at this zoom), so the old shrink-to-fit loop never runs at the wide zoom. Legibility wins over fit: on the narrowest block the caption (about 56 px wide) runs past the face of about 48 px into the side face. The fit logic only takes effect at higher zoom.
4. Edge check at all four walls and four corners found two real defects, both fixed: the head was cut at the top wall (`CAMERA_HEADROOM` = 108) and the feet and shadow were cut at the bottom wall (`CAMERA_FOOTROOM` = 24). The camera limits and a ground strip were extended by those amounts, so no void shows.
5. `__SHINOBI_STATE__` now also publishes `zoom`, `view_w` and `view_h`. Existing fields are unchanged.

**128x128 legibility at the wide zoom (tradeoff).** Measured with a synthetic `__verify__` 128x128 set in a temp copy (never committed; temp copy and build deleted). At 1/2.25 the figure is about 57 px tall (64 at zoom 0.5, 128 at 1.0). Silhouette, head, limbs and facing mark read fine at all three zooms with both filters. The project uses nearest-neighbour filtering:
- At 1/2.25 (non-integer) 1 px details alias and shimmer: a 1 px staff was present when static but vanished in 2 of 3 moving shots, a 1 px diagonal breaks into dots, a 1 px checker becomes moiré, pinstripes merge into a block, and the border partly drops out.
- At 0.5 (exact 2:1) it is stable but drops odd-pixel 1 px features; what survives depends on sub-pixel position.
- At 1.0 it is pixel-exact and stable, static and moving.
- Linear filtering with mipmaps at 1/2.25 and 0.5 keeps every 1 px feature at lower contrast (staff about 25 to 30% of its contrast at 1/2.25, 45 to 90% at 0.5) with no vanishing or popping, but outlines are softer. At 1.0 it is identical to nearest when static and blurs while moving (1 px lines 62 to 94% contrast).

**Owner choice (none applied; default zoom and the project-wide texture filter are unchanged):**
- A. Keep 1/2.25 with nearest filtering. The owner's requested view and crisp edges; 1 px detail aliases and shimmers.
- B. Use zoom 0.5. More pixel-friendly and stable, but it drops odd-pixel 1 px detail and shows 21% less arena (2560x1440 against 2880x1620 world units).
- C. Linear plus mipmaps on the sprites only. No flicker at the wide zoom; less crisp pixel art, and it blurs while moving at 1x.
- D. A larger base viewport. More render pixels for the same view, but with `canvas_items` stretch the resampling moves to the final window scaling. Not measured.
Recommendation (mine, not verified on production art): keep A for now and re-check once real 128x128 production art exists, since 1 px detail is the only thing that suffers.

## Files changed
(In the PR branch: commits `4ec5757`, `b7b1752`, `c2baa65`, `0754d0b` and the review-fix commit. The `player.tscn` literal added by the PR's first commit is removed again, so that file has no net change against `main`.)
- `scripts/world_scale.gd`: `CAMERA_BASE_ZOOM`, `CAMERA_HEADROOM`, `CAMERA_FOOTROOM`, `MIN_CAPTION_SCREEN_PX`, caption font helper.
- `scenes/player/player.tscn`: zoom literal removed. `scripts/player/player_controller.gd`: zoom from the constant, camera limits with head and foot room.
- `scripts/ui/animation_lab.gd`: zoom list, `zoom_label()`, baseline restore. `scripts/arena/training_arena.gd` and `scripts/player/placeholder_visual.gd`: zoom-aware captions, ground strips.
- `scripts/web/web_bridge.gd`: static `camera_framing()` helper, state fields `zoom`, `view_w`, `view_h`.
- `tests/run_tests.gd`: `test_camera_framing`. `scripts/ci/smoke/controls-probe.mjs`: four camera checks.
- Docs: `docs/development/GODOT_PROJECT_HANDOFF.md`, `docs/prototype/SPRITE_DROP_IN.md`, `docs/prototype/TESTING.md`. Order status and this report under `orders/Kiro/`.
- No synthetic sprites or screenshots are committed.

## Tests run before commit
Environment: Windows, Godot 4.7.2 (console build), Playwright headless Chromium shell with software rendering, run in the worktree `C:\tmp\shinobi-order01\camera\wt`. Logs: `c:\tmp\shinobi-order01\camera\logs`. Results below are recorded from earlier steps; this step did not re-run them.

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | exit 0 | logs, progress.md (s4) |
| `godot_ci.py tests` (runs `tests/run_tests.gd`) | 267 passed, 0 failed at `c2baa65` (245 on the PR head before, 266 at `b7b1752`) | `logs\s4\` |
| `validate_godot_project.py --project .` | PASS, 0 errors, 0 warnings | `logs\s4\` |
| `godot_ci.py validate-resources` | 21 scripts, 4 scenes, 0 failures | `logs\s4\` |
| `godot_ci.py export`, `finalize-export --kind game`, `check-export --expect-sha` | OK, 36 MiB, stamped `c2baa65` | `logs\s4\` |
| `node smoke.mjs` | VERDICT PASS | `logs\s4\` |
| `node controls-probe.mjs` | VERDICT PASS, 0 FAIL, including `camera-baseline-at-start`, `lab-open-keeps-baseline`, `lab-z-changes-zoom`, `lab-close-restores-baseline` | `logs\s4\` |
| `node debug-probe.mjs` | VERDICT PASS, 0 FAIL (26 PASS checks plus the VERDICT line at both `b7b1752` and `c2baa65`; the earlier "27 PASS" counted the VERDICT line. Verified by counting PASS lines in both `debug.out` logs: 27 each), so no regression from the camera change | `logs\s4\` |
| `node --test` (smoke library) | 36/36 | `logs\s4\` |
| Fail-then-pass, Godot: `_ready` temporarily set zoom 0.5 | 262 passed, 4 failed, including `camera: baseline zoom equals 1/SCALE within 1e-6 at scene start :: zoom=(0.5, 0.5) expected 0.444444`; reverted, 266 passed 0 failed | `logs\tests-broken.out`, `logs\tests-fixed.out` |
| Fail-then-pass, probe: temp copy expecting zoom 0.5 against the real build | FAIL on `camera-baseline-at-start`, `lab-open-keeps-baseline`, `lab-close-restores-baseline`; VERDICT FAIL; temp file deleted | progress.md (W3) |
| Browser lab zoom walk (real keys) | Z gave 1, 2, 3, 4, 0.4444, 1; Tab open at zoom 2 kept 2. Close-restores-baseline is proven by the controls-probe check `lab-close-restores-baseline` (waits 1500 ms before reading); the edge-log "after Tab close" sample is a stale 10 Hz read and is not cited | progress.md (W2), controls-probe |
| Edge and corner walk with Shift plus WASD, state read from `__SHINOBI_STATE__`, 8 screenshots, lab closed | After the head room and foot room fixes no void; the figure is visible at all 8 positions, side captions are cut and the HUD panel partly covers the figure at some corners (see Issues) | `evidence\edges\` |
| `caption_font_size` unit checks (added in the review-fix commit) | 3 new in-engine checks; full run after the review fix: 270 passed, 0 failed (`godot_ci.py tests`, log `logs\fix1.out`). Other suites were not re-run because the fix touched only tests and docs | `tests/run_tests.gd` |
| Three-way measurement and legibility study | numbers above | `evidence\`, `evidence\legibility\` (sheets and `metrics.json`) |

## Issues encountered
- `c:\shinobi-rush` was switched to `aki/debug-input-telemetry-producer` with uncommitted changes by another agent mid-job. I did not touch it; all work and these doc edits are in a separate worktree of the same repo (`C:\tmp\shinobi-order01\camera\wt`).
- Defects found and fixed: head clipped at the top wall, feet and shadow clipped at the bottom wall. The pre-fix bottom screenshots were overwritten, so no before images exist.
- Residuals not fixed (cosmetic): figure captions are cut by a few px at side walls and corners; the HUD text and the lab chip overlap the figure at the bottom and top corners (UI layout, not camera).
- The figure is 0.842x of its pre-scale on-screen size (see the table). Not changed.
- Mouse wheel and `Z` change the camera zoom even while the lab is closed (wheel zoom with the lab closed existed before this PR). Closing the lab restores the baseline, but if the lab is already closed nothing restores it except opening and closing the lab. Left as is on purpose, because guarding it would change existing input behavior; this is a follow-up for the owner or Orcha's camera director.
- The block caption overflow on the narrowest block at the wide zoom (see Work completed, item 3).
- Not run: `check_workflows.py`, `validate_sprite_manifests.py`, the Python `unittest` suite and `selftest.py` (areas not touched; CI will run them).
- The first export was stamped `4ec5757`; the later full pass at `c2baa65` is the one cited.

## Questions for project owner
1. Which sprite-scaling option (A to D above) do you want for the wide view? The default is A until you decide.
2. Do you want the figure enlarged so it keeps its pre-scale on-screen size (57 px instead of 48 px)? That changes `BODY_HEIGHT` against the 128x128 standard, so I did not do it.

## Outstanding work / next steps
- Push, update the PR #12 body, and run CI until `godot-ci-gate` is green; then the orchestrator merges and verifies the live build. Add the commit SHA and CI run link here afterwards.
- Re-check legibility with real 128x128 production art and real GPU frame rate (neither was tested).
- Optional UI follow-up for the HUD overlap at the corners.

## VERIFIED vs ASSUMED
| Claim | Status | Basis |
| --- | --- | --- |
| PR head matches pre-scale framing (area, tile size, obstacle boxes) | VERIFIED | Playwright screenshots plus pixel analysis (`analyze.py`, `tiles.py`), numbers above |
| Main shows 10.1% of the arena | VERIFIED | same measurement |
| Unit tests 267/0, validators and resources pass, export OK | VERIFIED | commands in the table, run at `c2baa65` |
| Smoke, controls and debug probes pass; no regression | VERIFIED | commands in the table |
| The new tests fail when zoom is wrong | VERIFIED for 4 in-engine checks and 3 probe checks only (baseline-at-start, visible rect, lab-open, lab-toggle; probe baseline-at-start, lab-open-keeps-baseline, lab-close-restores-baseline). The other new checks (zoom list, labels, limits, head and foot room, state fields, captions) were not mutation-tested. The proof ran at the 266-check commit, before the foot-room change | fail-then-pass runs in the table |
| `__SHINOBI_STATE__` fields in the bridge | Helper `camera_framing` is tested directly; the "still publishes" check greps the source text, so it would pass on dead lines. The controls-probe reads the real `state.zoom` in the browser | tests, probe |
| Lab zoom behavior in the browser | VERIFIED | real key presses and state reads; the mouse wheel is only covered by in-engine tests |
| No void and a visible figure at the 8 edge positions | VERIFIED visually | 8 screenshots opened and described; no pixel measurement; side captions are cut and the HUD partly covers the figure at some corners |
| Caption legibility at wide zoom | VERIFIED visually only | seen in screenshots; not measured in pixels |
| Sprite legibility tradeoff | VERIFIED for synthetic art only | metrics from a software-rendered browser; moving samples are only 3 per combination; production art not tested |
| Option D (larger viewport) effect | ASSUMED | reasoning about `canvas_items` stretch, not measured |
| 60 FPS on a real GPU, gamepad input | ASSUMED / not tested | software rendering ran at about 3 to 5 fps |
| PR CI green on the final head | See the PR checks page; not claimed here | `gh pr checks 12` |
| Deployed live build shows the wide view | NOT YET VERIFIED | the orchestrator verifies after merge |

## Coordination note for Orcha (camera director, PR #5 order)
The integration points to test against are:
- `WorldScale.CAMERA_BASE_ZOOM` (1/2.25) is the exploration baseline the director should return to. The lab and the director must not both write `player.camera.zoom`.
- The animation lab (`scripts/ui/animation_lab.gd`) sets `player.camera.zoom` as an absolute value from `ZOOMS = [CAMERA_BASE_ZOOM, 1, 2, 3, 4]`. When the director lands, route lab zoom through it or disable lab zoom while the director is active. Please test: open the lab, press `Z` through the list, close with `Tab`, and confirm the camera returns to the baseline.
- The camera limits include `CAMERA_HEADROOM` above and `CAMERA_FOOTROOM` below the arena; director clamping should use the same limits.
- `__SHINOBI_STATE__` publishes `zoom`, `view_w` and `view_h`, and `controls-probe.mjs` asserts the baseline; camera telemetry and probes can reuse them.
- World-space captions depend on the zoom, so zoom changes redraw them.
