# Job Report — Player disappearing beneath arena wall (wall occlusion)
- Agent: Kiro
- Order: [orders/Kiro/2026-10-18-deferred-wall-occlusion-investigation.md](../2026-10-18-deferred-wall-occlusion-investigation.md)
- Date: 2026-10-18
- Final status: DONE (set by the orchestrator on 2026-10-18 after the merge and the live verification, see "Live verification" at the end). Status when the workflow wrote this report: REVIEW.
- Commit / PR: branch `kiro/wall-occlusion`; fix commit `d028790` (parent `3d25e98`), merge of `origin/main` `5970c30` as `026fa6d`; PR [#17](https://github.com/kiotdstudios/shinobi-rush/pull/17), head `f248cee` at opening.

## Work completed
Diagnosis (VERIFIED by execution, headless Chromium + SwiftShader, Godot 4.7.2 Web export, 216 cells in the reproduction matrix, 56 flagged):
- Defect, a draw-order bug (H1) made worse by a collider narrower than the drawn base (H2). Every flagged east-side cell had player.y < block.y. Each block was ONE y-sort item keyed at its front edge, drawing front face, east face and roof together, so a player standing east of the block was drawn behind the east face and roof, although those faces are nearer the viewer than he is.
- The flip sits exactly at feet y == block y (sub-pixel sweep, 5 blocks, both zooms). The engine order from the sort inputs predicts the render in 126 of 126 cells that have a pixel overlap.
- Reproduced on the live site (commit `6f49e23`) with real keys: B1 and B3 east, 0 to 36% of the figure visible.

Hypotheses:
- H1 sort order: CONFIRMED, the defect.
- H2 collider vs drawn footprint: CONFIRMED as contributing; not a penetration (0 penetrations in 60 held-key browser runs and 400 headless runs, 48,000 physics frames).
- H3 intended occlusion: CONFIRMED for north and NE positions only (geometry-correct, 12 of the 56 flags); rejected for the east side.
- H4 camera: REJECTED (the north-wall clipping is a framing effect, not part of any cell).
- H5 feet / visual offset: REJECTED (shadow centre equals the sort origin to 0.0 px).

Fix (draw order only): each block is split into two y-sorted siblings under the already y-sorted arena.
- `Block` (StaticBody2D, key = block y): front face and caption. Collider unchanged.
- `BlockRear` (Node2D, key = block y - depth, no collider): east face and roof, same pixels as before.
- Rule (`ArenaSort`): the player is drawn over the east face and roof when feet.y > block.y - depth, and over the front face when feet.y > block.y. North and NE stay hidden as before. The player is never drawn over all walls.
- Rejected alternative (reviewer note, recorded here because it was only in the working notes): sorting the player in front of the whole block whenever he is east of the collider. It would draw him over the roof and east face at the north-east corner, where he is genuinely behind the box.
- Not touched: collision, camera, scale, foot anchor, state names, BLOCKS data.

## Files changed
- `scripts/arena/arena_sort.gd` (+.uid): pure rule helper (new).
- `scripts/arena/training_arena.gd`: Block draws front face and caption; new `BlockRear` class; `_ready` places the pair (+31/-6).
- `tests/test_arena_sorting.gd` (+.uid): new tests; `tests/run_tests.gd`: one added line.
- `docs/development/GODOT_PROJECT_HANDOFF.md`: short "Props with several faces: depth sorting" subsection.
- `orders/Kiro/2026-10-18-deferred-wall-occlusion-investigation.md`: Status REVIEW and log line. This report.
- The gated `?testhooks=1` teleport used for local evidence is NOT in the PR (chief directive 0A.4).

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import`, `validate-resources`, `validate_godot_project.py` on the fix commit | exit 0; 23 scripts, 4 scenes, 0 failures; PASS | VERIFIED, evidence dir `logs-fix` (local, not committed) |
| `godot_ci.py tests` on `d028790` | 375 passed, 0 failed (main had 270; +105 new) | VERIFIED |
| `godot_ci.py tests` on the merge `026fa6d` (includes Aki's telemetry from main) | 419 passed, 0 failed | VERIFIED |
| Red run 1: old `training_arena.gd` from main with the new tests | 299 passed, 6 failed (5 per-block "east face and roof have their own sort key" + "every block has a Block and a BlockRear piece") | VERIFIED |
| Red run 2: mutation, rear piece placed at the front edge | 355 passed, 20 failed (real draw order at the E positions); mutation removed | VERIFIED |
| Before/after Web export (fix + local hook), existing capture scripts on flagged and control cells only | 54 cells, drift 0.000, 0 console errors | VERIFIED locally |

Before/after numbers (O5-LEAN, build `d028790` + hook):
- 20 of 20 previously flagged east cells that were RE-RUN are fixed (the lean verification re-ran 16 positions at 1x and B1/B3 at the wide camera). At 1x: E-touch x5, Ea x5, Eb x5 and B1-E-step, all 100% visible with the player on top (before 0 to 85%; four of the Ea cells were 0%). At the wide camera: B1/B3 E-touch 94/93%, Eb 94/92% (before 6 to 41%).
- 6 NE cells unchanged (0, 0, 20, 0, 0, 59%), geometry-correct.
- 25 control cells at 1x (N, S, SE, Ec, Ed on 5 blocks) unchanged; N still covered. Ec at the wide camera, B1/B3, unchanged (94/95%).
- Opened by me: B1-E-touch 1x before/after, B3-E-touch wide before/after, B1-Eb wide after, B1-Ec wide after, B1-NE 1x after, B1-N 1x after. Everything else is numbers only.

## Issues encountered
- Residual (documented, geometry-correct): the feet can still stand inside the drawn base on the back half of the east side, and the figure vanishes when its feet cross y = block.y - depth there, as NE does. Optional follow-up, not done: add the east wedge as a second collision shape.
- A 128x128 sprite wider than about 25 px each side of its anchor could be clipped by a few px by the front face at the east contact.
- Risk: both pieces must stay siblings in the same y-sort group with the same z_index; documented in the handoff.
- Not re-run in the lean verification (low risk, the sort keys do not depend on zoom): 12 flagged wide-camera cells (B0, B2, B4 east cells, B1/B3 Ea, B1 E-step) and the 12 flagged live-site cells. The live site was replayed after the merge (see "Live verification" at the end).
- No debug logs were captured: the evidence builds predate Aki's telemetry producer (merged later as PR #13/#16), and the order says not to block the investigation on telemetry.
- Review follow-ups, not done: the draw offset in `BlockRear._draw` and the node position are two separate numbers and only the position is tested (derive both from one helper or test the world-space vertices); the test models Godot's tie rule, which was measured on the engine only at the front edge (re-run the 4 px flip sweep at the back edge on engine upgrades).

## Questions for project owner
None for this PR. (Optional: do you want the east-wedge collider follow-up?)

## Outstanding work / next steps
- Independent review, then merge by the orchestrator; verify the live build (`build-info.json` commit equals the merge commit) and replay B1/B3 east on the live URL.
- Chief report is written by the orchestrator after the live check.

## Verified vs assumed
| Claim | Status |
| --- | --- |
| Root cause is draw order (H1) plus collider/base mismatch (H2) | VERIFIED (measurements above) |
| Fix removes the 20 east-side flags, controls unchanged | VERIFIED locally, headless Chromium + SwiftShader |
| Unit and scene tests, red runs | VERIFIED (counts above) |
| Same draw order on real GPU hardware | ASSUMED (Godot's canvas y-sort is renderer independent) |
| Other browsers, controllers | NOT verified |
| Live build shows the fix | NOT verified (not merged yet) |
| CI pixel probe | none by design (chief directive); CI runs smoke, controls and export checks |
| Test hook | not shipped; local evidence only |

## Commit / PR
Fix `d028790`, merge `026fa6d`; PR #17. Not merged.

## Live verification (added by the orchestrator after the merge; the sections above were written by the workflow)
- **Merge:** PR #17 approved by the independent reviewer (no blocking defects, 9 non-blocking points) and merged 2026-10-19T01:20:23Z as merge commit 2b462f24c2e272654c9f7f2496de65edca2acb29.
- **CI on the merge commit:** Godot CI run 39184906275, all six jobs success. Read from the job logs: in-engine tests `SUMMARY: 419 passed, 0 failed`; pre-deploy smoke 11 PASS, controls probe 10 PASS, debug probe 26 PASS; post-deploy smoke on the live URL 11 PASS; no FAIL lines.
- **Live build:** https://kiotdstudios.github.io/shinobi-rush/build-info.json reported `commit_sha` 2b462f24c2e272654c9f7f2496de65edca2acb29, run 39184906275, built 2026-10-19T01:20:55Z. `typeof window.__SHINOBI_TEST__` is `undefined` on the live build (the local test teleport is not shipped).
- **Real-key replay on the deployed build** (the original failure; same script as the pre-fix live run, 0 console errors, wide camera zoom 0.4444 / view 2880x1620 unchanged): the player walks to the east face of B3 and B1 and is stopped at the collider contact (x 619.08 and 727.08), so collision still works. Figure pixels counted against a full-visibility reference:

| Spot (live) | Before the fix (commit 6f49e23) | After the fix (commit 2b462f2) |
| --- | --- | --- |
| B1 east, touching, default wide camera | 0% | 94% |
| B1 east, touching, lab 1x | 0% | 96% |
| B3 east, touching, default wide camera | 36% | 94% |
| B3 east, touching, lab 1x | 36% | 96% |
| B1 and B3 east, one key tap away (wide / 1x; tap distances differ between runs, informational only) | 89-90% / 96% | 90-94% / 96% |

- **Opened by me:** B1 east touching at the default camera and B3 east touching at lab 1x (after the fix): the figure stands in front of the east face, fully drawn. The pre-fix pictures from the same spots were opened in the O1b step.
- **Not re-verified live:** north, north-east and south positions (CI controls probe passes, and the local lean verification showed them unchanged), real GPU frame rate, other browsers, controllers.
