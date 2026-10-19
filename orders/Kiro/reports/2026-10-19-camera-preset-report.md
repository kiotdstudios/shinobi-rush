# Job Report — Configurable camera preset (close-combat framing)
- Agent: Kiro
- Order: orders/Kiro/2026-10-19-close-combat-camera-preset-and-validation.md (deliverable 1)
- Date: 2026-10-19
- Final status: DONE for deliverable 1 (set by the orchestrator after the live check; the workflow had left it at REVIEW). PR #21 merged as eeed7d2, verified on the live build, see "Live verification (added after the merge)" below. Deliverable 2 (validation scene) is not started.
- Commit / PR: implementation commit 17bfa53 on kiro/camera-preset-close, PR head 7fea08d; [PR #21](https://github.com/kiotdstudios/shinobi-rush/pull/21) merged as eeed7d2793c197f996ee547449fc45e20f6fb401 (2026-10-19T03:12:39Z). PR CI run 39191291445 (all required checks green: 492 passed / 0 failed, smoke 11, controls probe 13, debug probe 26); main run 39193598683 on eeed7d2 (six jobs green). Independent review: APPROVED, 10 non-blocking points (see the follow-up job `2026-10-19-probe-real-art-compat-report.md` and the chief report).

## Work completed
- New `scripts/camera/camera_preset.gd` (`CameraPreset`, pure statics plus one active-preset slot). Table: `wide` = 1/SCALE (0.4444), `close` = computed. `DEFAULT_ID = "wide"`: default behaviour is unchanged.
- Formula: close zoom = 0.175 x 720 / figure px. Snap: if zoom 1.0 puts the figure in 16-19 % (figure 115.2..136.8 px) use exactly 1.0. Result clamped to 0.25..4. Figure px = loaded sprite set `body_height_px`, else `WorldScale.BODY_HEIGHT` (108). For 108 px: zoom 1.1667, figure 126 px, 17.5 %, visible world 1097.1 x 617.1. A 120 px set gives exactly 1.0. All PROVISIONAL.
- Selection: `?camera=wide|close|<number>` parsed by one pure function (first key wins; number clamped; garbage, empty, zero, negative, exponent form -> wide). Read in `WebBridge._ready` (web only). Lab key `N` cycles presets (action registered at runtime because project.godot is not an allowed file).
- Everything that used the old constant goes through the preset: player camera zoom, lab zoom list (`[baseline,1,2,3,4]`, deduped if baseline is 1.0; label "wide 0.44x" / "close 1.17x"), restore on close, captions, `camera_framing`. The player follows sprite-set loading (`camera_baseline_changed` signal), so real art is picked up with no restart.
- `__SHINOBI_STATE__` gains `camera_preset` (`wide`, `close`, `custom`); existing fields unchanged.
- Docs: handoff section "Camera preset", TESTING.md checklist line.

## Files changed
`scripts/camera/camera_preset.gd` (+.uid), `scripts/player/player_controller.gd`, `scripts/ui/animation_lab.gd`, `scripts/web/web_bridge.gd`, `scripts/world_scale.gd` (comment), `tests/test_camera_preset.gd` (+.uid), `tests/run_tests.gd` (one include line; `test_camera_framing` reads the preset table), `scripts/ci/smoke/controls-probe.mjs`, `docs/development/GODOT_PROJECT_HANDOFF.md`, `docs/prototype/TESTING.md`, this report and the order file. No screenshots, no docs/visuals, no GDD.

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| godot_ci import, validate-resources | exit 0; scripts=28 scenes=5 failures=0 (VERIFIED) | camera2\evidence\logs-final |
| godot_ci tests (in-engine) | SUMMARY: 492 passed, 0 failed (main had 419, +73) (VERIFIED) | camera2\evidence\logs-final |
| validate_godot_project.py; node --check controls-probe.mjs | PASS 0/0; exit 0 (VERIFIED) | local |
| Red proof 1: default flipped to close (temporary) | 467 passed, 25 failed incl. "DEFAULT_ID is wide", "default preset is wide and the camera zoom equals the wide preset", "lab shows wide 0.44x"; restored (VERIFIED) | logs-mut1 |
| Red proof 2: parser accepts garbage (temporary) | 489 passed, 3 failed (garbage / no-value / repeated-key); restored, 0 mutation markers, 492/0 again (VERIFIED) | logs-mut2 |
| Local Web export (SHA 17bfa53, import/export/finalize/check exit 0) | OK (VERIFIED) | camera2\evidence\verify |
| (a) default, no parameter | wide, 0.4444, 2880x1620 | PASS |
| (b) `?camera=close` | close, 1.1667, 1097.1x617.1; standing figure 127 px = 17.6 % of 720 measured from the screenshot palette | PASS |
| (c) `?camera=garbage` / `?camera=2` | wide 0.4444 / custom 2.0000 (640x360) | PASS |
| (d) close, north wall / south wall (real keys) | head visible (top row 34), caption visible, no void / feet and shadow visible (feet row ~693), no void; images opened | PASS |
| (e) lab at close | Tab keeps baseline; Z walks 1,2,3,4,base,1; Tab restores; N switches | PASS |
| Console errors during the run | 0 | PASS |
| Controls probe (local, changed) | VERDICT PASS | camera2\evidence\probe.log |

Notes: sprint-pose figures measure 126 px (north) and 108 px (south) because stride changes leg spread; the standing figure is the spawn number. Opened images: spawn-close, north wall, south wall, spawn-wide (the wide-vs-close pair).

## Issues encountered
- The lab key `N` is not listed in the debug HUD legend (debug_hud.gd is not an allowed file); the lab panel and help show it.
- Numeric `?camera=` accepts only positive plain decimals; exponent form falls back to wide (deliberate).
- Captions >= 8 screen px at close rely on the `caption_font_size` formula (ASSUMED, not measured in the browser).
- The optional occlusion replay at B3 east with `?camera=close` was not run (sort keys do not depend on zoom: ASSUMED).

## Live verification (added after the merge, by the orchestrator, 2026-10-19)
Live URL https://kiotdstudios.github.io/shinobi-rush/ , real browser run (headless Chromium, software GL, 1280x720) after the deploy of eeed7d2, repeated on the current deploy c172f6e (which differs from eeed7d2 only by the `reference/` folder; `build-info.json` `commit_sha` equals the merge commit in both checks). VERIFIED:

| Query | Result on the live build |
| --- | --- |
| none (default) | `camera_preset` wide, zoom 0.4444, view 2880x1620, standing figure 48 px (6.7 %) |
| `?camera=close` | close, zoom 1.1667, view 1097.1x617.1, standing figure 127 px = 17.6 % of 720 (palette measurement on the screenshot) |
| `?camera=bogus` | wide, 0.4444, 2880x1620 |
| `?camera=2` | custom, zoom 2.0000, view 640x360, figure 218 px |
| console | 0 errors |

Opened by the orchestrator: the live close screenshot and a side-by-side of it with the owner's reference. Post-deploy smoke on the real URL: green in both main runs (39193598683, 39194231558). Evidence on the build laptop: `c:\tmp\shinobi-order01\camera2\evidence\live\` (eeed7d2) and `...\live-c172f6e\` (state numbers only).

Not covered by that replay: head/feet at the walls and the lab keys at close (covered by the local export in the table above).

### Live with the first real art (added 2026-10-19, build d9ebccf, Codex's PR #23)
`build-info.json` `commit_sha` d9ebccfbc77400424fcd1e1558e2daeaaa612d7a, run 39223465511 (six jobs green incl. post-deploy smoke; 493 tests, controls probe 16, debug probe 26). Set `player_128`, `body_height_px` 104. VERIFIED by the orchestrator, 0 console errors:

| Query | zoom | view | standing figure (measured on the screenshot) |
| --- | --- | --- | --- |
| none | 0.4444 | 2880x1620 | 46 px = 6.4 % |
| `?camera=close` | 1.2115 | 1056.5x594.3 | 127 px = 17.6 % |
| `?camera=1.2` | 1.2000 | 1066.7x600 | 122 px = 16.9 % |
| `?camera=1.25` | 1.2500 | 1024x576 | 131 px = 18.2 % |

At close zoom with real keys: the north wall shows the whole head (about 38 px of ground above the hair), the south wall shows the feet (about 23 px of ground below); at the east and west walls the figure ends at the screen edge, partly cut off (camera limits stop at the arena edge). The snap-to-1.0 rule cannot fire for the standard 100-112 px body, so `close` is always a non-integer zoom with this art (chief report, question 4).

## Not verified
Real GPU frame rate; controllers; real Codex 128x128 art when this report was written (only the 108 px placeholder was measured; the manifest path is unit-tested; the first real set, `body_height_px` 104, arrived in Codex's PR #23 five hours after the merge and gives close zoom 1.2115); the owner's reference image (it is now in the repo, PR #22); browsers other than the software-GL Chromium. The live deployed build is verified, see above.

Known weakness found afterwards: the controls-probe expectation `CLOSE_ZOOM = (0.175 x 720) / 108` was pinned to the placeholder (review point 3), and the probe assumed the lab starts closed, which was false once any sprite set existed (the lab opened by itself). Both turned Codex's PR #23 red. Codex fixed them inside PR #23 (merged as d9ebccf; the probe now derives the close zoom from the loaded figure height, and the lab now starts closed), see the chief report `2026-10-19-chief-camera-preset.md`. Review points 4 to 7 and 10 are still open.

## Questions for project owner
1. Is the close target of 17.5 % of viewport height (zoom about 1.17 for the placeholder) the right middle of the 16-19 % band, and may it become the default after you have compared it in the browser? Recommendation: try `?camera=close` first, then decide; the default stays wide until you say so.
2. Should the lab key N appear in the debug HUD legend? Needs a one-line change in a file outside this job's scope.

## Outstanding work / next steps
- Independent review, required CI green, orchestrator merge and live check.
- Deliverable 2: the validation scene (next workflow).
- Orcha's director must layer relative offsets on `CameraPreset` (see the handoff section).
