# Chief report - Wide camera framing restored (PR #12); wall-occlusion investigation started (PR #9)
- Agent: Kiro (orchestrator)
- Date: 2026-10-18 (all dates and times are UTC unless marked local; local time is UTC-4)
- Assignment: owner message "review PR #12 first (camera framing), followed by PR #9 (wall occlusion) ... complete the required tests before merging or reporting completion. Report your findings, fixes, test results, and PR links."
- Final status: camera order **DONE (verified live)**; occlusion order **IN_PROGRESS** (order merged, investigation running, no result yet).
- This report ships in docs-only [PR #14](https://github.com/kiotdstudios/shinobi-rush/pull/14). It was written after the live result was verified (section 4).

**TL;DR**
- The wider view is back and live. At 1280x720 the game shows 51.2% of the arena again (it showed 10.1% after the 2.25x world rescale). Tile size is the same as in the pre-scale build and all five obstacles sit in identical pixel boxes (only the captions on their faces differ, now legible). The 128x128 sprite standard is untouched.
- PR #12 as opened was one line, right in idea but not enough. Measuring found unreadable captions, the head cut off at the north wall, the feet cut off at the south wall, and a lab zoom that fought the baseline. All fixed, with 25 new in-engine checks and 4 new browser-probe checks.
- Not changed, needs your decision: at the wide view the figure is 48 px tall against 57 px before (0.84x), and 1 px sprite details will shimmer at the non-integer zoom with nearest-neighbour filtering (options A to D, question 1).
- PR #9 (occlusion): the order is merged and the investigation is running. Nothing is concluded yet.

## 1. Final status per assignment
| Assignment | Status | Why |
| --- | --- | --- |
| PR #12 / order [restore wide camera framing](../2026-10-18-restore-wide-camera-framing.md) | **DONE** | Merged as 9a467ea. The live `build-info.json` commit equals the merge commit. All six CI jobs on the merge are green, including the post-deploy smoke test. I opened the live screenshots and ran real-key checks against the deployed build (section 4). |
| PR #9 / order [wall occlusion](../2026-10-18-deferred-wall-occlusion-investigation.md) | **IN_PROGRESS** | The order PR is merged (3d25e98). Investigation workflow `wf_6939311f46922c2d` is running: setup is done, reproduction is not. No claim about the cause yet. It gets its own chief report once its result is verified live. |
| Sprite filtering and figure size at the wide view | **OPEN, owner decision** | None of the options was applied (question 1 and 2). |
| Aki's PR #13 (not assigned to me) | **NOT MERGED** | Needs your go-ahead (question 3). |

## 2. What was completed
| PR | Title | Merge commit | Merged (UTC) | What |
| --- | --- | --- | --- | --- |
| [#12](https://github.com/kiotdstudios/shinobi-rush/pull/12) | Restore wider arena camera framing after 128x128 world scaling (reviewed, tested) | 9a467ea | 21:12:21 | Baseline camera zoom is now `1 / WorldScale.SCALE`, derived in code. Lab zoom list is `[wide, 1, 2, 3, 4]`. World captions scale with the zoom. Head room and foot room at the north and south walls. `__SHINOBI_STATE__` gains `zoom`, `view_w`, `view_h`. 25 in-engine checks, 4 probe checks, docs. 13 files, +377/-16. Opened by another agent as a one-line zoom change (every agent commits as the same GitHub user, so the author cannot be told apart). Kiro's six commits: 4ec5757, b7b1752, c2baa65, 0754d0b, 10b68b0, 707f7be. |
| [#9](https://github.com/kiotdstudios/shinobi-rush/pull/9) | Queue deferred Kiro wall/player occlusion investigation | 3d25e98 | 21:26:20 | Docs only: adds the order file (27 lines). Merged because the dependency it names (PR #12 live) was cleared. |
| [#14](https://github.com/kiotdstudios/shinobi-rush/pull/14) | Chief report: wide camera framing verified live (PR #12) | on the PR page (a report cannot cite its own merge commit) | after CI is green | Docs only: this report, `CHIEF_INDEX.md`, the standing-rule section in `orders/Kiro/README.md`, camera order set to DONE, a live-verification section appended to the camera job report, one erratum in the first chief report. |

## 3. Evidence and test results
Each claim is labelled. CI numbers come from the logs of the runs named in the last column; I read them myself, not from a summary.

| Claim | Label | Evidence |
| --- | --- | --- |
| The merged tree equals the reviewed and CI-tested PR head 707f7be | VERIFIED | `git diff --stat 707f7be 9a467ea` prints nothing |
| In-engine tests on merged main: 270 passed, 0 failed (245 before the PR) | VERIFIED | Godot CI run [39166792014](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39166792014), build job log, line `SUMMARY: 270 passed, 0 failed` |
| Browser smoke before deploy: 11 of 11 PASS | VERIFIED | same run, job "Pre-deploy browser smoke test" |
| Controls probe: 10 of 10 PASS, including the four camera checks (baseline at start, lab open keeps baseline, Z changes zoom, lab close restores baseline) | VERIFIED | same job log |
| Debug-log probe: 26 PASS, verdict PASS (no regression from the camera change) | VERIFIED | same job log |
| Post-deploy smoke against the live URL: 11 of 11 PASS | VERIFIED | same run, job "Post-deploy live smoke test" |
| All three workflows green on 9a467ea: Godot CI 39166792014 (3 min 46 s), Repository checks 39166792064, Pipeline self-test 39166792005 | VERIFIED | `gh run list` |
| PR head 707f7be was green too: Godot CI 39166562618, Repository checks 39166562467, Pipeline self-test 39166562458 | VERIFIED | `gh run list` |
| Independent review: pass 1 had 7 findings, all fixed in 10b68b0; pass 2 APPROVED | VERIFIED (I read the review file; it is on the build laptop, not in the repo) | `c:\tmp\shinobi-order01\camera\review.md` |
| The workflow's local runs (tests, validators, export, smoke, controls and debug probes) passed | VERIFIED per the [job report](2026-10-18-wide-camera-framing-report.md) | The probes ran at c2baa65. Later commits touched only tests and docs (reviewer's `git diff c2baa65 10b68b0 --stat`), and CI re-ran everything on the final head. |
| The new checks can fail: forcing zoom 0.5 made 4 in-engine checks and 3 probe checks fail, then reverted | VERIFIED for those 7 only | job report. The other new checks were not mutation-tested. |
| 128x128 legibility at the wide zoom | VERIFIED for a synthetic set only | software-rendered browser, 3 moving samples per setting. No production art exists yet. |
| Option D (larger base viewport) effect | ASSUMED | reasoning about `canvas_items` stretch, not measured |

## 4. Live verification
- **URL:** https://kiotdstudios.github.io/shinobi-rush/ . `build-info.json` reported `commit_sha` 9a467eac4ab2620deaa4afca765c4d583b3e2ec0 (equal to the merge commit), run 39166792014, built 2026-10-18T21:12:56Z. VERIFIED. Since then PR #9 deployed (run 39167838751, green): the site now serves 3d25e98, a docs-only change. My camera checks were made at 9a467ea.
- **Post-deploy smoke:** 11 of 11 PASS on the real URL (section 3).
- **Screenshots I opened myself** (1280x720, default spawn, no input, 8 s after the ready flag, no `?debug` flag, same method as the three earlier captures):

| | Pre-scale build d651078 (the view the owner remembers) | Main before the fix 9d68b18 | Live 9a467ea |
| --- | --- | --- | --- |
| Visible share of the arena | 51.2% | 10.1% | 51.2% (state: `view_w` 2880, `view_h` 1620, `zoom` 0.4444) |
| Tile on screen | 64x32 px | 144x72 px | 64x32 px (live capture differs from the PR-head capture by 0.32 mean RGB per pixel) |
| Obstacles in view | 5 | 3, cut by the screen edge | 5, bounding boxes identical to the pre-scale build |
| Figure, head to feet | 18x57 px | 36x109 px | 16x48 px (same as the PR-head capture) |
| Mean RGB difference to pre-scale, outside the HUD panel and hint text | - | 35.9 | 2.97 (what differs is the smaller figure, its shadow and the world captions) |

- **Real-key checks on the deployed build** (my Playwright script, 7 of 7 PASS, 0 console errors in that run; screenshots opened):
  - Spawn state: zoom 0.4444, view 2880x1620. Tab (lab open) keeps the baseline. Six Z presses give 1, 2, 3, 4, 0.4444, 1. Closing the lab from zoom 2 returns to 0.4444.
  - Lab open shows the zoom row "wide 0.44x". After one Z it shows "1x" and the figure is about 108 px tall.
  - Sprinting to the north wall (y -1098): head and body are above the wall line, no void, the HUD panel covers the legs, the figure's caption is clipped by a few px at the screen edge.
  - Sprinting to the south wall (y 1125): head, legs, shadow and facing mark are inside the frame, no void, the HUD hint text overlaps the figure.
  - These match the residuals already disclosed in the job report (captions cut at walls, HUD overlap at corners).

## 5. Changes made outside code (and how to reverse each)
1. **Six commits pushed to PR #12's branch** and its title and body rewritten to match the facts. PR #12 merged by me with a merge commit. Reverse: revert merge commit 9a467ea through a PR (this also removes the original author's two commits).
2. **PR #9 merged** (3d25e98) after "update branch" put a merge commit (a6edd0b) on its branch. Docs only. Reverse: revert 3d25e98.
3. **Comment on Aki's PR #13:** https://github.com/kiotdstudios/shinobi-rush/pull/13#issuecomment-6255456097 . Reverse: delete the comment.
4. **Standing-rule file on this machine:** `c:\.kiro\steering\chief-report-after-every-task.md` (the reason this report exists). Reverse: delete or edit the file.
5. **`orders/Kiro/README.md` gets the same rule** for the repo (this PR). Reverse: revert this PR.
6. **Keep-awake still running** (holds system and display awake) until about 21:01 local. Reverse: stop that process.
7. **Git worktrees registered in the shared clone's `.git`:** camera, chief report, occlusion, all under `C:\tmp\shinobi-order01`. The shared clone's working tree was not touched. Reverse: `git worktree remove`. The camera worktree is already removed; the chief-report one goes after PR #14 merges and the occlusion one after its PR.
8. **Workflow runs started:** `wf_74a434fd6f617940` (camera, finished) and `wf_6939311f46922c2d` (occlusion, running).
9. Nothing deleted. Remote branches of merged PRs remain.

## 6. Findings about other agents' work and hazards
- **Shared clone collision (Aki).** Aki's agent took over `c:\shinobi-rush` (the clone the earlier work ran in) and switched it to `aki/debug-input-telemetry-producer`, now at d2a217e. Two agents on one working tree will overwrite each other's uncommitted work. I work only in worktrees. Suggest AGENTS.md says "one git worktree per agent task".
- **Aki's PR #13 (debug telemetry producer), reviewed read-only at 14a08db.** The contract matches `DEBUG_LOG_INTERFACE.md`. It registers before `BrowserDebug`, is off by default, edits nothing under `scripts/web/`, and keeps its tests in a new file (+2 lines in `tests/run_tests.gd`). A trial merge into main 9a467ea is conflict-free (VERIFIED with `git merge-tree`). Flag: the new actions bind F6, F10, F11 and F12, which browsers may keep for themselves (full screen, developer tools, address bar, menu bar). That is ASSUMED, not tested; I told Aki in the comment above. Aki pushed d2a217e after my review (docs only: Aki's own chief report; code unchanged, VERIFIED by diff stat). The branch is BEHIND main again and CI is re-running. Aki's report asks the same merge question as mine.
- **PR #12 as opened** would have shipped the right framing with unreadable captions, a clipped head at the north wall and clipped feet at the south wall (found by walking the edges), and absolute lab zoom values. Its author called it an unverified first pass, so this is a reminder rather than a violation: a one-line scene change still needs the three-way measurement.
- **For Orcha (camera director, PR #5 order).** The lab writes `camera.zoom` directly. The mouse wheel and Z also change the gameplay zoom while the lab is closed (the wheel already did before this PR). Two writers on one camera will conflict. The baseline constant and the contract are in the job report's coordination note.
- **For Codex (art).** The wide view draws 128x128 frames at 0.444x with nearest filtering. 1 px details alias and shimmer in motion; at 0.5 they are stable but odd-pixel details drop out. Avoid relying on 1 px details for key silhouette cues, or pick option B or C.
- **`tests/run_tests.gd` is a merge hotspot** (PR #12, PR #13, and the occlusion tests to come). New test files with one include line avoid conflicts; I told the occlusion workflow to do that.

## 7. Judgment calls you may want to overturn
- Kept PR #12's idea (zoom 1/2.25) but derive it from `WorldScale.SCALE` and removed the scene literal, so the camera follows the world scale if it changes.
- Went beyond the one-line fix because measurement showed real defects (captions, wall edges, lab zoom).
- Applied none of the owner choices A to D. Default A (nearest filter, zoom 1/2.25) stays, because you asked for the view, not for a rendering change.
- Did not enlarge the figure from 48 px to 57 px (it would change `BODY_HEIGHT` against the 128x128 standard).
- Captions: legibility over fit (at least 8 screen px). The caption on the narrowest block runs past its face.
- Left the wheel and Z zoom ungated while the lab is closed (guarding it changes existing input behavior).
- Merged PR #12 myself under your standing merge instruction, after the independent reviewer approved and CI was green, with a merge commit.
- Merged PR #9 (order only) on my reading of "review PR #12 first, followed by PR #9 ... before merging". It starts the investigation; it changes no code.
- Posted a review comment on Aki's PR #13 but did not merge it.
- Used the UTC date of the work (2026-10-18) in the file name, matching the other reports.

## 8. Not verified (said plainly)
- Frame rate on a real GPU. Everything ran in headless Chromium with software GL at 4 to 6 FPS.
- Firefox, Safari, Edge, phones and tablets, touch, gamepad. Window sizes other than 1280x720.
- Real 128x128 art (none exists yet). The legibility study used a synthetic set.
- Option D.
- Whether Aki's F6, F10, F11 and F12 reach the game in real browsers.
- Your own screenshot of the problem: I rebuilt "the previous view" from the pre-scale commit d651078 at 1280x720.
- Mouse-wheel zoom on the live build (covered by in-engine tests only).
- Edges: the live build was walked to the north and south walls only. The corners and side walls were checked on the PR build (8 positions; the reviewer opened 3 of the 8 images).
- One local run of my live screenshot logged a single console error, "The AudioContext encountered an error from the audio device or the WebAudio renderer". The next run had none and the CI smoke on the same commit has 0 fatal console events. ASSUMED environmental (no audio device in headless Chromium).

## 9. Questions for the chief
1. **Sprite scaling at the wide view.** A: keep zoom 1/2.25 with nearest filtering (crisp, 1 px detail shimmers). B: zoom 0.5 (stable, drops odd-pixel details, 21% less arena). C: linear filtering with mipmaps on sprites (no shimmer, softer). D: larger base viewport (not measured). Recommendation: A now, then re-run the study when Codex's first real 128x128 set exists.
2. **Figure size, 48 px now against 57 px before.** Enlarge it? Recommendation: no. It would change `BODY_HEIGHT` against the 128x128 standard. If you want it bigger, B gives 54 px at the cost of view size.
3. **Aki's PR #13.** May I merge it once Aki confirms the F-keys work in a real browser (or rebinds them) and CI is green on the updated branch? Aki asked the same. Recommendation: yes. Then I verify the whole debug-log chain on the live build.
4. **PR #9 merged by me.** Keep that? Recommendation: keep; it is docs only and one revert undoes it.
5. **Wheel and Z zoom with the lab closed.** Disable for gameplay? Recommendation: yes, as part of Orcha's camera director, not as a separate change.
6. **Still open from the [first chief report](2026-10-18-kiro-chief-report.md):** debug versus release build for the live site, world-scale approval, review rules and CODEOWNERS, preview GIF size in git history, Dependabot and Godot 4.8 and branch cleanup. Unchanged.

## 10. Comments / recommendations
- **CI cost correction.** The first chief report said every PR waits about 10 minutes. That was an estimate I had not measured. Measured later: Godot CI takes about 2.5 minutes on a PR, the repository check about 10 seconds, the pipeline self-test 2.5 to 3 minutes, and a main deploy run 2.5 to 4 minutes. A docs-only chief-report PR therefore costs about 3 minutes plus the merge, and the change-detector idea in the first report is not needed.
- **The wide view is now a regression-tested contract.** `__SHINOBI_STATE__` carries `zoom`, `view_w`, `view_h` and the controls probe asserts the baseline in CI. Running that probe against the live URL after each deploy would automate what I did by hand. Optional.
- Screenshots and scripts are on the build laptop (paths below), not in the repo, to keep binaries out of git history. Say so if you want a few committed (about 100 KB each).
- The keep-awake needs the laptop plugged in with the lid open.

## 11. Next steps
- Occlusion investigation: the workflow reproduces on the latest build, diagnoses by measurement, fixes only a proven defect, opens a PR. Then I verify live and write its chief report.
- Your answers to the questions above. PR #13 merge and live check of the debug-log chain once you say yes.
- Cleanup: camera worktree (done), this report's worktree after PR #14 merges, occlusion worktree after its PR, keep-awake at the end.
- Re-check the wide view and the sprite filter choice with Codex's first real art.

## 12. Where to look
- Job report (workflow, with the live-verification section added by me): [wide camera framing report](2026-10-18-wide-camera-framing-report.md). Order: [restore wide camera framing](../2026-10-18-restore-wide-camera-framing.md). Next order: [wall occlusion](../2026-10-18-deferred-wall-occlusion-investigation.md).
- PRs: [#12](https://github.com/kiotdstudios/shinobi-rush/pull/12), [#9](https://github.com/kiotdstudios/shinobi-rush/pull/9), [#13](https://github.com/kiotdstudios/shinobi-rush/pull/13). CI: [merge run 39166792014](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39166792014), [PR #9 deploy run 39167838751](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39167838751).
- Docs: [GODOT_PROJECT_HANDOFF.md](../../../docs/development/GODOT_PROJECT_HANDOFF.md), [TESTING.md](../../../docs/prototype/TESTING.md), [SPRITE_DROP_IN.md](../../../docs/prototype/SPRITE_DROP_IN.md).
- Evidence on the build laptop (not in the repo), under `c:\tmp\shinobi-order01\camera\evidence\`: `d-live-9a467ea.png` (live spawn), `a-prescale-d651078.png`, `b-main-9d68b18.png`, `c-pr12-14e6ae8.png`, `analysis-live.json`, `W1-summary.md`; under `live\`: `L1-lab-open-baseline.png`, `L2-lab-zoom-1x.png`, `L3-top-wall.png`, `L4-bottom-wall.png`, `wall-figure-crops-6x.png`, `live-camera-result.json`. Scripts: `c:\tmp\shinobi-order01\live-check\shot-clean.mjs` and `live-camera.mjs`. CI smoke evidence is also attached to the runs above as artifacts.
