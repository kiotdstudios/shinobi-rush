# Job Report — Lab zoom half steps (1.5x, 2.5x, 3.5x)
- Agent: Kiro
- Order: none. Direct request from the project owner ("zoom goes from .44444 to 1 to 2 etc, I need 1.5, 2.5, 3.5 etc"); there is no order file.
- Date: 2026-10-21
- Final status: REVIEW (PR open, not merged, not deployed; the live check belongs to the orchestrator after the merge)
- Commit / PR: branch `kiro/lab-zoom-half-steps`, implementation commit 5c50ba2, then this report in a report-only commit. The PR number and the CI run ids are in the PR and in the orchestrator's messages (a report cannot hold the CI result of its own head).

## Work completed
- The animation lab zoom list is now `[active preset baseline, 1, 1.5, 2, 2.5, 3, 3.5, 4]` (was `[baseline, 1, 2, 3, 4]`). The first `Z` from the baseline is still exactly 1.0, `Z` wraps from 4x to the baseline, the mouse wheel walks the same list one entry per notch and clamps at both ends, the cap stays 4, closing the lab restores the baseline.
- `zoom_label` printed `%d`, so 1.5 would have read "1x". Whole steps still read `1x`, `2x`, half steps read `1.5x`, `2.5x`, `3.5x`; the baseline keeps `wide 0.44x` / `close 1.21x` (`CameraPreset.label_for`, unchanged).
- A baseline equal to ANY step is listed once. The dedupe in `zoom_list` was already `is_equal_approx` per step, so it covers the new halves (`?camera=1.5` gives `custom 1.50x, 1x, 2x, 2.5x, 3x, 3.5x, 4x`).
- The half steps are documented as not pixel-exact with the nearest-neighbour filter (project default filter is Nearest, `default_texture_filter=0`) in SPRITE_DROP_IN.md, TESTING.md, GODOT_PROJECT_HANDOFF.md and in the lab help line. The filter, the presets, the `?camera=` parsing (clamp 0.25..4) and all other code are untouched.

## Files changed
- `scripts/ui/animation_lab.gd`: `NATIVE_ZOOMS` = 1, 1.5 ... 4 (name kept so nothing else moves; its comment says the halves are not native), `zoom_label`, `KEYS_HELP` ("Z or wheel zoom (half steps are not pixel-exact)"), two comments. `zoom_list`, `set_zoom_index`, `cycle_zoom` and the wheel code needed no change.
- `tests/run_tests.gd` (wheel walk, list, labels, Z walk, restore on close), `tests/test_camera_preset.gd` (close preset, 120 px snap to 1.0, baseline change at 3.5x, new pure list/label/dedupe checks, new `?camera=1.5` scene). `tests/test_camera_impact.gd` is unchanged: it uses index 1 = 1.0, which did not move.
- `scripts/ci/smoke/controls-probe.mjs`: one new check, `lab-z-second-step-is-half` (second Z gives 1.5). `lab-z-changes-zoom` (first Z gives 1.0) is unchanged and still true.
- Docs that stated the old list: `docs/prototype/SPRITE_DROP_IN.md`, `docs/prototype/TESTING.md`, `docs/development/GODOT_PROJECT_HANDOFF.md`. `docs/development/CAMERA_IMPACT.md` does not name the steps ("tested at the 1x step" stays true), so it is untouched.

## Tests run before commit
Machine: Windows, Godot 4.7.2 console build, headless Chromium (software GL, 1280x720, a few FPS), evidence in `C:\tmp\shinobi-order01\labzoom\evidence\` (not committed).

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py tests` on fresh main 6e510e3, own worktree, before any edit | SUMMARY: 742 passed, 0 failed (VERIFIED) | logs-base |
| `godot_ci.py import`, `validate-resources` on the branch | exit 0; scripts=40 scenes=6 resources=0 failures=0 (VERIFIED) | logs-new |
| `godot_ci.py tests` on the final tree | SUMMARY: 758 passed, 0 failed, +16 checks (VERIFIED). The one WARNING is the intentional t_badsheet fixture | logs-final |
| Red proof, ONE temporary mutation: 1.5 dropped from `NATIVE_ZOOMS` | 735 passed, 23 failed (wheel, list, labels, Z walk, restore on close, close preset, dedupe, `?camera=1.5`). File restored from a copy (SHA-256 equal), grep finds no MUTATION marker, tests 758/0 again (VERIFIED) | logs-mut |
| `validate_godot_project.py`; `node --check controls-probe.mjs` | PASS 0 errors; exit 0 (VERIFIED) | local |
| Local Web export of 5c50ba2 with the CI commands (`export`, `finalize-export`, `check-export`; GITHUB_SHA set for the export steps) | all exit 0, "export check: OK", `build-info.json` commit_sha 5c50ba25762098c88cf8c7c3e8dffd44a4c0a5df (VERIFIED) | export\ |
| Controls probe against that export | VERDICT PASS: 23 PASS, 0 FAIL (22 existing + the new check) (VERIFIED) | controls-probe.log |
| Real-browser session (real key presses and wheel, zoom read from `window.__SHINOBI_STATE__`, panel label and HUD line read by eye from opened screenshots) | sequences below, 0 console errors in both sessions (VERIFIED) | session\ (sheet-wide.png, sheet-close.png opened) |

Observed in the browser (state zoom / panel label):
- Wide (default): baseline 0.4444 `wide 0.44x`. `Z` x9: 1, 1.5, 2, 2.5, 3, 3.5, 4, 0.4444, 1 / `1x`, `1.5x`, `2x`, `2.5x`, `3x`, `3.5x`, `4x`, `wide 0.44x`, `1x`. Wheel up x9: 1, 1.5, 2, 2.5, 3, 3.5, 4, 4, 4. Wheel down x9 from there: 3.5, 3, 2.5, 2, 1.5, 1, 0.4444, 0.4444, 0.4444. `Tab` close and reopen: 0.4444.
- Close (`?camera=close`, the real 104 px art): baseline 1.2115 `close 1.21x`. `Z` x9: 1, 1.5, 2, 2.5, 3, 3.5, 4, 1.2115, 1 / `1x` ... `4x`, `close 1.21x`, `1x`. Wheel: the same walk, ending at 1.2115.
- Key `N` in the lab: wide -> close (1.2115), `Z` `Z` gives 1, 1.5, `N` -> wide (0.4444); and the reverse from the close session.
- Heavy camera kick (key `8`) at 2.5x, both presets: count 0 -> 1, peak 5 px, not active afterwards, offset 0, zoom stays 2.5.

## Issues encountered
- None blocking.
- Observation, unchanged and found by reading the code (not run in the browser): the wheel handler does not check that the lab is open, so a wheel notch zooms the camera during normal play too, and only closing the lab (`Tab` twice) restores the baseline. Half steps make each notch smaller, nothing else changes.
- `GODOT_PROJECT_HANDOFF.md` named a constant `ZOOMS` / `AnimationLab.ZOOMS` that no longer exists; I corrected the names inside the sentence I had to rewrite anyway (`NATIVE_ZOOMS`, `zoom_list()`).
- A code comment in `scripts/player/player_controller.gd` still says "(1x..4x)"; it is still true and the file is outside this job.

## Not verified
- Real GPU rendering and frame rate (software GL only); browsers other than headless Chromium; a real controller (the L-stick click calls the same `cycle_zoom`, covered only by the in-engine button/key parity test).
- Pixel quality of the half steps. "Not pixel-exact" follows from nearest-neighbour sampling at a non-integer scale (each source pixel covers 1 or 2, 2 or 3, 3 or 4 screen pixels); I did not measure it. I opened one 1.5x frame and saw nothing broken.
- The live site: nothing is deployed from this branch. After the merge the deployed build must be checked (`build-info.json` commit equals the merge commit, then Tab, Z).

## Questions for project owner
None.

## Outstanding work / next steps
- Independent review, required CI green on the PR head, merge by the orchestrator, then the live check above.
- If judging pixel art at 1.5x, 2.5x and 3.5x matters, snapping sprites to whole pixels would be a separate rendering decision; it was not done here.
