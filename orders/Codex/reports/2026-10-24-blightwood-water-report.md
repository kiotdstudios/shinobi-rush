# Job Report - Blightwood flowing river and small waterfall
- Agent: Codex
- Order: orders/Codex/2026-10-24-blightwood-water.md
- Date: 2026-10-24
- Final status: REVIEW - validated and submitted; canonical deployment pending.
- Commit / PR: initial implementation3337643981dbec5d76c66c88b8f29e171aa6b309; upstream integration2b892cf764ec1c84aae6e9fa8a7c80967b6f9cea; https://github.com/kiotdstudios/shinobi-rush/pull/162. Report was written before the implementation commit.

## Work completed
Three original PixelLab Pro sources reproduce only water from the owner's reference: detailed blue river surface, narrow small waterfall and separate foamy landing. Three 16-frame animation jobs supply48 distinct native frames. Existing72x36 grid supports nine edge/corner/center river masks. The native128x192 cascade uses a fixed64,169anchor. The surface128x128, cascade128x192 and foam128x64 sources export as separate4x4atlases at 16/18/13 FPS. Eighteen bounded droplets add independent spray, extracted from authored water highlights. No scenery, plants, stones or banks baked in.

BlightwoodWater renders floor tiles with shared world coordinates and synchronized clock, preventing separate diamond phase/UV seams. Integer sampling, nearest textures, native-scale handling and no interpolated animation. The waterfall and foam have independent clocks and a separate spray toggle. The original cascade apron is cropped out so separate foam owns the landing.

Builder River water category has nine paintable/movable/deletable floor cards and a small waterfall. Existing persistence, filtering and scroll-without-zoom behavior retained. Filter grid uses three columns so Save remains accessible with this additional category. This pass is decorative: no swimming, navigation/collision rules or automatic map repaint. No gameplay/combat/camera code changes. Opt-in water=review scene offers normal/half/pause/step/spray controls and read-only browser state.

## Files changed
New assets/environment/blightwood_water (sources, atlases, tile masks, metadata/imports); scripts/environment/blightwood_water.gd; shaders/blightwood_water.gdshader; review scene/script; own browser/native probes and docs/previews. Shared editor files only register the art, thumbnails and read-only telemetry; art proof gate adds opt-in review; test runner registers own checks. Unrelated untracked ancient shrine report preserved and excluded.

## Tests performed BEFORE commit
- Python docs/visuals/blightwood-water/export_pack.py: PASS48 unique frames, dimensions, alpha cleanup,9 masks, exact first/last surface edge equality and no dark border, native atlases/contact sheets/metadata.
- Godot4.7.2 via scripts/ci/godot_ci.py import --project . --log-dir build/blightwood-water-import: PASS. Final corrected assets reimported with build/blightwood-water-final-import: PASS.
- Full native suite via scripts/ci/godot_ci.py tests --project . --log-dir build/blightwood-water-tests:2376PASS,0FAIL. Includes water renderer/layers, fixed root, bounded long playback, nonblocking placement, brush replacement, category visibility, move/delete/freeing. Only expected malformed-sheet fixture warning.
- Fresh full-game Web export via export --project . --out ../blightwood-water-final-web-20261024 --log-dir build/blightwood-water-final-export: PASS.
- Real browser builder and review checks are being finalized; exact results recorded below before commit.

## Issues encountered
First actual Web inspection exposed a one-pixel dark border in the generated full-bleed surface, repeating as square lines. Replaced only that unwanted border with adjacent native pixels, repaired toroidal edges and added edge/color assertions. Corrected edge/corner mask direction mapping before final export. Source screenshots and jobs retained. No source pixels rescaled. Waterfall original landing apron removed to avoid double foam. No known code failure.

## Questions for project owner
None required; visual approval is not claimed.

## Outstanding work / next steps
Finalize corrected browser render and previews, required PR/CI and canonical live integration/verification. Water remains NOT LIVE until verified main deployment. Banks, rocks, lilies and flowers remain outside this owner-requested water-only batch.

## Final pre-commit result
Corrected actual Web render visually inspected: no dark square grid, clear continuous surface across the assembled river, separate rooted cascade/foam/spray. Repeated node scripts/ci/smoke/builder-water-probe.mjs --serve-dir ../blightwood-water-final-web-20261024 --out-dir build/blightwood-water-builder-final: all 12checks PASS,0errors. node docs/visuals/blightwood-water/browser-proof.mjs ../blightwood-water-final-web-20261024 build/blightwood-water-review-browser: all 10boolean checks PASS plus192 actual frames. Normal/half/pause/frame-step and independent foam/spray verified. Corrected final asset set is what the browser tested. Preview GIF packaging and timing verified below; production art stays native. Shared editor panels inspected: all filters and Save accessible. Source border regression is fixed, not waived.
Preview packaging verified: normal192 frames/8000ms, half-speed192 frames/16000ms, each about5.61MB. No duplicated padding added. Order and whitespace checks pass. Shared main advanced to56da29a (Aki's fence sorting and bandit combo/substitution); it will be merged and affected tests rerun before integration. Those systems remain owned by Aki.

## Shared-main integration validation
Merged origin/main56da29a without conflicts, preserving Aki's bandit combo/substitution and fence/shrine sorting. Godot import PASS (build/blightwood-water-integrated-import). Full native suite2393 PASS,0 FAIL (build/blightwood-water-integrated-tests/tests-builtin.log). Fresh Web export PASS (../blightwood-water-integrated-web-20261024). Repeated actual browser builder probe all12 checks PASS,0 errors (build/blightwood-water-integrated-browser); refreshed screenshot/JSON copied to docs. No water art/review changes from that merge. Untracked generated tools/shot_fence_shrine.gd.uid belongs to incoming tooling and is excluded alongside the unrelated ancient-shrine report.
Upstream's unchanged BANDIT_L1_STATS.pdf is text-encoded PDF and triggers Git whitespace warnings in its xref records. Verified staged PDF exactly matches origin/main; did not alter PDF bytes. Whitespace check against origin/main (the actual PR diff) PASS.

Environment: Windows, Godot4.7.2 GL Compatibility, Chromium Playwright1280x720, Python/Pillow/NumPy native artifact processing. Required PR checks running; no live-delivery claim yet.
