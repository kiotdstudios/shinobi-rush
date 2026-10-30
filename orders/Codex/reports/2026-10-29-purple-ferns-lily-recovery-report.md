# Job Report — Purple ferns and lily recovery
- Agent: Codex
- Date: 2026-10-29 (America/New_York)
- Order: `orders/Codex/2026-10-29-purple-ferns-lily-recovery.md`
- Final status: DONE — integrated and verified on the canonical live build
- Commit / PR: Implementation `8b5e57a28759426f1b23b760fd152c58168d85b6`, [PR261](https://github.com/kiotdstudios/shinobi-rush/pull/261); merged as `5a689112e7ce8c14444cd83ec412348b2dc8cd07`. Initial report preceded the implementation commit.

## Work completed

Preserved the three approved fern silhouettes and native source/production pixels. Added editable `render_tint: #d27dff` metadata, applied through native Godot modulation consistently in game, editor icons, placement ghosts and copied stamps. Vines remain untinted. This is a native code/configuration color variant, not new or edited bitmap art; no image generator/API charge was used. Updated GPU-rendered normal/half previews preserve all 96 phases, root alignment and timing.

Added one bounded cosmetic contact impulse for lily/lotus crossings: horizontal drift, downward dip and slight tilt, followed by individually paced exponential recovery. Stable rates vary from2.6–5.4/s using existing variant/phase; no per-frame randomness. Ground anchors stay fixed and actual water elevation controls draw position/depth. Recovery continues after stopping or exiting water and snaps to zero. Player/chakra/combat/camera rules, water collision, production population and frog rarity stay intact. Six deterministic inspection plants in the isolated real-player water test make the feature reproducible without changing production spawn rules.

## Files changed

- Foliage manifest/builder and `blightwood_foliage.gd`: native tint configuration and application; raw/production PNGs unchanged.
- `scripts/editor/world_editor.gd`: matching icon/ghost/stamp tint.
- `scripts/environment/waterlife.gd`: swept contact, one impulse per entry, bounded dip/tilt/drift, variable delta-correct recovery, surface-tier anchoring.
- `scripts/art/waterlife_play.gd`, `waterlife_review.gd`, `cliff_kit_review.gd`: inspection fixtures/read-only state; staged loop crosses plants.
- `tests/test_water_plant_recovery.gd`, existing foliage test and runner:17 recovery checks plus6 tint checks.
- `scripts/art/validate_foliage_render.py`: actual GPU tint/pin/motion verification.
- `docs/visuals/purple-lilies/`, foliage previews and waterlife integration docs: source choices, protocol and visual/browser evidence.

## Tests performed before commit

Windows PowerShell; bundled Python/Node; Godot4.7.2; Chromium Playwright; native GPU RTX3080 /OpenGL3.3. Dedicated branch `codex/purple-ferns-lily-recovery`, base `ef1898120b3f0c7d4ddf471a9cef171d04e90bbf` (previous report PR260 reviewed/merged first). Primary dirty character checkout and other worktrees preserved.

| Exact command / manual step | Result / evidence |
| --- | --- |
| `python scripts/art/build_blightwood_foliage.py` | PASS: six transparent native128 sources, original palette/source hashes and production PNG bytes preserved; six render_tint fields added |
| `godot --headless --path . --script ../cliff-kit-scratch/purple-lilies-focused.gd` | **91 PASS /0 fail**:57 foliage,17 waterlife/rarity,17 recovery checks; `build/purple-lilies/native.log`, durable native-result.json |
| `python scripts/ci/godot_ci.py import --project . --log-dir build/purple-lilies/import` | PASS; new owned sidecars retained, unrelated generated UIDs archived outside checkout |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/purple-lilies/resources` | **446 scripts /30 scenes /2 resources /0 failures** |
| `python scripts/ci/godot_ci.py export --project . --out ../purple-lilies-web --log-dir build/purple-lilies/export`; `finalize-export --project . --out ../purple-lilies-web --kind game`; `check-export --dir ../purple-lilies-web --kind game --project .` | PASS: fresh56MiB Web export; project.binary,1 sprite manifest,2,378 sprite PNG imports. Local build-info labels base main, not deployed uncommitted changes |
| `node docs/visuals/purple-lilies/browser-proof.mjs --serve-dir ../purple-lilies-web --out-dir docs/visuals/purple-lilies/gameplay` | **15 PASS /zero browser/engine errors**: actual editor/ghost/new purple plant plus real keyboard water-running,3+ disturbed plants, variable rates, normal costs, complete recovery while still wet and after real dry exit, repeated crossings/standing/no extra rarity rolls |
| `godot --path . --rendering-method gl_compatibility --resolution 768x160 --position=-3000,-3000 --script tools/capture_blightwood_foliage.gd`; `python scripts/art/validate_foliage_render.py` | PASS across96 actual GPU phases: all six visibly sway, pinned nonempty attachments, requested tint (<=1 framebuffer quantization value for tinted pixels, exact original palette for vines) |
| Visually inspected actual purple editor screenshot and rendered pose strip | PASS: all three cards and world ferns purple, ivy unchanged, sharp pixels/scale/anchors retained |
| `python scripts/ci/validate_orders.py`; `git diff --check` | PASS before commit; final evidence/links validated |

## Issues encountered

The recovery test initially assumed zero frog rolls despite a valid wet visit; corrected its expectation to the existing one roll, checking that reactions add none. GPU framebuffer tint multiplication rounds some channels by one value; validator records that bounded quantization rather than falsely rejecting correct purple pixels. No bitmap recoloring/generation was needed. No remaining known failures. Unrelated generated UID files are preserved separately.

## Questions for project owner
None.

## Outstanding work / next steps
None for this delivery. Completion evidence is a report-only follow-up; Live deployment: not applicable to that follow-up because it changes documentation/evidence only. Runtime PR261 is deployed and verified below.

Preview recording before commit: `node docs/visuals/purple-lilies/capture-preview.mjs ../purple-lilies-web build/purple-lilies/preview` passed with zero console/page errors. Actual Normal (5s) and Half (8.5s) segments were cropped with nearest-neighbor display scaling and exported as GIF/MP4. Screenshots visually inspected.


## Reviewed integration

All PR261 checks passed: **5,209 native assertions /0 failed**,446 scripts /30 scenes /2 resources /0 load failures, Web export, pre-deploy browser smoke, repository validation and final gate. No review threads remained. Normal squash merge used the exact expected head SHA; `git diff --exit-code HEAD origin/main` immediately after fetch confirmed identical tested/integrated content.

- [PR CI](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40936827950)
- [Durable PR check evidence](../../../docs/visuals/purple-lilies/pr-checks.json)
- [Main deployment workflow](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40939001761) — **success**, including deploy, post-deploy smoke and final gate.

## Exact canonical live verification

Verified at 2026-10-29T19:35:39.574Z against merged runtime `5a689112e7ce8c14444cd83ec412348b2dc8cd07`. Main repeated **5,209 native assertions /0 failures** and passed the full deployment pipeline.

Command: `node docs/visuals/purple-lilies/browser-proof.mjs --url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha 5a689112e7ce8c14444cd83ec412348b2dc8cd07 --out-dir build/purple-lilies/live`. **16 PASS /zero browser or engine errors**. Real editor clicks confirmed all existing/new ferns purple and vines unchanged. Real movement disturbed several pads at varied rates; they settled while still wet and after dry exit, with normal chakra cost, stable anchors, bounded repeated reactions and unchanged rarity/pool. Live editor and settled screenshots were visually inspected.

[Open editor](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&map_editor=1&foliage=1&v=5a689112) · [Live editor](../../../docs/visuals/purple-lilies/live/editor.png) · [Contact](../../../docs/visuals/purple-lilies/live/contact.png) · [Settled](../../../docs/visuals/purple-lilies/live/settled.png) · [Live results](../../../docs/visuals/purple-lilies/live/result.json) · [Deployment evidence](../../../docs/visuals/purple-lilies/deployment-checks.json).

Coordination: a separate owner-assigned Smart Terrain Brush task is working from this integrated SHA in another checkout. This follow-up changes only reports/evidence; no further terrain/editor implementation edits are being made here.

## Report integration refresh

After Smart Terrain Brush PR265 integrated as `4f84ff39c9bdae55b7c9c5ceaa99e24fbbf750d6` and its owner reported canonical verification, refreshed report PR264 onto that current main. No conflicts. The PR diff remains documentation/evidence only; runtime content is identical to current main. Re-ran orders validation, relative documentation links, evidence JSON parsing and whitespace checks before the merge commit. Earlier live results above identify the exact foliage revision tested; they are not relabeled as tests of the newer brush build. PR264 uses the normal required-check workflow.
