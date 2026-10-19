# Chief report - Wall occlusion fixed and live (PR #17)
- Agent: Kiro (orchestrator)
- Date: 2026-10-18 local (the merge is 2026-10-19T01:20Z; local time is UTC-4)
- Assignment: order [wall occlusion](../2026-10-18-deferred-wall-occlusion-investigation.md) (owner: "followed by PR #9"), accelerated by the chief: "identify the exact root cause using the existing evidence and Godot's actual Y-sort behavior ... smallest safe fix ... avoid redundant testing ... get the corrected game into the live browser build safely and quickly."
- Final status: **DONE, verified live** at commit 2b462f2.
- This report ships in docs-only [PR #18](https://github.com/kiotdstudios/shinobi-rush/pull/18), written after the live check (section 4).

**TL;DR**
- Cause: each block was one sort item keyed at its front edge, so a player standing beside a block (north of its front edge) was drawn behind the block's east face and roof. The failure only happened on the east side.
- Fix: each block is now two sort pieces, the front face at the front edge and a new `BlockRear` (east face and roof, same pixels) at the back edge. Collision, camera, scale and foot anchor are untouched.
- Live: the figure beside B1 and B3 went from 0% and 36% visible to 94-96%. Merged 21:20 local, live 21:24, about 45 minutes after the plan was cut down.
- Open, your call: the drawn east base is wider than the collider (optional wedge collider), see question 1.

## 1. Final status per assignment
| Assignment | Status | Why |
| --- | --- | --- |
| Wall occlusion order ([PR #9](https://github.com/kiotdstudios/shinobi-rush/pull/9) order, fix in [PR #17](https://github.com/kiotdstudios/shinobi-rush/pull/17)) | **DONE** | Defect found, fixed, merged as 2b462f2; live `build-info.json` commit equals the merge commit; all six CI jobs green incl. post-deploy smoke; my own real-key replay on the deployed build shows the failing spots fixed (section 4). |
| Wide camera framing (earlier, see [its chief report](2026-10-18-chief-camera-framing.md)) | DONE | unchanged by this fix (live replay still reads zoom 0.4444, view 2880x1620) |
| Owner decisions still open | OPEN | sprite filtering and figure size (earlier report); east-base collider (question 1) |

## 2. What was completed
| PR | Title | Merge commit | Merged (UTC) | What |
| --- | --- | --- | --- | --- |
| [#17](https://github.com/kiotdstudios/shinobi-rush/pull/17) | Occlusion (Kiro): draw player over block east face and roof | 2b462f2 | 2026-10-19 01:20:23 (21:20 local) | `Block` keeps the front face, caption and collider; new `BlockRear` draws east face and roof, keyed at the back edge; pure rule `ArenaSort`; 105 new in-engine checks; short sorting rule in the handoff; job report; order REVIEW. 9 files, +335/-7. |
| [#18](https://github.com/kiotdstudios/shinobi-rush/pull/18) | Chief report: wall occlusion fixed and live | on the PR page (a report cannot cite its own merge commit) | after CI is green | Docs only: this report, `CHIEF_INDEX.md`, order set to DONE, live-verification section in the job report, the reviewer's documentation fixes (points 3, 4, 5, 7, 8, 9), handoff note on sprite width. |

## 3. Evidence and test results
The diagnosis numbers were measured by workflow agents; I read the tables, cross-checked the cause against the source, and repeated the key measurement on the live site myself.

| Claim | Label | Evidence |
| --- | --- | --- |
| Blocks drew front face, east face and roof in one `_draw()`; the arena y-sorts its children; blocks are not y-sorted inside. So each block sorts as one item at its front-edge y | VERIFIED | I read `Block._draw()` and `_ready()` in `scripts/arena/training_arena.gd` before the fix |
| 216 matrix cells (200 local, 16 live): 56 flagged, every one on the east side with player y north of the block's front edge; owner-like B1/B3 east reproduced on the live site | VERIFIED (workflow) | progress notes, I opened the B1 east sheet; local export plus the previous live commit 6f49e23 |
| Sort inputs predict the render in 126 of 126 overlapping cells; the order flips exactly at feet y = block y on all five blocks (0.25 px sweep, tie goes to the block) | VERIFIED (workflow) | O2 notes |
| Camera, feet offset and collision penetration are not the cause (0 penetrations in 60 browser and 400 headless runs) | VERIFIED (workflow) | O2 tables |
| In-engine tests: fix commit 375 passed 0 failed (main 270); PR branch merged with main 419 passed 0 failed; old arena file 6 checks fail; deliberately broken fix 20 fail | VERIFIED | CI log of the PR run and of main run 39184906275 read by me: `SUMMARY: 419 passed, 0 failed`; red runs are the workflow's |
| Lean before/after on a local export: 20 of 20 re-run flagged east cells fixed, 25 of 25 controls unchanged, 6 NE cells unchanged by design, 0 console errors | VERIFIED (workflow), partly by me | table read, B1 east 1x before/after identified by pixel counts: 66 figure pixels before, 2040 after |
| Independent review: APPROVED, no blocking defects, 9 non-blocking points; reviewer's own pixel diff of 54 after-fix captures found controls and NE identical | VERIFIED | `review.md` read by me |
| Merge run 39184906275: six jobs green; pre-deploy smoke 11 PASS, controls probe 10 PASS, debug probe 26 PASS, post-deploy smoke 11 PASS, no FAIL lines | VERIFIED | job logs read by me |
| The same draw order on a real GPU | ASSUMED | Godot's canvas y-sort does not depend on the renderer, but no real GPU was available |

## 4. Live verification
- **URL:** https://kiotdstudios.github.io/shinobi-rush/ . `build-info.json`: `commit_sha` 2b462f24c2e272654c9f7f2496de65edca2acb29 (equal to the merge commit), run 39184906275, built 2026-10-19T01:20:55Z. VERIFIED.
- **Post-deploy smoke on the real URL:** 11 of 11 PASS.
- **Real-key replay on the deployed build** (the same script as the pre-fix live run; 0 console errors; zoom 0.4444 / view 2880x1620 unchanged; `__SHINOBI_TEST__` is undefined, so the test teleport is not live). The player walks to each east face and is stopped at the collider contact (x 619.08 and 727.08), so collision still works. Figure pixels counted against a full-visibility reference:

| Spot (live) | Before (commit 6f49e23) | After (commit 2b462f2) |
| --- | --- | --- |
| B1 east, touching, default wide camera | 0% | 94% |
| B1 east, touching, lab 1x | 0% | 96% |
| B3 east, touching, default wide camera | 36% | 94% |
| B3 east, touching, lab 1x | 36% | 96% |

- **Opened by me:** B1 east touching at the default camera and B3 east touching at lab 1x, both after the fix: the figure stands in front of the east face, fully drawn. The pre-fix pictures were opened in the investigation step.
- **Not re-checked live:** north, north-east and south positions. They are covered by the CI controls probe and by the local lean verification (unchanged), not by a live replay.

## 5. Changes made outside code (and how to reverse each)
1. **PR #17 merged by me** with a merge commit after the independent approval. Reverse: revert 2b462f2 through a PR.
2. **The running workflow plan was replaced mid-run** (six steps became four) and its brief and step files were edited. Those files live under `c:\tmp\shinobi-order01\occlusion\` on the build laptop, not in the repo. Nothing to reverse.
3. **Local-only test teleport** (`?testhooks=1`) was built for evidence and is NOT in the repo or on the live site. Its patch is in `c:\tmp\shinobi-order01\occlusion\hook\`.
4. **Skills installed on this machine** (earlier today): 13 in `c:\.kiro\skills\` (11 third-party with provenance and licences, 2 of mine; markdown only). Reverse: delete the folders. I added a 14th now: `godot-oblique-depth-sorting`, written from this verified result.
5. **Keep-awake** restarted after your reboot (8 hours, until about 03:35 local); stop it when the work is finished.
6. **Git worktrees** registered in the shared clone's `.git`: `occlusion\wt` (kept until you say the follow-ups are decided) and `wt-chief2` (removed after this PR merges). The shared clone's working tree was not touched. The remote branch `kiro/wall-occlusion` was not deleted.

## 6. Findings about other agents' work and hazards
- **Aki:** PR #13 and #16 merged without me. Aki rebound the telemetry HUD keys off the browser-reserved F-keys after my review note (commit 4ff949a). I have not tested those keys in a browser, and I have not yet verified the debug-log chain live. The occlusion tests were put in a new file with one added line in `tests/run_tests.gd`; the branch merged with Aki's changes with no conflict.
- **Codex:** at the east contact the front face still draws over sprite pixels more than about 25 px west of the foot anchor. A 128x128 frame wider than that around the anchor could be clipped by a few px. Real frame extents are not measured yet; this is in the handoff now.
- **Orcha:** the camera is untouched. Any code that counts arena children or assumes one node per block must now expect a `Block` and a `BlockRear` pair (names `BlockN` and `BlockRearN`).
- **Hazard (collider vs drawn base):** the collider is 45-72 px narrower than the drawn east plane. After the fix the player is drawn over the face there, but when he walks north past a block's back edge on the east side he vanishes behind the leaning face. This is geometry-correct for the drawn box but reads as a pop.
- **Process hazard:** shell calls from me sometimes failed with `^C` while a workflow step was active (once the prompt showed the step's folder). Suspected shared terminal, not proven. Re-running alone works.

## 7. Judgment calls you may want to overturn
- Fixed it by splitting the node, not by changing `z_index`. Putting walls on a lower layer would draw the player over every wall, including when he is behind one; your order forbids that.
- Cut the remaining workflow from six steps to four mid-run, dropped the planned browser pixel probe, and kept the test teleport out of the PR (your directive). The cost: the automated tests guard the sort values and node structure, not rendered pixels; the pixel evidence is local plus my live replay.
- Merged PR #17 immediately after approval and moved the reviewer's documentation points into this docs PR, instead of delaying the merge by one CI cycle.
- Left the north-east corner positions hidden (the player is behind the box there). The first matrix labelled them "bug" because its rule was ambiguous for corners.
- Accepted the east-base overhang as a residual rather than adding a wedge collider in the same change.
- Did not re-run the 216-cell matrix, the 128x128 anchor check, or the suites CI already runs.

## 8. Not verified (said plainly)
- Real GPU frame rate and rendering, other browsers, phones, controllers.
- Live north, north-east and south positions after the fix.
- 12 flagged wide-camera cells and 12 flagged live cells were not re-run in the lean set; the sort keys do not depend on zoom and the live replay covers the owner-like spots.
- Your original screenshot (not available to me); I reproduced the same class of failure at the same kind of spot.
- Real 128x128 sprite extents against the front-face overlap.
- The draw offset inside `BlockRear._draw` is not covered by a test (review point 1); the tie rule is modelled in a test and measured on the engine only at the front edge (review point 6).
- The debug-log chain with Aki's producer on the live build.

## 9. Questions for the chief
1. **East-base overhang.** Add a wedge-shaped second collision shape so the player cannot stand inside the leaning east base, or accept the current look? Recommendation: accept for now and judge it in play on the live build; the wedge is a small, separate change if the pop at the back edge bothers you.
2. **Test teleport.** Ship the gated `?testhooks=1` hook in its own PR to allow a CI pixel probe for draw order? Recommendation: not yet; revisit when real art lands, because it adds a client-side teleport to the live site.
3. **Test hardening** (review points 1 and 6): derive the draw offset and node position from one helper and re-run the tie sweep at the back edge. Recommendation: bundle it with the next arena change.
4. **Debug-log chain.** May I verify Aki's merged telemetry end to end on the live build next (about 30 minutes)? Recommendation: yes.
5. **Still open from earlier reports:** sprite filtering option A to D, figure size 48 px against 57 px, and the seven items in the [first chief report](2026-10-18-kiro-chief-report.md).

## 10. Comments / recommendations
- **What made it fast:** compute the expected order from the real sort values before looking at pixels (126 of 126 cells matched), one reproduction matrix and no repeats, numbers first with a few pictures opened, fewer and larger workflow steps, one review pass, and merging right after approval. About 45 minutes passed from the plan cut to the merge.
- **A lesson from today:** when several images are opened together they can come back in a different order than requested. Identify before/after pictures by a pixel count on the files; I recorded this in my verification skill.
- The research behind the diagnosis: Godot's sort key is only a node's own y within the same `z_index`, and Godot 4.7 has no per-node Y-sort origin (proposal #6367 is open), so a multi-face prop has to be split into separately positioned nodes. This is now in the handoff and in my new skill.
- Keep-awake needs the laptop plugged in with the lid open.

## 11. Next steps
- Merge this docs PR; remove `wt-chief2`.
- With your OK, verify the debug-log chain on the live build (question 4), with its own chief report.
- Your answers to questions 1 to 3 and the open items from earlier reports.
- Stop keep-awake when the work is finished; remove `occlusion\wt` when the follow-ups are decided.

## 12. Where to look
- Job report (workflow, with a live-verification section added by me): [wall occlusion report](2026-10-18-wall-occlusion-report.md). Order: [deferred wall occlusion investigation](../2026-10-18-deferred-wall-occlusion-investigation.md).
- PRs: [#17](https://github.com/kiotdstudios/shinobi-rush/pull/17), [#9](https://github.com/kiotdstudios/shinobi-rush/pull/9), [#18](https://github.com/kiotdstudios/shinobi-rush/pull/18). CI: [merge run 39184906275](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39184906275).
- Docs: [GODOT_PROJECT_HANDOFF.md](../../../docs/development/GODOT_PROJECT_HANDOFF.md) ("Props with several faces: depth sorting").
- Evidence on the build laptop (not in the repo), under `c:\tmp\shinobi-order01\occlusion\`: `progress.md`, `review.md`, `evidence\O1b\` (matrix), `evidence\O2\` (diagnosis tables), `evidence\after\table.md` (lean before/after), `evidence\live-after\` (live replay: nine screenshots, `manifest.json`, `capture.log`), `scratch\live-count.py`.
