# Job Report — Bandit vision debug overlay (P0)
- Agent: Kiro
- Order: `orders/Kiro/2026-10-22-bandit-vision-debug-overlay.md` (owner request: "For the game test I want to be able to see what the bandit's in-game vision is.")
- Date: 2026-10-22
- Final status: REVIEW. Implemented, tested, verified on a local Web export, documented. NOT DONE: the independent review, the required CI on the PR head, the merge and the live check on the deployed build come next (the orchestrator's). The worker does not merge and does not set DONE.
- Commit / PR: branch `kiro/bandit-vision-overlay`. Code commit 5ef94fbd479081ca79160f03c3188e4ab0de856d (the local export was built from it); the PR head adds only docs, the order and this report (no game file), so the export is code-identical to the PR head. The PR number and the CI run ids are in the PR and in the orchestrator's messages (a report cannot hold the CI result of its own head).

## Work completed
A toggleable, real-time picture of exactly what the Level 1 Bandit's AI accepts as "seen", in the real playable arena, debug only and OFF by default.

- **What it draws** (full legend in `docs/development/BANDIT_VISION_OVERLAY.md`): per live Bandit a translucent region plus outline (the cone of 110 degrees and 700 px with a 150 px close-sense circle while the Bandit is not chasing, a full 945 px circle while it chases, in both cases cut by every wall, rock and other blocker), the sample rays, the facing arrow, a label (level, real State name, category text, cone or circle numbers, "AI sees player: YES/no"), a last-seen cross while the AI uses it, and a ring with "SEEN" on the player ONLY while the AI's own `sees_player` is true. Okabe-Ito colours plus a different outline style and a text per state: not alert (green, solid), suspicious (yellow, dashed), detected (vermillion, thick), lost sight (purple, dash-dot), searching (purple, dotted), returning (blue, long dash); DEAD draws nothing.
- **Truth over prettiness:** the polygon is built from the AI's own numbers (`profile.sight_range`, `fov_deg`, `close_sense`), the same chasing rule and the same physics ray query as `Bandit.can_see`. Nothing in the AI was changed (no tuning, no behaviour, no accessor): `scripts/enemy/**` has zero diff.
- **Toggle:** key `F2` (not the suggested F6, reasoning below), an always-visible button "Bandit vision: off/ON (F2)" left of "Lab (Tab)" (works with the lab closed), `?vision=1` to start ON. One legend line in the HUD.
- **Telemetry** (additive, 21 `vision_*` fields in `__SHINOBI_STATE__`): switch, Bandits drawn, polygon points, rays, cost in ms, category, the AI's own State and `sees_player`, `can_see` at that instant, whether the polygon contains the player, cone flag, range, close sense, FOV, facing, polygon apex, mismatch count, budget flag, and the scene-tree node count. Two of them (`vision_nodes`, `vision_origin_x/y`) were added in this step so the browser run could PROVE "OFF leaves no node" and "the overlay is not a frame behind" with numbers.

### The AI code paths used (all VERIFIED by reading `scripts/enemy/bandit.gd` at main 471f312)
| What | Where | Mirrored in |
| --- | --- | --- |
| `_update_perception()`: `chasing := state in [NOTICE, APPROACH, THREATEN, ATTACK, REPOSITION, RETREAT]`, `sees_player = can_see(player, not chasing)`, `last_seen` while seen | `bandit.gd:224-231` (lines 228, 229, 231) | `BanditVisionRegion.CHASING_STATES`, `uses_cone()` (mirror, guarded) |
| `can_see(target, use_cone)`: `reach = sight_range * (1.0 if use_cone else 1.35)`; with the cone and `d > close_sense` the test `abs(facing8.angle_to(to)) > fov_deg / 2` rejects; then `line_clear_to` | `bandit.gd:236-246` (239, 242-245) | `CHASE_REACH_MULT = 1.35` (**mirror of a literal**, guarded), wedge +-`fov_deg / 2` with exact seams, close-sense circle |
| `line_clear_to`: ray `global_position + EYE_OFFSET` to `target + EYE_OFFSET`, exclude own RID and the player's, default mask, bodies only | `bandit.gd:250-259`, `EYE_OFFSET = Vector2(0, -13.5)` at line 28 | the same `PhysicsRayQueryParameters2D` for every sample ray |
| Sight is decided once per physics tick after `_find_player()`; not in hitstop (151), DEAD (164), EVADE (166), HIT_REACT (178-190) | `bandit.gd:192-193`, `778` for `_find_player` | EVADE / HIT_REACT labelled "AI sight paused"; DEAD hidden |
| Timers the overlay does NOT show: notice 0.65 s, blind grace 0.5 s, lose-sight 2.2 s, leash 1500 px | `bandit.gd:345, 350, 362, 365-366, 403` | documented under "What it does NOT show" |

Public, read-only members used: `state`, `facing8`, `profile`, `sees_player`, `last_seen`, `intelligence_level`, `global_position`, `can_see()`, `get_state_name()`, `get_notice_progress()`, `get_rid()`, const `EYE_OFFSET`. Private ones (`_player`, `_resume_state`, timers) are not touched; the overlay finds the player like `_find_player` (first node of group `player`).

### Design decisions you may want to overturn
1. **F2, not F6.** The input map and every key-collision test are clear for F6, but F6 is the address-bar / pane-focus key in Chrome, Edge and Firefox. Godot's Web runtime `preventDefault()`s canvas key events, which should stop it, but I cannot drive a headed browser (Playwright injects events below the browser UI), so "no conflict" could not be shown. The brief says to use F6 only if all checks are clear. F2 is unbound everywhere and follows the F-key family (F1, F7, F8, F9). The button is the guaranteed path. Recommendation: keep F2; add F6 as a second binding only after a check in a headed browser.
2. **EVADE and HIT_REACT** draw the chasing (no-cone) region and say "AI sight paused", because the AI skips its sight evaluation there and both states always continue to APPROACH. Alternative: draw the cone for them (flickers for 0.2 s).
3. **The overlay mirrors two things the AI does not expose** (the `1.35` literal and the chasing list) instead of changing `bandit.gd`. Alternative for Aki: expose them as a const or profile field so the overlay reads them (see "Dependencies on Aki").
4. **Two extra telemetry fields** beyond the brief's list (`vision_nodes`, `vision_origin_x/y`), both additive.
5. **The existing HUD legend constant was extended** by one text line in `debug_hud.gd` (the constant is a single source line, so the diff shows one line replaced) so the key and the URL option are documented where testers look.

## Files changed
18 files, +2277/-4 against main 471f312 (`git diff --stat origin/main`, this report included):
- NEW `scripts/debug/bandit_vision_region.gd` (257 lines, the AI-faithful polygon), `bandit_vision_overlay.gd` (340, world-space drawing, lifecycle, runtime sync probe), `bandit_vision_toggle.gd` (223, action, button, URL option, telemetry), each with its `.uid`.
- NEW `tests/test_bandit_vision_overlay.gd` (1021 lines, 122 checks, + `.uid`); `tests/run_tests.gd` +1 include line.
- EDITED `scripts/ui/animation_lab.gd` (+6: creates the switch and its button in the lab's always-visible layer), `scripts/ui/debug_hud.gd` (legend line), `scripts/web/web_bridge.gd` (`?vision=` at boot, the 21 fields), `scripts/ci/smoke/controls-probe.mjs` (+112, new checks only).
- Docs: NEW `docs/development/BANDIT_VISION_OVERLAY.md`; one pointer each in `docs/development/GODOT_PROJECT_HANDOFF.md` and `docs/prototype/TESTING.md`. Order status and log in `orders/Kiro/2026-10-22-bandit-vision-debug-overlay.md`; this report.
- NOT touched (VERIFIED, `git diff --stat origin/main -- scripts/enemy scripts/arena scenes project.godot` is empty): `scripts/enemy/**`, `scripts/arena/**`, scenes, `project.godot`, assets, presets, the camera impact module, `docs/visuals/**`, other agents' orders. No screenshot or clip is in the PR. All new files are LF.

## Tests run before commit
Machine: Windows, Godot 4.7.2 console build, headless Chromium (SwiftShader software GL, 1280x720, the game runs at 4 to 9 FPS). Evidence (not committed): `C:\tmp\shinobi-order01\bvis\evidence\`.

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py tests` on fresh main 05c7c8f, own worktree, before any edit | SUMMARY: 1045 passed, 0 failed (VERIFIED; a first run had 1 timing failure of the existing camera-impact check "during local hitstop..." while the PC was busy, it passes alone) | logs-s1\tests-base2.log |
| `godot_ci.py import`, `validate-resources`, `validate_godot_project.py`, `check_workflows.py`, `validate_orders.py` on the final tree | all exit 0 / PASS (0 errors, 0 warnings, 0 problems) (VERIFIED) | logs-s1, logs-s2-export |
| `godot_ci.py tests` on the code commit 5ef94fb | **SUMMARY: 1167 passed, 0 failed** = 1045 + 122 new (VERIFIED). The only WARNING is the intentional `t_badsheet` fixture | logs-s1\tests-s2final.log |
| New file alone (scratch runner outside the repo) | 122 passed, 0 failed in ~16 s (VERIFIED) | logs-s1\vision-s2b.log |
| Oracle in the real arena (Aki's walls, rocks, bounds) | see "Oracle numbers" (VERIFIED) | logs-s1\vision-s2b.log |
| Red proof, 5 temporary mutations on the final code, each restored from a backup (SHA-256 identical), `grep MUTATION` finds 0 | see "Red proof" (VERIFIED) | logs-s1\mutations.txt (step-1 run kept as mutations-step1.txt) |
| Local Web export of 5ef94fb with the CI commands: `import` 6.1 s, `validate-resources` 4.5 s ("validated 55 scripts, 8 scenes, 0 failures"), `export` 10.2 s, `finalize-export` 0.4 s ("export OK ... (38 MiB), build-info.json written for commit 5ef94fb..."), `check-export` 0.6 s ("export check: OK"), `GITHUB_SHA` set for export + finalize only | all exit 0 (VERIFIED) | logs-s2-export\summary.txt, export\build-info.json |
| `node --check scripts/ci/smoke/controls-probe.mjs`; the controls probe against that export | **30 checks, 30 PASS, 0 FAIL, VERDICT PASS, 130 s** = 23 existing + 7 new; 31 console messages, 0 error/pageerror (4 SwiftShader "GPU stall" warnings), 0 "OUT OF SYNC" (VERIFIED) | probe-p1\controls-probe.mjs.log, probe-result.json |
| Real-key scenario on that export (scratch scripts), final runs | see "Browser scenario" (VERIFIED) | scenario\ |
| Esc pause with the overlay ON on that export | Bandit moved 112.7 px before Esc, **0.000 px over 15 paused frames** while the overlay stayed ON (126 points, apex on the Bandit), moved 30.3 px after resuming, 0 console errors (VERIFIED) | scenario\pause-check.json, pause-ON-while-paused.png |

### Oracle numbers (the core test)
In the real arena scene, `overlay.region_contains(p) == bandit.can_see(p, use_cone)`: **204 configurations** (9 spots x 1 to 8 facings x PATROL (cone), APPROACH and NOTICE (chasing, no cone), SEARCH and RETURN (cone), EVADE (paused, no cone)), **136,044 sampled player positions** (29,108 the AI sees, 106,936 not; both answers > 100 per mode). Samples: random in and out of range, the max-range edge at -3 / -0.5 / +0.5 / +3 px, the close-sense edge, the cone edges at +-0.2 / +-1 degree, behind the facing, straight ahead, and points on and 0.4 / 3 / 40 px around the shadow edges through every corner of every blocker. Result: **0 disagreements outside the stated 1.0 px band; 1 inside it, 0.05 px from the AI's own decision boundary** (checked with `can_see` itself, not with a model). Max 273 rays per rebuild, 0 rebuilds capped. The band is justified by the bisection floor (0.012 degrees = 0.14 px at 700 px) and the arc sagitta of a 3 degree step (0.24 px at 700 px). An independent geometry check (a box of known size added to the live physics world) put the polygon vertices on its front face within 0.05 px and its corners within 0.2 px. An AI-flag oracle ran the AI's own `_update_perception()` in each of 12 States at 6 places: 72 rows, 0 mismatches with "polygon contains the player".

### Red proof (each shown red, restored, marker grep 0)
| Mutation of production code | passed / red (122 checks) |
| --- | --- |
| MUT1 the polygon ignores walls (no ray query) | 109 / 13 |
| MUT2 wrong cone half-angle (0.4 x FOV): oracle 1286 of 136,044 samples disagree | 119 / 3 |
| MUT3 a DEAD Bandit keeps its polygon | 118 / 4 |
| MUT4 mirrored chase multiplier 1.0 instead of 1.35 (also fails the source guard) | 113 / 9 |
| MUT5 OFF only hides the overlay instead of freeing it | 114 / 8 |

Other native coverage (VERIFIED): the State mapping for every `Bandit.State`; hidden on DEAD; a new Bandit while the old lies dead; two Bandits; another Bandit blocking the line like for the AI; a freed Bandit; zero Bandits; scene freed while ON; arena restart gives a fresh overlay on the new Bandit; `?vision=1` and `?vision=0` at boot; 100 ON/OFF pairs in one frame and 100 over real frames (node count and draw items stable); lab and F1 panels opened and closed with the overlay ON; OFF = no node, no `_process`, 30 frames compute nothing; the player walks the same distance ON and OFF and the camera is identical (input, camera, collision untouched); no input callbacks; the toggle does not consume F2; the key is not shared with any other action; per-frame cost bound; a moving test on 420 real ticks and 1011 rendered frames with the camera following (at the last `_process` of every frame the polygon is on the Bandit's current position and facing, 0 stale frames; AI flag and polygon differ in 1 frame, one tick).

## Browser verification (local export of 5ef94fb)

### Controls probe, 7 new checks (all PASS)
`vision-default-off` (all 21 fields present, zero geometry, nodes 155), `vision-key-toggles-on-off` (F2: ON 1 Bandit 112 points 115 rays nodes 156; OFF zero, nodes 155), `vision-button-toggles-on-off` (same through the button), `vision-follows-and-agrees-with-ai` (20 published frames while the Bandit walked 234 px: 0 disagreements between the overlay and the Bandit's own State, `sees`, `can_see` of the same publish; apex within 0.0000 px of the Bandit; mismatch 0), `vision-repeat-toggle-stable` (12 ON/OFF cycles alternating F2 and the button = 24 toggles, nodes back to 155), `vision-url-starts-on` (`?vision=1`), `vision-url-on-then-off-leaves-nothing`.

### Real-key scenario (scratch scripts `scenario.mjs`, `geom.mjs`, `analyze.mjs`; not in the repo)
Real key presses and real mouse clicks on the real button, one Web export, every published frame recorded by an in-page timer (no per-sample round trip). Page A uses the default camera (the owner's view), page B `?camera=0.3&vision=1` (zoomed out only so that the Bandit stays in view while the player is 1500 px away). **746 published frames, 655 with the overlay ON, 636 with a live Bandit compared on four opinions:** the AI's `sees_player` flag, the AI's `can_see(player)` at that instant, the drawn polygon, and an independent hard-coded model of the rules and the arena blockers (`geom.mjs`, a segment-vs-box test).

| Comparison, every frame | Result |
| --- | --- |
| Overlay publishes the Bandit's own State / `sees` / position (apex within 0.01 px) | 0 mismatches |
| AI `can_see` at that instant vs the drawn polygon | 0 disagreements |
| AI `sees_player` flag vs the polygon | 0 differences (the one-tick lag did not show in this run) |
| Independent model vs `can_see`; cone flag, range, category text vs the rules | 0, 0, 0, 0 |
| Overlay's own sync probe `vision_mismatch` / `vision_capped` | max 0 / 0 frames |
| Console | 0 errors, 0 "OUT OF SYNC" on both pages |

**Situations reached (frames by the model's class of the player relative to the Bandit):** out of range 363; in range AND in the cone angle but a wall or rock between 29; in range behind the facing with a clear line 14; behind the facing and behind a wall 32; seen 198 (175 within the 150 px close-sense circle, mostly the fights). In every class the AI flag, the polygon and `can_see` agreed. **Bandit States seen (frames):** PATROL 373, THREATEN 78, ATTACK 71, RETURN 39, APPROACH 23 (detected 13, lost sight 10), SEARCH 16, EVADE 11, REPOSITION 9, RETREAT 6, HIT_REACT 5, NOTICE 5; DEAD hidden for 19 frames. Movement: the Bandit travelled 13,518 px and the player 10,289 px over consecutive frames, 373 frames with the Bandit moving, 86 with both moving, the camera following.

**Crossings of the true boundary (each: the AI flag, `can_see` and the polygon flipped in the same published frame):**
- From BEHIND the facing: unseen at 171.9 px with the Bandit facing away (163 degrees off its facing, clear line, in range), seen at 91.6 px after it turned (inside the 150 px close-sense circle). Not a single-pixel edge sample (the frame gap was 80 px).
- Cone range edge: unseen at 731.2 px, seen at 696.5 px (limit 700); the first sighting was at 696.0 to 697.6 px in all seven lane approaches recorded across my runs (the archived ones are in `scenario-run1\` to `scenario-run5-AB-kill-ok\`).
- Chase range edge: seen at 905.2 px, unseen at 949.3 px (limit 945), in APPROACH, the player running away at 607 px/s.
- Wall: the player INSIDE the cone's angle (17 degrees) and range (623 px) but behind the north wall: not seen, and the picture shows the wedge cut by the wall (frame-exact A-03).
- A flee that loses sight: APPROACH, sight lost at the 945 px edge, "lost sight" category, then SEARCH (cone again), RETURN, PATROL.

**Toggles, panels, OFF (page A):** 20 ON/OFF cycles + a final ON = **41 toggles, 10 cycles by F2 and 10 by the button**: every ON had 1 Bandit and nodes 156, every OFF 0 points, 0 rays, empty state and nodes 155, 0 bad. Lab (`Tab`) x4 and F1 diagnostics x4 with the overlay ON: still ON and drawing every time, nodes 156 after each cycle. OFF in the middle of a fight (Bandit THREATEN): zero geometry, nodes 156 to 155; ON again through the button: 156. Esc pause: see the test table.

**Kill with real J presses (39 presses, 51 s):** REPOSITION, THREATEN, ATTACK, RETREAT, APPROACH, EVADE, HIT_REACT, then DEAD. After death `vision_bandits` 0, `vision_points` 0, `vision_rays` 0, `vision_state` "", the switch still ON, node count 156: nothing drawn, nothing published, no ghost polygon.

**Cost in the WASM build** (software GL, n=636 rebuilds): `vision_ms` average 2.2 ms, median 1.8, 95th percentile 3.9, max 18.3 (one outlier); rays average 147, max 291; polygon points average 143, max 282; `vision_capped` never set. Median `state.fps` with the overlay OFF vs ON at the same idle spot: 7 to 8 in both (the counter is an integer; no difference visible). ASSUMED: on a real GPU at 60 FPS the cost is the same few milliseconds of CPU raycasting per frame.

### Pictures (1280x720 canvas; all OPENED by me, one per call; in `evidence\scenario\` unless marked)
Each was taken inside the animation frame whose published state satisfied the trigger (`canvas.toDataURL` in a patched `requestAnimationFrame`), because `page.screenshot` takes about a second at this frame rate and missed the 0.65 s NOTICE state in the first run.
- `A-01-off-start` (run 1 copy): default view, the player at Pos (0,135), grey placeholder blocks, nothing coloured; top right "Bandit vision: off (F2)" next to "Lab: off (Tab)"; the bottom legend has the new F2 line.
- `A-03-wall-clips-the-cone` (also serves as the patrol cone): the Bandit at lower right facing north-west, a bluish-green wedge with a solid outline and an arrow, label "L1 PATROL: not alert / CONE 110 deg range 700 px close 150 px / AI sees player: no". A straight edge along the long wall's east face cuts the wedge; a narrow strip passes through the gap and runs west. The player (left, Pos 792,-377) is inside the wedge's angle but behind the wall: outside the shape, no marker.
- `A-06-behind-the-facing`: the player (centre, Pos 1003,-247) 406 px west of the Bandit with a clear line; the green wedge and arrow point east, away from him. He is unmarked; "AI sees player: no".
- `A-04-notice`: the approach from behind, yellow dashed outline, "L1 NOTICE: suspicious: acquiring 5% / NO CONE (chasing) range 945 px / AI sees player: YES", a SEEN ring on the player 139 px away.
- `A-05-detected`: "L1 THREATEN: PLAYER DETECTED" in vermillion with a thick solid outline, the full circle sliced by the walls, a ring and "SEEN" on the player, "Hand over your ryo!" above the Bandit.
- `A-10-hit-react`: "L1 HIT_REACT: PLAYER DETECTED / NO CONE (AI sight paused, next look is chasing) range 945 px / AI sees player: YES".
- `A-08-off-in-fight`: the button reads "off (F2)", the Bandit (red, with a health bar; the published state around the shot was ATTACK then APPROACH) just below the player, nothing coloured drawn. `A-09-on-again`: "ON (F2)", "L1 ATTACK: PLAYER DETECTED", orange circle cut by the wall and a block, SEEN ring.
- `A-12-bandit-dead`: caption "BANDIT L1 (DEAD)" over the corpse beside the player, button still "ON (F2)", no region, label or marker.
- `B-b2-detected-before-flee` (zoom 0.3): "L1 APPROACH: PLAYER DETECTED", the thick orange circle reaching the player only through the gap between the two long walls, SEEN ring.
- `B-b4-searching`: dotted purple cone, the "last seen" cross ahead of the Bandit, "L1 SEARCH: lost target: searching / CONE 110 deg ... / AI sees player: no"; the player is the tiny figure at far left, unmarked. `B-search-looks-around-SHEET.png`: 6 frames (125 to 135) of that cone turning from west to north-west in a 45 degree step, clipped by a different block each time.
- Run 4 copies of the same triggers, also opened: `B-b1-notice` (yellow dashed circle reaching the player through the gap, "acquiring 3%"), `B-b3-lost-sight-chasing` ("L1 APPROACH: lost sight / NO CONE (chasing) range 945 px / AI sees player: no", mauve dash-dot circle, "last seen" cross at its left edge where the player ran out of range), `B-b5-returning` (blue long-dash cone, "L1 RETURN: returning to patrol"), in `scenario-run4-B-search-ok\`. Run 1 also: `A-02-patrol-cone`, `A-06-off-in-fight`, `A-07-on-again` in `scenario-run1\`.

## Discrepancies between the overlay and the AI
**None found.** Native: 136,044 oracle samples, 1 inside the 1 px band (0.05 px). Browser: 636 compared frames, 0. Observations about the AI itself, none an overlay defect (nothing was hidden, nothing in the AI was changed):
1. **One-tick lag at a state change (documented, seen once in an earlier run).** In the lane-flee run (`scenario-run2-B-lane\`, analysis in `analysisB.txt`) the first RETURN frame showed `bandit_sees` true at 767 px (computed under APPROACH's no-cone rules earlier in the tick) while the drawn RETURN cone, which is shorter (700 px, cone), did not contain the player; the next frame's flag agreed (explained as lag by the next-frame rule). No such frame in the final run.
2. **Chase leash vs SEARCH.** A plain sprint west along the lane makes the Bandit chase at 470 px/s while the player runs 607 px/s (both measured in the browser: 470 and 607). The leash (`bandit.gd:365-366`) fires when the Bandit is 1500 px from home (x about -188) with the gap still 748 px and the Bandit still SEEING the player, and sends it to RETURN. SEARCH only happens if sight is lost first. The only way found with real keys: start running about 260 ms after the first NOTICE sample (the player is just past 945 px when the Bandit commits; blind it walks at 320 px/s, `bandit.gd:385-386`, and enters SEARCH). A hide-behind-the-wall-and-run-north attempt did NOT work (the wall blinded the Bandit for only about three frames; it came through the gap and saw the player again at 415 px and kept chasing him to the north edge; `scenario-run3-B-north-failed\`).
3. EVADE and HIT_REACT skip the sight evaluation entirely (`bandit.gd:151-190`), so the `sees_player` flag is stale there (16 frames in the final run).

## Dependencies on Aki (nothing blocks the PR)
- `Bandit.can_see` holds the chase multiplier as the literal `1.35` (`bandit.gd:239`), and the chasing list is inline in `_update_perception` (`bandit.gd:228`). The overlay mirrors both and guards them three ways: a unit test parses `bandit.gd` for them, the oracle compares with the live `can_see` at the max-range edge, and the runtime probe flags a mismatch. If either changes the unit tests go red and a running overlay shows "OVERLAY OUT OF SYNC WITH AI". Suggested change (NOT applied, `scripts/enemy/**` is Aki's): expose them (`const CHASE_SIGHT_MULT := 1.35` used in `can_see`, and the chasing list as a const) so the overlay can read instead of mirror.
- Aki changes the Bandit several times a day: expect `scripts/web/web_bridge.gd` and `tests/run_tests.gd` to be merge hotspots (one include line, additive fields only, new tests in a new file). Main had not moved since the merge of PRs #71/#72 (471f312) when this report was written.

## Issues encountered
- First attempt at the NOTICE picture missed (a `page.screenshot` takes about 1 s at 5 to 8 FPS, longer than the 0.65 s NOTICE state): fixed by capturing inside the animation frame.
- First SEARCH attempts failed for the AI reasons above; the working flee is documented.
- My own scratch export wrapper wrote `import.log` into the folder where `godot_ci.py --log-dir` writes the same file name (PermissionError); renamed the wrapper's captures. No effect on the repo.
- Baseline flake on main (not mine): `impact real frames: during local hitstop the effect still runs on its own...` (`tests/test_camera_impact.gd`) failed once on fresh main while the machine was busy and passed alone; its timing assumptions hold only at high frame rates.
- Godot-starting shell calls often return `^C` or exit -1 while the job runs; the logs were read afterwards. Nothing was lost.

## Not verified (said plainly)
- Real GPU rendering and frame rate (SwiftShader software GL only); any browser other than headless Chromium; a headed browser, so **F6 and any browser-reserved key**; a touch screen.
- The owner's own play session on the live game. The pictures and numbers above come from scripted real-key sessions on a local export.
- The deployed build: nothing was deployed from this branch; the orchestrator verifies `build-info.json` and a replay after the merge.
- The WASM cost on a real device (only software-GL numbers).
- Obstacles narrower than the ray spacing (the arena has none; the spacing is 3 degrees, 47 px at 900 px).

## Questions for project owner
1. Keep F2, or also bind F6 after a headed-browser check? Recommendation: keep F2 for now (the button always works) and add F6 only if the owner wants it and can confirm it reaches the game in Chrome.
2. The overlay is available to anyone through the key, the button or the URL in the test build (like the Lab button). Should it be gated behind a developer flag before a real release export? Recommendation: leave it for the test build, gate it (`OS.is_debug_build()` or `?debug=1`) when a release export exists.

## Outstanding work / next steps
- Independent review of the PR, required CI on the PR head (godot-ci-gate), merge by the orchestrator, then the live check: `build-info.json` `commit_sha` equals the merge commit; open the live URL with `?vision=1`, read `vision_on` and `vision_points` from `window.__SHINOBI_STATE__`, one real-key replay of the lane approach (NOTICE at about 697 px, "lost sight", SEARCH, RETURN) and one picture.
- For Aki: the optional exposure of the chase multiplier and the chasing list, and a decision whether the leash should send a Bandit that still sees the player to RETURN (a balance question, not an overlay one).
- Optional later: an F6 alias, more intelligence levels (nothing to do, the profile is read live), other enemy classes (see the extension notes in the doc).
