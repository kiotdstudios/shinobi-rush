# Job Report — Blightwood modular bridge kit
- Agent: Codex
- Order: orders/Codex/2026-10-25-blightwood-bridge-kit.md
- Date: 2026-10-25
- Final status: REVIEW — tested art kit ready; NOT LIVE awaiting gameplay integration
- Commit / PR: Implementation commit pending at report creation; follow-up below.

## Work completed
Created the requested Blightwood modular bridge kit: three lengths (4/6/8 logical tiles), two-tile fixed width, both diagonal axes, start/end caps, support posts, timber rails, optional rope rails, and damaged versions. Delivered 13 reusable modules, 18 assembled examples and 72 separate support/rear/deck/front bitmap layers. Added 72x36 grid basis, exact sockets/anchors, dimensions, sampled palette and SHA-256 metadata.

Built-in image_gen produced all raw creative pixels. PixelLab API instructions and configured service were reviewed; get_balance succeeded (209.80 generations remaining); no PixelLab generation was used. Deterministic processing mapped colors to a 36-color palette sampled from existing wooden-post and grass art, projected textures with nearest sampling, aligned rails and mirrored axes. Raw source, cleaned source, generation prompts and processor QC are preserved. No character, gameplay controller, builder, navigation, camera, world map or movement file was edited.

## Files changed
- assets/environment/blightwood_bridges/: raw sources, 103 transparent deliverable PNGs, import sidecars, bridges.art.json. Sources excluded from runtime import with .gdignore.
- docs/visuals/blightwood-bridges/: build/check scripts, asset-qc.json, full prompt set, contact-sheet.png, native godot-render.png, integration instructions.
- tools/shot_blightwood_bridges.gd and its UID: isolated dev render/import verification.
- Own order and this report.

## Tests run BEFORE implementation commit
Environment: Windows PowerShell; Godot 4.7.2 stable GL Compatibility on NVIDIA RTX 3080; bundled Python with Pillow/NumPy. Working checkout .tools/dynamic-shrine, base 7c40239be85d8439190123a6c9b9ec6e3c98b39d.

| Command / manual steps | Result | Evidence |
| --- | --- | --- |
| python C:/Users/dielp/.codex/skills/generate2dsprite/scripts/generate2dsprite.py process --input assets/environment/blightwood_bridges/source/deck-raw.png --target asset --mode single --output-dir assets/environment/blightwood_bridges/source/processor-qc --rows 2 --cols 1 --cell-size 1024 --align center --component-mode all --fit-scale 0.92 --reject-edge-touch | PASS | source/processor-qc outputs |
| python docs/visuals/blightwood-bridges/build_kit.py | PASS; 13 modules, 18 assemblies, 72 layers | bridges.art.json, contact sheet |
| python docs/visuals/blightwood-bridges/check_kit.py | PASS; 584 checks, 0 failures across 103 files; RGBA, binary alpha, no missing/empty images, sampled palette membership, hashes, socket geometry, mirrored alignment, fixed width, unclipped assembly bounds and damage holes | docs/visuals/blightwood-bridges/asset-qc.json |
| python scripts/ci/godot_ci.py import --project . --godot <Godot_v4.7.2-stable_win64_console.exe> --log-dir build/bridge-kit-import | PASS; import sidecars generated and included | build/bridge-kit-import.log |
| python scripts/ci/godot_ci.py validate-resources --project . --godot <Godot_v4.7.2-stable_win64_console.exe> --log-dir build/bridge-kit-validate | PASS; 357 scripts, 24 scenes, 0 failures | build/bridge-kit-validate.log |
| Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/shot_blightwood_bridges.gd | PASS; all 103 textures loaded, screenshot save_error=0, no script/runtime errors | build/bridge-kit-render.log; docs/visuals/blightwood-bridges/godot-render.png |
| Viewed contact sheet and native Godot screenshot | PASS; coherent material scale across three lengths, visible damaged gaps, matching cool moss/wood against actual game water, both axes visible | contact-sheet.png and godot-render.png |
| python scripts/ci/validate_orders.py; git diff --check | PASS | command output |

No gameplay code changed; full combat tests, Web export and browser traversal tests were not run for this art-only handoff. No live bridge route, builder control or traversable bridge is claimed. The native preview tool is independent of the main scene.

## Issues encountered
- The first generated accessory atlas placed its unused rope near the bottom edge; regenerated the rope separately with safe margins.
- A detached neighboring rope fragment was present in the timber-rail crop; removed by largest-component extraction before projection.
- Initial native screenshot inherited window stretching and cropped presentation edges; corrected the tool to render into a fixed 1440x1000 SubViewport and verified the replacement screenshot.
- Import generated an unrelated tools/shot_shrine_climb.gd.uid; preserved under ignored build/preserved-shot_shrine_climb.gd.uid, excluded from this commit.
- Damaged alpha gaps are cosmetic; walkability/elevation, water masks, rail collision and actor occlusion must be implemented by gameplay owner before playable use. Mirrored v-axis uses the same material art; no independent re-lighting pass.

## Questions for project owner
None.

## Outstanding work / next steps
Review art PR. Aki owns map/builder placement, traversable deck/entry elevation, collision/navigation and dynamic actor layering. Use separate layers rather than the flattened preview for final gameplay integration. Follow normal main CI/deploy and canonical public verification when integrating runtime behavior.

Live deployment: not applicable to this art-only PR; **NOT LIVE — awaiting gameplay integration**. Existing canonical game is unchanged by these assets.
