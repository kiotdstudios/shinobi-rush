# Chief report - Combat camera impact (hit kick) live (PR #50)
- Agent: Kiro (orchestrator)
- Date: 2026-10-21 local. Your order reached main at 03:10Z (PR #41); the module merged at 13:32:28Z and deployed at 13:34:04Z; this report was written at about 14:00Z (10:00 local; local time is UTC-4).
- Assignment: order [Combat Camera Feedback Animation Prototype](../2026-10-20-combat-camera-feedback-animation.md) ("keep this small because Kiro has limited remaining execution budget").
- Final status: **DONE for the module, tests, guide and the handoff, verified live at 7d8ba83.** The call is **not wired**: the order gives the confirmed-hit integration to Aki, so in the live game nothing kicks the camera yet except the lab demo keys. Nothing was left half done.
- This report ships in docs-only [PR #53](https://github.com/kiotdstudios/shinobi-rush/pull/53), written after the live checks in section 4.

**TL;DR**
- One standalone module, `CameraImpact` (`scripts/camera/camera_impact.gd`): `light_hit(dir)` 2.5 screen px for 80 ms, `heavy_hit(dir)` 5.0 px for 120 ms, both inside your bands, same size in screen px at the wide and the close zoom. It writes `Camera2D.offset` only, ends at exactly zero, caps stacking at 6 px, never shows void at the arena edge, and can be turned off or halved (`?camera_impact=off|reduced`, and a browser that asks for reduced motion starts halved).
- **The independent review found a real defect that my author's tests could not see:** the edge clamp read a stale camera centre while the camera was moving, so a hit landing during a run into a wall showed up to the whole kick as void at the screen edge (100 of 256 timing trials). Fixed with a second clamp pass and a moving-camera test that fails on the old code. Merging took three extra rounds (fix, re-review, a test hardening) instead of one.
- Live on https://kiotdstudios.github.io/shinobi-rush/ : Tab opens the lab, then `7` light, `8` heavy, `9` burst of three, `0` slow heavy. Measured live: light 2.500, heavy 5.000, burst 3.536 screen px, always back to offset exactly (0, 0) and the same zoom; off and reduced behave.
- Needs you: tell Aki to add the 5-line call (question 1), and say whether to merge the two other order PRs, #39 and #40 (question 3).

## 1. Final status per assignment
| Assignment | Status | Why |
| --- | --- | --- |
| Combat camera impact module, tests, parameter guide, test capture ([PR #50](https://github.com/kiotdstudios/shinobi-rush/pull/50)) | **DONE** | Merged as 7d8ba83; live `build-info.json` commit equals the merge commit; all six CI jobs of the merge green incl. post-deploy smoke; two independent reviews (changes requested, then approved); my live replay matches (section 4). |
| Event handoff for Aki | **DONE (documented)** | Contract and paste-ready snippet in `docs/development/CAMERA_IMPACT.md`; handed over in a comment on his order PR [#39](https://github.com/kiotdstudios/shinobi-rush/pull/39#issuecomment-6317560759). Not wired, by the order. |
| Aki's call at the hit site | **NOT STARTED (not mine)** | Waits for Aki (question 1). |
| Validation scene and the open decisions of my 10-19 report | **STILL OPEN** | No answers in the repo that I can see (section 9, item 4). |

## 2. What was completed
| PR | Title | Merge commit | Merged (UTC) | What |
| --- | --- | --- | --- | --- |
| [#41](https://github.com/kiotdstudios/shinobi-rush/pull/41) | Queue Kiro: Combat Camera Impact Animation | 9826590 | 2026-10-21 03:10 | Your order, order-only. I merged it so the order exists on main and my PR could update its status. |
| [#50](https://github.com/kiotdstudios/shinobi-rush/pull/50) | Camera impact (Kiro): hit kick module and lab demo keys | 7d8ba83 | 2026-10-21 13:32:28 | The module, 100 in-engine checks, lab keys `7 8 9 0` and a button row, `?camera_impact=` and seven `cfx_*` telemetry fields, six controls-probe checks, the guide, the order and the job report. 13 files, +1450 / -5. |
| [#53](https://github.com/kiotdstudios/shinobi-rush/pull/53) | Chief report: combat camera impact live | on the PR page (a report cannot cite its own merge commit) | after CI | Docs only: this report, `CHIEF_INDEX.md`, the order set to DONE, a live-verification section in the job report. |

Not mine and still open: #39 (Aki's order), #40 (Codex's order), #42, #44, #46 (policy: one official live URL), #48, #49, #20 (Aki, conflicting since 10-19).

## 3. Evidence and test results
| Claim | Label | Evidence |
| --- | --- | --- |
| Whole suite: 534 passed on clean main (9826590, before the module); 742 passed, 0 failed on the PR head and on the merge, of which 100 are the module's | VERIFIED | PR runs 39598440526 and 39608145473, main run 39608902631 (log downloaded and counted by me: `SUMMARY: 742 passed, 0 failed`) |
| Controls probe 22 PASS (16 older + 6 new camera-impact checks), debug probe 26 PASS, smoke 11 + 11 PASS on the merge | VERIFIED | main run 39608902631, counted by me |
| The tests can fail: four temporary mutations of production code (peak 2.5 to 7: 12 checks red; final zero offset not written: 23; edge clamp bypassed: 5; second clamp pass removed: 2), each restored with no marker left | VERIFIED | job report (the reviewers re-ran the fourth and the old-module case) |
| First review (head 4d400fe): CHANGES_REQUESTED, one blocking defect: the clamp showed void on a moving camera, 100 of 256 hit-timing trials, up to 6.9 world px (4.1 world px = the whole 5 px kick at the close zoom) | VERIFIED | `camfx\review.md`; the engine step that causes it is in Godot 4.7.2 `camera_2d.cpp` (`set_offset` advances the smoothing one more step), read by two reviewers |
| After the fix: reviewers' probes show 0 void in 272 real-input runs, 504 static cases, 8 wall walks of 2080 frames, 208 corner trials, also at 10 and 5 FPS | VERIFIED | `camfx\review2.md` |
| Edge behaviour: Godot 4.7.2 applies the offset after the limit clamp, so an unclamped kick shows void at a wall | VERIFIED (measured: 12 px of void) | job report, guide |
| Calibration in pixels: the world moved by the published offset to 0.037 px at close and 0.26 px at wide, and returned pixel-identical | VERIFIED on a local export of 2d4a604 (before the second clamp pass); ASSUMED unchanged for a still camera | job report; the 96 original checks and a static probe of 504 cases cover the second pass |
| Live numbers (section 4) | VERIFIED | my replay on the deployed build, 0 console errors |
| Live pixel shift | NOT CHECKED | my screenshot call was slower than the 1.5 s slow kick, so the picture missed the effect |

## 4. Live verification
- **URL:** https://kiotdstudios.github.io/shinobi-rush/ . `build-info.json`: `commit_sha` 7d8ba83616acc7b78ea11532fba0fa2504339836 (the #50 merge), run 39608902631, built 2026-10-21T13:34:04Z. VERIFIED. `index.pck` 2,385,744 bytes (2,376,568 before, +9,176). Post-deploy smoke on the real URL: passed.
- **Replay on the live build** (headless Chromium, software GL, 1280x720; I wait on the published state, never on sleeps):

| Case | Result |
| --- | --- |
| default, nothing pressed | wide 0.4444, view 2880x1620, lab closed, `cfx_enabled` true, count 0, peak 0, offset (0, 0): unchanged |
| key `7` with the lab closed | count stays 0: the keys only work while the lab is open |
| wide: light / heavy / burst | peak 2.500 / 5.000 / 3.536 px (burst: 3 hits counted, cap 6); each ends active=false, offset exactly (0, 0), zoom 0.4444 |
| close (1.2115): light / heavy | 2.500 / 5.000 px, the same screen size as at wide; ends at offset (0, 0), zoom 1.2115 |
| close: burst | read mid-burst by my script (count 2, peak 2.500); the CI probe's burst check covers it (3.536) |
| `?camera_impact=off`, keys 7 and 8 | `cfx_enabled` false, count 0 to 0, peak 0 |
| `?camera_impact=reduced` | light 1.250, heavy 2.500 (`cfx_scale` 0.5) |
| browser asks for reduced motion, no query | `cfx_scale` 0.5; `?camera_impact=on` puts it back to 1 |
| console | 0 errors in every run |

- **Opened by me:** the close baseline with the lab open (new "Cam kick 7 8 9 0" row with four buttons, the real-art ninja, the red-scarf bandit and the new brick floor). **Numbers only:** everything else in the table.
- **Not live-checked:** the moving-camera edge case in a browser (verified headless by two reviewers at a fixed 60, 10 and 5 FPS), the 60 FPS feel, a live pixel-shift measurement.

## 5. Changes made outside code (and how to reverse each)
1. **Merged #41, your order PR.** Reverse: revert through a PR. I did not merge #39 or #40.
2. **Merged #50** (mine) with a merge commit after the second review approved it. Reverse: revert through a PR.
3. **Comment on Aki's order PR #39** with the contract: https://github.com/kiotdstudios/shinobi-rush/pull/39#issuecomment-6317560759 . Reverse: delete the comment.
4. **Five agent runs** for this one order: build `wf_e9ab9245d9b70775` (failed on a network error, `getaddrinfo ENOENT`, after its work was done; its PR was already open and green), review, fix, re-review, polish. Reverse: nothing to reverse.
5. **Keep-awake restarted** for 3 hours; I stop it when the work ends.
6. **Git worktrees** in the shared clone's `.git`: `camfx\wt` (branch `kiro/combat-camera-impact`, merged; to remove) and `wt-chief4` (this PR). The shared clone's working tree was not touched.

## 6. Findings about other agents' work and hazards
- **Aki:** the hit site is `PlayerController._check_attack_hits()` (search for `enemy.take_damage(`; lines 413-414 on 91eb294, they move with every combat PR). Under today's attack table only `light3` (75 ms hitstop) is above the suggested heavy threshold of 70 ms; a sweep that hits three enemies in one frame makes three calls (the stack is capped; call once per swing if you want one kick). The contract and the snippet were checked on a throwaway copy: imports clean, suite green.
- **Shared files are merge hotspots.** `scripts/web/web_bridge.gd` conflicted once with Codex's PR #52 (both append state fields); `tests/run_tests.gd` auto-merged. `main` moved four times during the job and the ruleset wants the branch up to date, so every move costs a CI cycle.
- **Orcha (future camera director):** the module is the single writer of `Camera2D.offset` and writes exactly zero when an effect ends, so a second writer would be erased. Route impulses through `CameraImpact` or agree on one combined writer. Also: while an effect runs on a moving camera, anything that reads `get_screen_center_position()` sees a centre one smoothing step ahead (engine quirk, documented).
- **A rendering quirk I cannot remove:** writing `Camera2D.offset` makes Godot advance the smoothing one extra step for the rendered frame, so a hit that lands while running moves the view one frame of camera travel (5.7 world px walking, 8.8 sprinting = 10.6 screen px at close, about twice the kick) for as long as the effect lasts, and back when it ends. No drift (0.000000 afterwards). Cure if it reads badly in play: run the helper before the camera.
- **No kick toward a pinned east or west wall:** the arena has no camera margin there (the figure already stands at the screen edge). It is deliberate (your order asks for no clipping at the screen edges) but it may feel dead in play.
- **Shared machine:** another agent runs Godot test jobs in the shared clone on the same laptop, and our shell calls collide (`^C`); this stalled local runs several times. Re-running alone worked.
- **PR #46** (one official live URL, open): this report already follows it (canonical URL, merged SHA, deploy CI, live replay, evidence).

## 7. Judgment calls you may want to overturn
- **I merged your order PR #41 myself** so the order exists on main. #39 and #40 stay open because they are other agents'.
- **Lab keys are `7 8 9 0`, not `H G B`:** the repo's key-collision tests compare physical keys only and `H G B` are the telemetry HUD chords.
- **No zoom pulse.** The order made it optional. Measured: at the east limit a +1.5 % zoom moves the view 9.6 screen px, more than the 5 px kick, and it fights `refresh_camera_baseline()`.
- **A helper node created on first use** under the player's camera, so no scene or controller was edited. `WebBridge` now runs last in the frame (`process_priority = 1`) so the published offset is the one about to be rendered.
- **I paid for two reviews and a polish round** (about four extra agent sessions) because the first review found a real defect, and the test hardening protects a required check from flaking. With a small budget that is a real cost; I think a camera that shows void at a wall is worse.
- **I did not wire the call myself,** although it is five lines: the order forbids touching Aki's controller.

## 8. Not verified (said plainly)
- The feel: 60 FPS on a real GPU. Every number is a starting value inside your bands; none has been felt.
- Aki's integration (a contract, nothing calls it).
- The moving-camera edge case in a real browser (only headless engine runs), and any live pixel measurement.
- Other browsers, phones, controllers, memory.
- The zoom pulse (left out).

## 9. Questions for the chief
1. **Who wires the call?** Please tell Aki to add the 5-line snippet in `docs/development/CAMERA_IMPACT.md` at his hit-confirm site (comment on his order PR #39). Recommendation: Aki, because it is his file and sits in the middle of his combat PRs; I can verify it live right after.
2. **Tuning after wiring.** Play ten minutes at 60 FPS and tune in this order: `HEAVY_PEAK_PX`, `LIGHT_PEAK_PX`, durations, then `KICK_SIGN` (+1 pushes toward the target, -1 recoils). Recommendation: keep reduced mode available; watch two cases the guide lists: hits toward a pinned east/west wall, and a hit while sprinting at the close zoom.
3. **Order PRs #39 and #40 are still open,** and their own text says they start when they reach the agent's inbox on main. Aki already built Milestone A from #39. Recommendation: merge both (order-only docs); I will do it if you say so.
4. **Still open from my 10-19 report (no answers in the repo that I can see):** the lane rule for PRs that touch other agents' files, the lab starting closed, the missing ground shadow, the close zoom (1.2115 against 1.2 or 1.25), the validation scene split with Aki (his #20 conflicts with main), a camera side margin (this also gives east/west kicks room), the ground-only mockup into git, projection and tile size. Recommendation unchanged; the side margin now has one more reason.

## 10. Comments / recommendations
- **A second reader is worth it for camera code.** The defect lived in an interaction (the engine steps the smoothing inside a setter) that my author's tests, which settled a still camera and drove the clock by hand, could not see. The reviewer built real-input probes and found it in an hour.
- **Test the frame order, not the function.** The fix test runs the helper in its automatic mode with real frames; calling `advance()` by hand skips the engine's real order.
- **A test that depends on the frame rate is a hazard in a required check.** The polish round removed two assertions that only held above about 58 FPS.
- **The network:** the first run stopped on a DNS error while the laptop was idle, after its work was done. Keep-awake and a plugged-in laptop matter for long jobs.

## 11. Next steps
- Your answers to questions 1 to 4. Then I verify Aki's wiring live (the demo telemetry plus one real hit).
- Remove `camfx\wt` and `wt-chief4`, delete the merged local branch, stop keep-awake.
- The validation scene and the 10-19 decisions stay with you.

## 12. Where to look
- Job report (with a live-verification section added by me): [combat camera feedback report](2026-10-20-combat-camera-feedback-report.md). Order: [combat camera feedback animation](../2026-10-20-combat-camera-feedback-animation.md). Guide and event contract: [CAMERA_IMPACT.md](../../../docs/development/CAMERA_IMPACT.md).
- PRs: [#41](https://github.com/kiotdstudios/shinobi-rush/pull/41), [#50](https://github.com/kiotdstudios/shinobi-rush/pull/50), [#53](https://github.com/kiotdstudios/shinobi-rush/pull/53); handoff comment on [#39](https://github.com/kiotdstudios/shinobi-rush/pull/39#issuecomment-6317560759).
- CI: PR runs [39598440526](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39598440526) and [39608145473](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39608145473); main run [39608902631](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39608902631) (the merge, deployed).
- Evidence on the build laptop (not in the repo), under `c:\tmp\shinobi-order01\camfx\`: `review.md` and `review2.md` (the two independent reviews), `evidence\` (local telemetry cases, screenshot pairs, logs), `evidence\live\` (live replay: `live-camfx.json`, three screenshots), `progress.md`, `main-7d8ba83.log` (the merge run log).
