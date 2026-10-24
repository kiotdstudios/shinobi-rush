# Job Report — Dynamic Blightwood shrine
- Agent: Codex
- Order: orders/Codex/2026-10-24-dynamic-shrine.md
- Date: 2026-10-24
- Final status: REVIEW — local acceptance passed; required PR CI/integration/public deployment outstanding. Owner visual approval not yet received.
- Commit / PR: Not committed yet; this report is written before implementation commit.

## Work completed
PixelLab reference-matched broken-arch shrine with central red-orange flame monolith, front stairs, dark blue-gray stone, sage foliage and pale blue hanging flowers. Native512x448 source is padded16pixels to544x480 without resampling. Four hanging foliage bands are split by palette and exterior region; rest-pose reconstruction is pixel-exact to padded source.1869authored emissive pixels get a gentle12second pulse. Separate halo, four rooted8second foliage bends, three independently seeded14-insect groups (42total), independent blue-white god rays. Existing PixelLab Blightwood firefly art reused; runtime animation/shaders are authored code, not generated-frame claims.

Separate optional Dynamic shrine / Ancient Flame Shrine builder landmark: paint/place, select, move, hide, delete and save/load. Existing shelter and default layout preserved; no gameplay/controller/camera changes. Decorative nonblocking asset, no shrine interaction added. Dedicated ?shrine=review and normal/half/pause/step/layer controls.288actual Godot Web captures packaged into normal12second and half-speed24second GIFs.

## Files changed
New assets/environment/blightwood_dynamic_shrine (RGBA layers, manifest, ignored source originals), scripts/environment/dynamic_shrine.gd and two shaders, art review scene/script, export/proof/preview tools and evidence under docs/visuals/dynamic-shrine, native regression cases. Minimal registration in placed_objects/world_editor, art gate and test runner. Unrelated generated tests/test_wall_colliders.gd.uid excluded.

## Tests performed BEFORE commit
Windows PowerShell; Godot4.7.2 pinned executable in .tools/godot-4.7.2; bundled Python/Node. Commands run from .tools/dynamic-shrine.

| Command / manual step | Actual result / evidence |
| --- | --- |
| python docs/visuals/dynamic-shrine/export_layers.py | PASS native RGBA, padded transparent border, exact pixel reconstruction, four populated foliage layers568/312/625/190pixels;1869emissive pixels; manifest source hash |
| Godot --headless --editor --import --path . --quit | PASS; build/shrine-import.log, no errors |
| python scripts/ci/godot_ci.py tests --project . --godot <pinned executable> --log-dir build/shrine-final-tests | PASS2504,0failed; no engine errors; only expected malformed-sheet fixture warning.13new meaningful shrine checks: seeded groups/count, layers, fixed geometry, pulse/moving insects/toggles, move/hide, serialization, delete |
| python scripts/ci/godot_ci.py export --project . --out ../dynamic-shrine-final-web-20261024 --godot <pinned executable> --log-dir build/shrine-final-export | PASS debug Web export; unknown local build SHA because GITHUB_SHA unset (not a public deployment claim) |
| node docs/visuals/dynamic-shrine/browser-proof.mjs ../dynamic-shrine-final-web-20261024 build/shrine-final-browser --no-capture | PASS17browser checks, no console/page errors; docs browser-validation.json |
| node scripts/ci/smoke/builder-shrine-probe.mjs --serve-dir ../dynamic-shrine-final-web-20261024 --out-dir build/shrine-builder-final | PASS11checks: filter, Save access, wheel/nozoom, place/select/move, saved/reload, hide/delete/noerrors |
| python docs/visuals/dynamic-shrine/make_previews.py | PASS288actual Godot frames;12000/24000ms; stable global palette/no dithering; preview-validation.json |
| Visual inspection with view_image | Inspected actual Web review and builder screenshots: complete padded base/arches, readable emblem, coherent Blightwood scale/palette, grouped insects and separate soft light; screenshots copied to docs |
| git diff --check | PASS |

## Issues encountered
Initial full suite returned2504assertion passes but engine-error scan correctly FAILED because new kind fell through to procedural block thumbnail and accessed missing height. Added the proper shrine icon branch, reran full suite and browser checks clean. Initial capture still renders identical shrine art and yielded288frames; final no-capture browser validation rechecked corrected boot without errors. First builder probe clicked inside the builder panel instead of map; corrected to actual visible map positions, then all11passed. No failed result is counted as passed. New isolated worktree avoids unrelated dirty original checkouts.

## Questions for project owner
None. Visual approval remains for the delivered reference recreation.

## Outstanding work / next steps
PR/required checks, normal protected merge, canonical Web deployment and exact public build/browser verification; update order/report with final SHA/links. Prior shoreline PR166 public review passed12checks; latest public builder probe had save_reload count mismatch after upstream map additions, final shoreline evidence/report remains separate outstanding work.
