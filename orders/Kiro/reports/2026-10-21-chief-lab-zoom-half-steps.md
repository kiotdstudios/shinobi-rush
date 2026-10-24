# Chief report - Lab zoom half steps (1.5x, 2.5x, 3.5x) live (PR #57)
- Agent: Kiro (orchestrator)
- Date: 2026-10-21 local (the merge is 2026-10-22T02:25:58Z; local time is UTC-4)
- Assignment: a direct request from the project owner, no order file: "zoom goes from .44444 to 1 to 2 etc, I need 1.5, 2.5, 3.5 etc". He confirmed the reading: keep the whole steps and add the halves.
- Final status: **DONE, verified live** at 9d5b5a0.
- This report ships in docs-only [PR #60](https://github.com/kiotdstudios/shinobi-rush/pull/60), written after the live check in section 4.

**TL;DR**
- The animation lab's zoom list (Z key and mouse wheel) is now baseline, 1, 1.5, 2, 2.5, 3, 3.5, 4. The first Z from the baseline still goes to exactly 1.0, the cap stays 4, closing the lab restores the baseline. Labels read `1x`, `1.5x`, `2x` and so on.
- Live and checked: Z walks 1, 1.5, 2, 2.5, 3, 3.5, 4, baseline, 1 at both the wide and the close preset; the wheel walks the same list.
- The half steps are not pixel-exact with the nearest-neighbour filter (uneven pixel widths); the lab help line and the docs say so.

## 1. Final status per assignment
| Assignment | Status | Why |
| --- | --- | --- |
| Lab zoom half steps ([PR #57](https://github.com/kiotdstudios/shinobi-rush/pull/57)) | **DONE** | Merged as 9d5b5a0; live `build-info.json` commit equals the merge commit; all six CI jobs of the merge green incl. post-deploy smoke; my replay on the deployed build matches (section 4). |

## 2. What was completed
| PR | Title | Merge commit | Merged (UTC) | What |
| --- | --- | --- | --- | --- |
| [#57](https://github.com/kiotdstudios/shinobi-rush/pull/57) | Lab zoom: add 1.5x 2.5x 3.5x half steps | 9d5b5a0 | 2026-10-22 02:25:58 | `NATIVE_ZOOMS` becomes 1, 1.5 ... 4 in `scripts/ui/animation_lab.gd`; `zoom_label` prints non-integers; tests, one probe check (`lab-z-second-step-is-half`) and the docs that listed the old steps; job report. 8 files, +197 / -44. |
| [#60](https://github.com/kiotdstudios/shinobi-rush/pull/60) | Chief report: lab zoom half steps live | on the PR page | after CI | Docs only: this report, `CHIEF_INDEX.md`, the job report's final status and live section. |

## 3. Evidence and test results
| Claim | Label | Evidence |
| --- | --- | --- |
| Whole suite 742 passed on fresh main, 758 passed / 0 failed on the branch and on the merge (+16 checks) | VERIFIED | worker's logs; main run 39711340816 log counted by me: `SUMMARY: 758 passed, 0 failed` |
| The tests can fail: dropping 1.5 from the list turns 23 checks red (735 passed), file restored, no marker left | VERIFIED | job report |
| Controls probe 23 PASS (22 older + `lab-z-second-step-is-half`), debug probe 26 PASS, smoke 11 + 11 PASS on the merge | VERIFIED | main run 39711340816, counted by me |
| The production diff is the list, the label formatting and the help line | VERIFIED (read by me) | `gh pr diff 57` |
| Pixel quality of the half steps | NOT MEASURED | see section 8 |

## 4. Live verification
- **URL:** https://kiotdstudios.github.io/shinobi-rush/ . `build-info.json`: `commit_sha` 9d5b5a0c3135058e2b775f37db324ebffc4e5579 (the merge commit), run 39711340816, built 2026-10-22T02:27:28Z. VERIFIED. Post-deploy smoke on the real URL: passed.
- **Replay on the deployed build** (headless Chromium, software GL, 1280x720; real key presses and wheel, zoom read from `window.__SHINOBI_STATE__`, 0 console errors):

| Case | Result |
| --- | --- |
| wide (default), lab open, Z x9 | 1, 1.5, 2, 2.5, 3, 3.5, 4, 0.4444, 1; Tab to close: back to 0.4444 |
| `?camera=close`, lab open, Z x9 | 1, 1.5, 2, 2.5, 3, 3.5, 4, 1.2115, 1; Tab to close: back to 1.2115 |
| wide, mouse wheel up, up, up, down | 1, 1.5, 2, 1.5 |

- **Opened by me:** the wide session at the 1.5x step: HUD line "Zoom: 1.5000 (wide)", lab panel row "Zoom Z / wheel" reads `1.5x`, the help line reads "Z or wheel zoom (half steps are not pixel-exact)", both figures drawn larger on the brick floor. **Numbers only:** the close session and the 2.5x pictures.
- **Not live-checked:** a real gamepad (the L-stick click calls the same function, covered by an in-engine test).

## 5. Changes made outside code (and how to reverse each)
1. **Merged #57** (mine) with a merge commit. Reverse: revert through a PR.
2. **Keep-awake started** on your computer at your request, 8 hours (until about 05:47 local). Stop it on request.
3. **Git worktrees** in the shared clone's `.git`: `labzoom\wt` (merged, to remove) and `wt-chief5` (this PR). The shared clone's working tree was not touched.

## 6. Findings about other agents' work and hazards
- None for other agents: the change is inside my lab file, its tests and docs. The camera-impact tests and demo keys use the 1x step (index 1), which did not move.
- **The mouse wheel zooms the camera during normal play too** (the wheel handler never checked that the lab is open); only closing the lab restores the baseline. It was like this before and the half steps just make each notch smaller. You may be using the wheel in play without opening the lab.

## 7. Judgment calls you may want to overturn
- I added the half steps between the whole steps and kept the cap at 4; I did not drop the whole steps.
- I read the production diff myself instead of ordering an independent review pass: it is one list, one label formatter and a help string, with a red proof and CI behind it.
- The constant is still called `NATIVE_ZOOMS` so nothing else moves, although the halves are not native.

## 8. Not verified (said plainly)
- Pixel quality at 1.5x, 2.5x and 3.5x: with nearest-neighbour sampling a source pixel covers an uneven number of screen pixels (1 or 2, 2 or 3, 3 or 4). Derived, not measured; one 1.5x frame looked fine.
- Real GPU rendering, other browsers, a real controller.

## 9. Questions for the chief
1. **Steps above 4?** The cap is 4 (the preset clamp is 0.25 to 4). Recommendation: leave it unless someone needs a closer look.
2. **Wheel zoom in normal play.** Keep it, or only while the lab is open? Recommendation: keep for now, decide with the validation scene.
3. **Still open from my earlier reports:** the 10-19 and 10-21 chief reports (who wires the camera kick call, the open order PRs #39 and #40, close zoom 1.2115 or 1.2, validation scene split with Aki, lab starting closed, shadow-free, side margin, ground mockup, projection and tile size). Recommendation unchanged.

## 10. Comments / recommendations
- For judging pixel art, use the whole steps; use the halves for framing and layout checks. `?camera=1.5` in the page address also works if you want a half step without opening the lab.

## 11. Next steps
- Merge this report, remove `labzoom\wt` and `wt-chief5`, stop keep-awake when you say so.

## 12. Where to look
- Job report (worker's, with a live section added by me): [lab zoom half steps report](2026-10-21-lab-zoom-half-steps-report.md). No order file for this request.
- PRs: [#57](https://github.com/kiotdstudios/shinobi-rush/pull/57), [#60](https://github.com/kiotdstudios/shinobi-rush/pull/60). CI: main run [39711340816](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39711340816).
- Docs that state the steps: `docs/prototype/SPRITE_DROP_IN.md`, `docs/prototype/TESTING.md`, `docs/development/GODOT_PROJECT_HANDOFF.md`.
- Evidence on the build laptop (not in the repo), under `c:\tmp\shinobi-order01\labzoom\`: `evidence\live\` (live replay JSON and two lab screenshots per preset), `main-9d5b5a0.log`.
