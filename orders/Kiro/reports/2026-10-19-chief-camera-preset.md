# Chief report - Close-combat camera preset live (PR #21), owner reference in git (PR #22), first real art live (PR #23, Codex)
- Agent: Kiro (orchestrator)
- Date: 2026-10-19 local. The merges are 03:12Z, 03:20Z and 08:32Z; this report was written at about 09:00Z (05:00 local; local time is UTC-4).
- Assignment: order [close-combat camera preset and validation scene](../2026-10-19-close-combat-camera-preset-and-validation.md). Your directions: "Kiro can begin the configurable camera preset and validation scene"; "keep the 17.5% player-height target for the first comparison. Don't spend more time tuning it until we see Codex's actual sprite at that scale"; use the ground-only mockup "as a visual reference for paving density and texture, not as a ready-to-import Godot tileset".
- Final status: deliverable 1 (camera preset) **DONE, verified live, also with the real art**. Deliverable 2 (validation scene) **NOT STARTED, waiting for your decision** (Aki's open PR #20 overlaps and now conflicts with main). Review of Codex's PR #23 (it touched my files): done, see section 6.
- This report ships in docs-only [PR #25](https://github.com/kiotdstudios/shinobi-rush/pull/25), written after the live checks in section 4.

**TL;DR**
- **The real sprite at your scale, measured on the live site:** `?camera=close` gives zoom 1.2115 and a standing figure 127 px tall = 17.6 % of 720 (target 17.5 %). Head and feet are visible at the north and south walls. With no parameter nothing changed: wide, 0.4444, 2880x1620, figure 46 px (6.4 %).
- Codex opened PR #23 (the first real art, 847 frames) at 08:06Z and merged it himself at 08:32Z, 26 minutes later. It went red first because of **two assumptions in my browser probe and one in my CI unit tests** (all three assumed no art exists). He fixed all three himself inside that PR, which edits eight code and test files outside the art lane (his report calls them "necessary camera/lab verification corrections" under your approval to publish all passed animations live). I read the edits: they are correct. Two of them change the game: **the animation lab no longer opens by itself, and the ground shadow is gone for every figure** (his report says shadow-free was your request).
- I stopped my own fix (it would have collided with his) and aborted that workflow.
- Needs you: confirm the lane rule and the two game changes (questions 1 to 3), pick the close zoom (question 4), and decide the validation scene split with Aki (question 5).

## 1. Final status per assignment
| Assignment | Status | Why |
| --- | --- | --- |
| Camera preset (order 2026-10-19, deliverable 1, [PR #21](https://github.com/kiotdstudios/shinobi-rush/pull/21)) | **DONE** | Merged as eeed7d2; live `build-info.json` commit equals the merge commit; all six CI jobs of the merge green incl. post-deploy smoke; my replay on the live build matches (section 4), again on the real-art build d9ebccf; independent review APPROVED. |
| Owner's close-combat reference in git ([PR #22](https://github.com/kiotdstudios/shinobi-rush/pull/22)) | **DONE** | Merged as c172f6e; live pck unchanged at 130,736 bytes and contains no mockup path. |
| Validation scene (deliverable 2) | **NOT STARTED, BLOCKED on a decision** | Aki's [PR #20](https://github.com/kiotdstudios/shinobi-rush/pull/20) overlaps, and now conflicts with main (question 5). |
| Probe fix for real art | **SUPERSEDED** | Codex fixed it in PR #23 first; my workflow `wf_263602b9e8c77134` was paused, then aborted. Small follow-ups remain (section 11). |
| Codex's art [PR #23](https://github.com/kiotdstudios/shinobi-rush/pull/23) (not mine) | **MERGED by Codex, live** | d9ebccf, CI green on every workflow; live-verified by me (section 4). Two game changes inside it await your call. |

## 2. What was completed
| PR | Title | Merge commit | Merged (UTC) | What |
| --- | --- | --- | --- | --- |
| [#21](https://github.com/kiotdstudios/shinobi-rush/pull/21) | Camera preset (Kiro): wide default, opt-in close framing | eeed7d2 | 2026-10-19 03:12:39 | `CameraPreset` (`scripts/camera/camera_preset.gd`): `wide` default unchanged; `close` computed as 0.175 x 720 / figure height (snaps to 1.0 only if that keeps the figure in 16-19 %); `?camera=wide\|close\|<number>`; lab key N; `camera_preset` in `__SHINOBI_STATE__`; follows the loaded sprite set's `body_height_px`. 14 files, +716/-19; 73 new in-engine checks (492 total). |
| [#22](https://github.com/kiotdstudios/shinobi-rush/pull/22) | Reference: keep owner close-combat mockup in reference/mockup | c172f6e | 2026-10-19 03:20:28 | Your mockup (1536x1024, 3.3 MB), a README and an empty `.gdignore` so Godot neither imports nor ships it. |
| [#25](https://github.com/kiotdstudios/shinobi-rush/pull/25) | Chief report: camera preset live, first real art | on the PR page (a report cannot cite its own merge commit) | after CI | Docs only: this report, `CHIEF_INDEX.md`, order and job report closed out for deliverable 1. |

Not mine, merged meanwhile: [#23](https://github.com/kiotdstudios/shinobi-rush/pull/23) (Codex, "Publish all passed 128px player animations for live game review", merge commit d9ebccf, 2026-10-19 08:32:14, merged by the shared account; 1,712 files). Open and not mine: #20 (Aki), #15 (Aki, an order), #24 (Codex, docs only: his live-verification report and a two-line change to his validation script).

## 3. Evidence and test results
| Claim | Label | Evidence |
| --- | --- | --- |
| In-engine tests 492 passed, 0 failed (main had 419). A new test fails when the default is flipped (25 red) and when the parser accepts garbage (3 red) | VERIFIED | PR run 39191291445 log read by me; red runs are the workflow's, in its report |
| PR #21 run: smoke 11, controls probe 13, debug probe 26, required checks incl. `godot-ci-gate` green. Main runs 39193598683 (eeed7d2) and 39194231558 (c172f6e): six jobs green each | VERIFIED | job lists read by me |
| Independent review of #21 APPROVED; 12 of 14 production mutations go red; 10 non-blocking points | VERIFIED | `review.md` read by me. Point 3 (probe pinned to 108 px) bit five hours later, see section 6 |
| Main run 39223465511 on d9ebccf (real art): six jobs green incl. deploy and post-deploy smoke. 493 tests passed, 0 failed; smoke 11 + 11 PASS; controls probe 16 PASS, 0 FAIL; debug probe 26 PASS | VERIFIED | job log downloaded and counted by me |
| Live numbers on the real-art build (table in section 4); figure heights measured on screenshots | VERIFIED | my replay, 0 console errors |
| Your reference: standing characters measure 16.2 % of the image height on average (enemies 16.0, 15.5, 16.2, 16.7 %; player lunge 16.6 %), ruler reading, +/- 5 px | VERIFIED (measurement) | `c:\tmp\shinobi-order01\reference\` |
| Those poses are crouched, so upright figures would be 15-25 % taller (about 18.5-20 %) | ASSUMED | not measured; supports 17.5 % as a middle value, does not prove it |
| Paving slab in your ground-only mockup is about 0.30-0.35 x the figure height; our arena diamonds (144x72 world units = 1.33 x figure height) are about 4x coarser | VERIFIED (rough, +/- 25 %) | seam-spacing analysis; not used to change any code |
| Codex's edits to my files (probe, state fields, tests, lab) are correct for what they do | VERIFIED (read) and CI | I read the full diff against main; CI exercises them |
| The two probe failures and the third CI failure had one cause each | VERIFIED | failure text, the probe's own start screenshot ("Lab: ON (Tab)"), `animation_lab.gd` `_set_lab(not lib.sets.is_empty())`, and `check-export` reading the repo's real manifests in a unit test |
| Pixel quality of the art, motion at 1.2115 | NOT CHECKED | see section 8 |

## 4. Live verification
- **URL:** https://kiotdstudios.github.io/shinobi-rush/ . `build-info.json`: `commit_sha` d9ebccfbc77400424fcd1e1558e2daeaaa612d7a (the #23 merge), run 39223465511, built 2026-10-19T08:32:48Z. VERIFIED. `index.pck` is 1,913,712 bytes (130,736 before the art, +1.78 MB). Earlier checks of the preset: eeed7d2 (run 39193598683) and c172f6e (run 39194231558).
- **Post-deploy smoke on the real URL:** passed in all three runs.
- **Replay on the live real-art build** (headless Chromium, software GL, 1280x720, between about 08:45Z and 09:00Z; figure heights measured from the screenshots as head top to feet by pixels that are not ground colours):

| Query | Result |
| --- | --- |
| none | wide, zoom 0.4444, view 2880x1620 (unchanged); figure 46 px = 6.4 %; lab closed; set `player_128`, `figure_height_px` 104 |
| `?camera=close` | close, zoom 1.2115, view 1056.5x594.3; figure **127 px = 17.6 %** |
| `?camera=1.2` | custom, zoom 1.2000, view 1066.7x600; figure 122 px = 16.9 % |
| `?camera=1.25` | custom, zoom 1.2500, view 1024x576; figure 131 px = 18.2 % |
| close + Tab | lab opens (`lab_open` true) |
| close + Shift+D | state SPRINT, speed 607 px/s; figure runs to the east wall |
| close, walk to north / south wall (real keys) | stops at y -1098 / 1125; head fully visible (about 38 px of ground above the hair, read off the magnified picture), feet fully visible with about 23 px of ground below them |
| close, sprint to east / west wall | stops at x 2000 / -2000; the figure ends at the screen edge, partly cut off |
| console | 0 errors in every run |

- **Opened by me:** live close (idle), live default (wide), close sprint (east wall), north wall, south wall, east wall, a magnified crop of the figure, and from Codex's CI run: start, lab at 1x, close. **Numbers only:** `?camera=1.2` and `?camera=1.25` pictures, the west wall, the lab-open picture.
- **Compare it yourself (live):** [close 1.2115](https://kiotdstudios.github.io/shinobi-rush/?camera=close) , [1.2](https://kiotdstudios.github.io/shinobi-rush/?camera=1.2) , [1.25](https://kiotdstudios.github.io/shinobi-rush/?camera=1.25) , [default wide](https://kiotdstudios.github.io/shinobi-rush/). Tab opens the lab.
- **What I saw:** the real ninja (dark skin, spiky black hair, olive vest, white wraps) stands centred on the green diamond ground, no ground shadow under it, no lab panel in the way. The HUD title still says "BOOTSTRAP BUILD - PLACEHOLDER ART".

## 5. Changes made outside code (and how to reverse each)
1. **Merged #21 and #22** (mine) with merge commits after the independent approval. Reverse: revert through a PR.
2. **Committed your mockup to git** with your permission ("u can keep the image in git in a reference/mockup folder"). Reverse: delete `reference/mockup/`.
3. **Three comments on other agents' PRs:** Aki's #20, the overlap and a proposed split (https://github.com/kiotdstudios/shinobi-rush/pull/20#issuecomment-6258871947); Aki's #20, the one-block conflict with main and how to resolve it (https://github.com/kiotdstudios/shinobi-rush/pull/20#issuecomment-6262943782); Codex's #23, "the red check is my probe, please do not edit it" (https://github.com/kiotdstudios/shinobi-rush/pull/23#issuecomment-6262770733). Reverse: delete the comments. No branch of theirs was touched.
4. **Workflow `wf_263602b9e8c77134`** (probe fix) launched, paused after 25 minutes and aborted by me. Its worktree `artcompat\wt` (branch `kiro/probe-art-compat`, nothing pushed) still holds uncommitted partial work; I saved it as `artcompat\partial-step1.patch`. Reverse: remove the worktree and branch.
5. **Keep-awake restarted** (the first one had expired); 4 hours, until about 08:10 local. I stop it when the work ends. The laptop needs power and the lid open.
6. **Git worktrees** registered in the shared clone's `.git`: `occlusion\wt` (kept; its node_modules run my browser scripts), `camera2\wt` and `wt-ref` (merged, to remove), `wt-chief3` (this PR, removed after merge), `artcompat\wt` (see 4). The shared clone's working tree was not touched.
7. **Local only, not in git:** your ground-only mockup (`kosen ground only game mock.png`, 2.9 MB) under `c:\tmp\shinobi-order01\reference\` (question 7).

## 6. Findings about other agents' work and hazards
- **Codex, PR #23 - what it is.** 847 PNG frames with their import records in six animations (idle 120, walk 128, run 160, sprint 151, jump 192, dodge 96), the manifest `player_128.manifest.json` (`body_height_px` 104, foot anchor (64,116), 24 fps, `shadow_baked` false), two preview GIFs, provenance and handoff notes, a validation script, three reports. The game accepts the set ("player_128 128x128 OK").
- **Why its CI went red (my bugs, three of them).** (1) `camera-close-via-query` pinned the placeholder's 108 px, so the correct zoom 1.2115 failed against 1.1667. (2) `lab-close-restores-baseline` assumed the animation lab starts closed, but it opened by itself once a sprite set existed. (3) A unit test of the CI tooling (`test_cli_exits_2_for_an_empty_expect_sha_and_an_empty_commit_sha`) ran `check-export` against the repository's real sprite manifests, which only matters once sprites exist. The preset did exactly what it should. The debug probe could not run behind the first red step; it passes with art (26 of 26).
- **How it got fixed.** My comment (08:14:57Z) asked Codex not to edit `controls-probe.mjs`. His edits landed at 08:25:35Z and 08:27:51Z (CI on the last one started at 08:27:58Z and was green), and he merged at 08:32:14Z, with no review by me (owner of the camera, player, web bridge, lab and probe files). **Eight code and test files outside the art lane were edited**, while his README says "Coordinate integration requirements with gameplay agents; do not silently edit their code". The commits were open and well named, so it was not silent, but it was not coordinated. His report says the owner "explicitly" approved publishing all passed animations live, and that his changes are "limited to the authorized asset-to-live integration and necessary camera/lab verification corrections". I have no record of that approval and none for the code edits themselves.
- **What I read in those edits.** `controls-probe.mjs`: the close zoom is derived from the loaded figure height with the same rule as `CameraPreset`; walk and sprint are compared per physics second; jump and dodge are checked in the lab when the set is `player_128`. `web_bridge.gd`: five additive state fields (`physics_frame`, `figure_height_px`, `sprite_set_id`, `lab_open`, `lab_animation`). `test_safety_and_harness.py`: the right hermetic fix (`--project` points at an empty folder). Tests follow the lab change. **All correct.**
- **Two game changes inside it (not art).** (a) `animation_lab.gd`: `_set_lab(false)`, so the lab no longer opens when art exists; this reverses the earlier behaviour (an in-engine test required it), though the live game now starts without a panel over 27 % of the screen. (b) `placeholder_visual.gd` and `sprite_actor.gd`: the runtime ground shadow is removed for every figure, the placeholder included, "matching owner's shadow-free request" (his report), and the manifest says `shadow_baked: false`, so no figure has any ground shadow now. His report on (a): "loaded art auto-opened lab, invalidating toggle behavior. Lab now always starts closed; tests explicitly open it." Questions 2 and 3.
- **Edge of the arena.** At close zoom the figure ends at the screen edge, partly cut off, at the east and west walls: the camera limits stop at the arena edge and only north and south have head and foot room. Not new with art (same limits); at wide I did not look.
- **Texture memory grows as animations first play:** 18 MB with idle loaded, 31 MB after two animations (the lab HUD). Six animations not measured.
- **Aki, PR #20 (open, 10 files):** an isolated validation scene with a 64 px stone tile, two gate pillars, a bandit placeholder and its own zoom literal `VALIDATION_CAMERA_ZOOM := 126.0/108.0`. He reports 130 px = 18.1 %. No walls, steps, Heavy Bandit, stations or measurement tool; not reachable from the live site. Hazards: the literal is pinned to the placeholder (with the 104 px body it gives 121 px = 16.8 %). **It now conflicts with main in one place**, the comment block above `CAMERA_BASE_ZOOM` in `scripts/world_scale.gd`, which my #21 rewrote too (`git merge-tree`: only that block). GitHub showed it clean when I first looked; this is the overlap the reviewer predicted (point 1). I told Aki how to resolve it and did not touch his branch. His order PR [#15](https://github.com/kiotdstudios/shinobi-rush/pull/15) (playtest Codex's idle art) was waiting for Codex's push, which has now happened.
- **Orcha:** no Orcha PR is open. The camera director still has to layer relative offsets on `CameraPreset` (handoff section "Camera preset").
- **Stale label:** the debug HUD title still reads "BOOTSTRAP BUILD - PLACEHOLDER ART" over real art (not my file).

## 7. Judgment calls you may want to overturn
- **I merged #21 with the reviewer's ten non-blocking points deferred.** Point 3 was exactly the pinned 108 px; it bit five hours later, when I knew art was queued. From now on I grep tests and probes for placeholder literals (108, 126, 1.1667) before merging while art is imminent.
- **I launched a probe-fix job immediately, and aborted it 25 minutes later** when Codex's own fix appeared: two fixes on the same lines would only conflict, his CI was heading to green, and his names (`figure_height_px`, `lab_open`) are as good as mine. Cost: one workflow step and a saved partial patch.
- **I did not object to his two game changes, I flagged them for you.** They are small and reversible, the shadow one is said to be your request, and the lab change helps the framing review.
- **I commented on his PR instead of editing his branch,** and I did not merge anything of other agents.
- **Kept 17.5 % and the wide default,** as you said. I did not re-tune anything after seeing the real sprite.
- **I ran the live replay on the art build before writing,** although the merge was not mine, because the camera claims on real art are mine.

## 8. Not verified (said plainly)
- Real GPU frame rate, other browsers, phones, controllers, memory on phones with all six animations loaded.
- The art itself: silhouette, anchor in every animation, jump and dodge in play (I saw idle, walk and sprint frames only).
- Wall occlusion with the real sprite (the front face may clip arms or weapons wider than about 25 px from the foot anchor: the idle figure is 55 px wide on screen at close, about 45 world px, so inside; the sprint pose is wider and was not checked).
- Whether 1.2115 shimmers on 1 px details in motion with nearest filtering (the earlier study says non-integer zooms do).
- The east and west walls at the wide zoom, and head/feet at the walls at wide with art.
- Whether you approved the code edits inside #23 (Codex's report cites your approval to publish the animations and your shadow-free request; I have no record of either).

## 9. Questions for the chief
1. **Lane rule.** PR #23 edited eight code and test files outside the art lane (under your approval to publish the animations live, per Codex's report) and was merged by its author four minutes after his last push. Accept it retroactively? Recommendation: yes for the probe, test, state and CI-fixture edits (reviewed, correct); and agree a rule: a PR from an art or gameplay branch that touches another agent's files needs that owner's comment before merge. I can add a warning-only check to `validate-orders-and-project` (branch prefix to allowed paths) if you want it enforced.
2. **The lab no longer opens by itself.** Keep? Recommendation: keep, because the framing review needs an unobstructed screen and art reviewers just press Tab; I will add a line to `SPRITE_DROP_IN.md` and the handoff saying the lab starts closed and Tab opens it, in a small follow-up.
3. **No ground shadow for any figure.** Codex says shadow-free was your request (his report: `orders/Codex/reports/2026-10-19-shadow-free-jump-dodge-review-report.md`). Is it final for gameplay, or only for the animation review? The manifest has `shadow_baked: false`, so today nothing marks where the feet touch the ground, which will matter for combat readability. Recommendation: keep it for the animation review; when combat needs ground readability, add a faint shadow that stays at the logical ground position (right for jumps), off when a set says `shadow_baked: true`.
4. **Close zoom for the real art.** The standard body is 100-112 px, so 17.5 % needs a zoom of 1.125-1.26, never 1.0; my snap-to-1.0 rule cannot fire for it. Codex's 104 px gives 1.2115 (127 px, 17.6 %). A simple ratio keeps the nearest-neighbour pixel pattern regular: 1.2 (6:5) gives 122 px = 16.9 %, 1.25 (5:4) gives 131 px = 18.2 %; both measured live. 1.2 is inside 16-19 % for every 100-112 px body. Recommendation: open the three live links in section 4 and pick one; if you choose 1.2, `close` becomes a fixed 1.2 in a small PR. This is the sprite-filtering question (options A to D) from my earlier report, now concrete.
5. **Validation scene: who builds what?** Aki's #20 composes an isolated scene; my staged job would build the same thing again. Proposal: Aki keeps scene content and ground tiles; once #20 lands I add the `CameraPreset` integration (replacing his 126/108 literal), a `?scene=validation` entry reachable from the live site, stations, a measurement tool against the reference, a CI probe and props built as `Block` + `BlockRear`. Recommendation: yes, and tell Aki to merge main into #20 (one comment-block conflict) and land it first.
6. **Camera side margin.** Add east/west room like the north/south head and foot room, so the figure is never half cut at the screen edge? Recommendation: yes, together with the validation scene; it is a small camera-limit change.
7. **Ground-only mockup into git?** Same folder and `.gdignore` as the first one; it is your file, so I ask first. Recommendation: yes.
8. **Projection and tile size.** Your reference is true 2:1 isometric; the game draws oblique blocks. The paving in the mockup is about four times finer than our arena diamonds. Recommendation: keep the oblique blocks for the first validation scene (fast), call the projection an open owner decision, settle tile size after you see the scene.
9. **Still open from earlier reports:** figure size 48 px against 57 px at the wide view (the figure is now 46 px with the 104 px set), the east-base wedge collider, the gated test teleport, test hardening, whether to verify Aki's debug-log chain on the live build, and the items in the [first chief report](2026-10-18-kiro-chief-report.md). Recommendation: unchanged; I would take the debug-log check next.

## 10. Comments / recommendations
- **The art is in, and the instruction "wait until we see the sprite at that scale" can be followed now.** The links in section 4 show it at 1.2115, 1.2 and 1.25.
- **Three of my own tooling assumptions broke on first contact with real art** (a pinned figure height, a lab that starts closed, a unit test reading the real repository). All were found by CI before the art reached the live site, which is the point of CI. I should have hunted them before the art arrived, since I knew it was queued.
- **Speed.** The art went from PR to merged in 26 minutes and to live in about half an hour, much of it CI waits. My probe fix would not have been faster than his.
- **Pipeline order hides failures:** the first red step stops the later ones (smoke, controls probe, debug probe). The debug probe had never run with art until his fix; it passes.
- **Process:** a shared account means GitHub cannot tell the agents apart, so lane discipline has to be a written rule or a CI check (question 1).

## 11. Next steps
- Your answers to questions 1 to 6. Then one small follow-up PR of mine: the review's open points that still apply (a test that guards the N key binding, the vacuous figure-height test, the state test that reads source text, the stale `web_bridge.gd` header comment, a length guard for very long `camera=` values), the stale handoff lines, the docs for the lab and the new state fields. My saved partial patch covers part of it.
- Validation scene after your answer to question 5.
- Cleanup: remove `camera2\wt`, `wt-ref`, `wt-chief3` and `artcompat\wt`; keep `occlusion\wt`; stop keep-awake when the work ends.

## 12. Where to look
- Job report (workflow's, with the live sections added by me): [camera preset report](2026-10-19-camera-preset-report.md). Order: [close-combat camera preset and validation](../2026-10-19-close-combat-camera-preset-and-validation.md). Codex's reports for #23: `orders/Codex/reports/2026-10-19-production-animation-assets-report.md`, `...-shadow-free-jump-dodge-review-report.md`, `...-live-animation-review-report.md`.
- PRs: [#21](https://github.com/kiotdstudios/shinobi-rush/pull/21), [#22](https://github.com/kiotdstudios/shinobi-rush/pull/22), [#23](https://github.com/kiotdstudios/shinobi-rush/pull/23), [#25](https://github.com/kiotdstudios/shinobi-rush/pull/25); open: [#20](https://github.com/kiotdstudios/shinobi-rush/pull/20) (Aki).
- CI: PR run [39191291445](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39191291445); main runs [39193598683](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39193598683), [39194231558](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39194231558), [39223465511](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39223465511) (real art); Codex's first red run [39220440077](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39220440077).
- Docs: [GODOT_PROJECT_HANDOFF.md](../../../docs/development/GODOT_PROJECT_HANDOFF.md) ("Camera preset"), [reference/mockup/README.md](../../../reference/mockup/README.md).
- Evidence on the build laptop (not in the repo), under `c:\tmp\shinobi-order01\`: `camera2\review.md`, `camera2\evidence\live\` and `live-c172f6e\`, `codex23\evidence\live-art\` (live real-art screenshots, `live-art.json`, walls), `codex23\` (the failed log and Codex's CI screenshots), `reference\` (measurement tools and sheets), `artcompat\` (aborted job, brief and partial patch).
