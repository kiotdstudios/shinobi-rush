# Finish open PRs 238 / 244 / 245 / 247 / 251

- Agent: Codex, explicitly authorized by the owner to finish all five listed PRs, including their programming integration.
- Status: REVIEW — local implementation and browser verification complete; remote checks and canonical delivery pending.
- Branch: `codex/finish-terrain-prs`, based on PR251, merging latest main `4c79fda602afb2352cc7b92d6b2a6c54b74c623b` without dropping either test suite.
- Dependency order: PR251 into PR245 first, then PR245 into main. The three specification branches are preserved as ancestors; their documents are archived with implementation/evidence references rather than passed off as code.

## Delivered / reviewed

PR238's two-tier CI is already implemented by PR239. Audited the current workflow, unchanged required checks, same-head fast/full success, three baseline runs and five recent routine deployments. Median wall time improved **30m04s → 13m40s** (54.5%); p90 30m48s → 15m45s. **The 7–10 minute aspiration is not met**; the implementation's required acceptance checks are met and the remaining performance goal is documented, without removing tests. See `docs/visuals/auto-blend/CI_AUDIT.md` and raw per-job/step `ci-benchmark.json`. Corrected stale documentation claiming the comprehensive controls probe still blocks routine deploys.

PR247's art is already delivered by PR248/252. Preserved all source art and authored maps. Registered manual terrain/junction categories correctly in the black editor's TILES tab through the existing category definitions.

Completed the PR251/245 integration: ten pair families with correct polarity; all 360 exact three-material corner signatures; shared vertex votes; stable variants; owned material painting; persistent locks and ownership; move/undo/redo; local retile and animated shorelines. Added the brown bank family for actual brown dirt, with the older olive/path bank remaining separate. Both new pure dirt/rock brushes remain valid with Auto Blend off.

Fixed issues found during review:

- Test compile error: inferred Variant for the moved object; typed it as Dictionary.
- Stale assertions that still required pair fallback when exact junctions now exist.
- Pure dirt/rock could pick nonexistent legacy nine-role filenames; retain native pure tiles instead.
- Manual deletion left orphan material ownership; Clear/undo lost ownership. Ownership changes are now recorded with the corresponding gesture; manual replacements stay pinned.
- The animation lab swallowed Ctrl+Z/Y as plain Z/Y actions before editor shortcuts. Modified keys now pass through; focused native lab regression and actual browser undo/redo pass.
- Move replay now uses its recorded ownership operations rather than mutating them again during replay.
- The two reported Player Sense “flakes” were a deterministic test leak: the terrain test set `MapEditorMode.forced=true` and never restored it, freezing the player in the next suite. Restored the previous mode; both previously failing tests now pass in the full run.

Added opt-in `?autoblend=review&editor=1`: twenty actual material-brush samples (ten pairs, ten triples), each 121 cells, live corner-vote audit, undo/redo/save-reload, player movement, real pointer painting and keyboard undo/redo. The black map editor is also exercised. Autosave is disabled; only an isolated in-memory layout is replaced. No authored layout is written.

## Files

Editor: `terrain_blend.gd`, `auto_tile.gd`, `placed_objects.gd`, `asset_browser.gd`, `world_editor.gd`; modifier handling in `animation_lab.gd`. Tests: `test_terrain_blend.gd` and runner. Preview: `auto_blend_review.gd`, gate hook, `auto-blend-probe.mjs`. Documentation: three original order files, terrain README, CI guide, benchmark and browser evidence. Original production textures, player/bandit/combat controllers, normal camera, map geometry and collision definitions are unchanged.

## Pre-commit verification

Godot 4.7.2, bundled Python and Node, Windows; actual exported Web build in Chromium/Playwright at 1280×720.

- `scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --log-dir build/finish-prs/import`: PASS.
- `... validate-resources ... --log-dir build/finish-prs/validate-final`: PASS, **438 scripts / 30 scenes / 2 resources, zero failures**.
- Focused terrain suite: 83/0 before adding full signature/shore coverage.
- First full native run: 5068/2; exposed the real map-mode test leak described above. Not accepted as a flaky pass.
- Final `... tests ... --log-dir build/finish-prs/tests-final`: **5,072 passed / zero failed**, including all ten pair/mask polarities, all 360 junction signatures, ownership persistence and replay, brown/rock banks with blending on/off, and both Player Sense checks. Expected intentional malformed SpriteSet fixture warning only.
- Final `... export --out ../finish-prs-web-pointer ... --log-dir build/finish-prs/export-pointer`: PASS, single-threaded Compatibility Web export.
- Browser probe: **27/27 PASS**, `docs/visuals/auto-blend/gameplay/result.json`; all twenty real brush layouts have zero missing/contradictory corners, save/load and undo/redo preserve exact owners, real movement/pointer/keyboard and black-editor painting pass with zero engine/browser errors. Visually inspected the screenshots. Initial review-checker issue used `ground_at` for grass and miscounted valid grass tiles as missing; corrected to count all floor kinds. Actual corner conflicts were zero. Pointer test initially targeted the builder panel, where input was correctly blocked; moved the test into the free canvas. These were preview/test issues, not reasons to weaken production UI input handling.
- Focused lab suite after shortcut fix: **18/0**, including the new Ctrl+Z regression and existing plain-key/button behavior. The 5,072-test full run precedes this isolated modifier fix; required remote full suite will include the added regression.
- Orders validator, sprite manifest validator (1 manifest / 0 errors), staged and working whitespace checks: PASS.

## Limits / questions / integration

All ten three-material combinations are supported. **Four distinct materials within one diamond have no authored kit and use deterministic pair fallback; that case is not claimed seam-free.** Cliff/stair/waterfall geometry and explicit variation reroll are separate follow-ups. CI's 7–10 minute goal remains a measured performance follow-up.

Questions: None. Access blockers: None. No protections, required checks, permissions or deployment gates changed or bypassed.

Implementation commit / updated PR heads / CI / live SHA: pending tested push and normal reviewed integration.
