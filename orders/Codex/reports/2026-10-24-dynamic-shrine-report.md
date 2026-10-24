# Job Report — Dynamic Blightwood shrine
- Agent: Codex
- Order: orders/Codex/2026-10-24-dynamic-shrine.md
- Date: 2026-10-24
- Final status: DONE � runtime committed, integrated, deployed and publicly verified; owner visual approval not claimed.
- Commit / PR: runtime merge205b2bbc15033c6c04449d1ea57ecff3486e3af7 / https://github.com/kiotdstudios/shinobi-rush/pull/181. Initial report written before implementation commit.

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

## Latest-main integration — before publishing integrated branch
Main f6a303b40ebce755d539f3028a2748c7267b8c54 (Aki's PR180 starting courtyard) was merged normally as83c6ca84fe216893b805924c2a4c21769f63ffba. Incoming courtyard code/tests kept intact. The merge commit was created by git merge before integration checks; no untested merged branch was pushed. Then executed focused native starting-area+shrine harness:21PASS0FAIL/no errors (build/shrine-integration.log). Fresh debug Web export to ../dynamic-shrine-integrated-web-20261024 passed. Re-ran all17review checks and11builder checks on the integrated build, all PASS/no console errors; integrated-browser/builder-validation.json stored in docs.

Builder probe now starts outside the authored courtyard, which the existing map system reconstructs on reload. That existing behavior can clear custom props placed inside its reserved footprint; this art task does not change Aki's layout ownership. Both new shrine source/art and review rendering are unchanged by integration. The successful final native full suite remains2504on the pre-integration branch; exact integrated full suite is delegated to required fresh PR CI, not falsely claimed rerun locally.

## Merged main native/resource CI evidence
Runtime PR181 merged as205b2bbc15033c6c04449d1ea57ecff3486e3af7 after required PR run40139018771 and Repository checks40139018809/Pipeline self-test40139018813 passed. Main run40140152663 import/test/export job121010057073 completed success. Its decoded logs were fetched through the connected GitHub tool:336scripts and21scenes validated with0failures; full native summary2512passed,0failed. Public deployment verification is still pending at this entry; no local result is substituted for it.

## Canonical public verification — 2026-10-24
Public site build-info.json reports205b2bbc15033c6c04449d1ea57ecff3486e3af7, exactly the PR181 merge. This is the deployed runtime actually tested.

- https://kiotdstudios.github.io/shinobi-rush/?shrine=review —17checks PASS/no page or console errors;23:08:46.563UTC. Invoked node docs/visuals/dynamic-shrine/browser-proof.mjs with canonical base URL, build/shrine-live-review and --no-capture. Verified three swarms, progressing animation, fixed stone, normal/half speeds, pause/step and all four layer toggles.
- Canonical game ?editor=1 —11checks PASS/no errors;23:09:24.987UTC. Invoked node scripts/ci/smoke/builder-shrine-probe.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --out-dir build/shrine-live-builder. Verified independent filter, accessible Save, scroll/no world zoom, placement, selection, movement, localStorage save, reload, visibility and deletion outside the existing authored courtyard.
- Inspected actual public screenshots with view_image: reference-matched arches, stairs, blue flowers and orange emblem are complete and consistent with the live scene. Dynamic shrine / Ancient Flame Shrine builder card works. All42insects remain in three independently seeded groups; animation runs continuously without moving the stone root.
- Exact SHA/time/URLs/checks and screenshots: docs/visuals/dynamic-shrine/live-review-validation.json, live-builder-validation.json, live-review.png, live-builder.png.
- Normal/half-speed GIFs remain the same tested288actual Web captures, available on main. Owner visual approval is not claimed.


## Final pipeline result / remaining work
https://github.com/kiotdstudios/shinobi-rush/actions/runs/40140152663 completed SUCCESS, including import/validation/native tests/export, predeploy browser checks, Pages publishing, postdeploy live smoke and godot-ci-gate. Own public28checks also passed on exact runtime205b2bb. No outstanding shrine runtime work. The new shrine is a separate optional builder landmark; replacing/rearranging the existing authored courtyard or adding interaction/collision was outside this art order. Owner visual review remains separate.

This final evidence/report branch also closes the previous shoreline report and corrects its overly broad whole-map-count assertion after a successful14check public rerun. Live deployment: not applicable to this follow-up commit (reports/screenshots and browser-test assertion only; no runtime asset/script change). The actual runtime delivery above is already live and verified. validate_orders.py and git diff --check passed before this report commit. Required CI for the report PR follows the normal workflow; no bypass used.
