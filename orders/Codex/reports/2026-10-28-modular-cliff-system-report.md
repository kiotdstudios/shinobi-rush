# Job Report — Blightwood modular cliff system

- Agent: Codex
- Order: `orders/Aki/2026-10-26-blightwood-modular-cliff-kit.md`, explicitly reassigned by the owner in full.
- Date: 2026-10-28
- Final status: REVIEW — implementation and pre-commit acceptance checks pass; reviewed integration/live verification pending.
- Commit / PR: Not committed yet; tested delivery on `codex/modular-cliff-system`.
- Base: main `c829538a64d8f5c2dcfea1552bb948a6519fd078`. Refetched main; no new upstream commits during implementation.

## Work completed

Created a native, manifest-backed cliff kit using lossless cuts/assembly of the approved moss-capped masonry, stair, grass/path and water artwork. Nineteen module assets plus two original-art stair wrappers and a separate cascade form 22 searchable editor entries. Connected cells share surfaces and hide internal faces; exposed perimeter and stair sides provide real collision. Four inner and four outer directional variants, end caps, joins, raised stone/grass/path/river and a separate waterfall lip support reusable layouts.

Extended the existing elevation and navigation systems. Player and bandit traverse both stair directions; upper actors use the correct visual depth. Original stairs can connect to the full platform and revert to their old landing when the kit is removed. Original IDs/maps remain valid, with no schema migration. Module movement, erase, history, category visibility and save/load rebuild topology.

Measured the original 66-pixel rise against the approximately 150-pixel default cascade. Added a per-instance 16-frame native 56×96 cascade crop, diagonal lip/stone shoulders and lower foam connection. The old waterfall remains unchanged. Timing stays 18 FPS cascade / 13 FPS foam with 18 independent bounded droplets. Upper river tiles participate in existing water/chakra rules; foot VFX and plants receive the corresponding visual elevation.

The 670-object demo includes 134 elevated cells, long walls, convex/concave corners, both stair directions, upper river, waterfall and lower river. The opt-in demo runs in the actual arena/editor, saves separately from normal worlds, and Playtest opens the edited demo snapshot. Instructions and measurements: `docs/visuals/cliff-kit/README.md`.

## Files changed

- `assets/environment/blightwood/cliff_kit/`: native PNGs, import metadata, adjacency/anchor/source-hash manifest, exported demo.
- `scripts/art/build_cliff_kit.py`, `scripts/ci/validate_cliff_kit.py`: reproducible native assembly and pixel/geometry/source verification.
- `scripts/environment/cliff_kit.gd`, `cliff_world.gd`, `cliff_elevation.gd`, `shrine_elevation.gd`: rendering, shared topology, collision, existing elevation/nav integration.
- `scripts/editor/placed_objects.gd`, `world_editor.gd`: catalog, snapping, selection/drag and geometry lifecycle.
- `scripts/environment/blightwood_water.gd`, `waterlife.gd`, `waterlife_frog.gd`: instance-specific waterfall and upper-water presentation.
- `scripts/arena/training_arena.gd`: nav surfaces, stair axes and boundary integration.
- `scripts/art/cliff_kit_review.gd`, `kunai_proof_gate.gd`: opt-in real runtime/editor review and read-only probe state.
- `world/demos/blightwood-cliff-kit.json`, `docs/visuals/cliff-kit/`: demonstration and evidence.
- `tests/test_modular_cliffs.gd`, `tests/run_tests.gd`, `scripts/ci/smoke/cliff-kit-probe.mjs`: native and real-input browser coverage.

## Tests run before commit

Environment: Windows, Godot 4.7.2 stable console, bundled Python/Pillow and Node/Playwright Chromium. Commands run from `.tools/ground-mist`; `<godot>` is `../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.

| Command / steps | Result | Evidence |
| --- | --- | --- |
| `python scripts/ci/validate_cliff_kit.py` | PASS: 19 native modules, 16 unique cascade frames, seven unchanged source SHA256s, exact palette/alpha/geometry/demo checks | validator output |
| `<godot> --headless --path . --script res://build/cliff-kit/focused.gd --log-file build/cliff-kit/focused-compat.log` | PASS: 56 / 0 | focused log; actual physics for both player/bandit stair directions, upper/lower collision, nav, depth, water/VFX, filters, 12 repeated wall modules, history, save/reload, waterfall, both legacy IDs and restoration |
| `<godot> --headless --path . --script ../cliff-kit-scratch/build-script-backup/cliff-kit/focused.gd --log-file build/cliff-kit/focused-final.log` | PASS: 57 / 0 after layer-registry test correction | focused-final log |
| `python scripts/ci/godot_ci.py export --project . --out ../cliff-kit-complete-web --godot <godot> --log-dir build/cliff-kit/export-complete` | PASS: debug Web export, zero engine errors | export log |
| `node scripts/ci/smoke/cliff-kit-probe.mjs --serve-dir ../cliff-kit-complete-web --out-dir docs/visuals/cliff-kit/gameplay` | PASS: 22 checks, zero browser/engine errors; both climbs/descents, upper river/chakra, cliff collision, water frames, real editor place/drag/erase/history/file-save/reload and real Playtest of edited geometry | gameplay screenshots/result; followed by final export rerun for new layer-eye controls |
| `python scripts/ci/godot_ci.py export --project . --out ../cliff-kit-delivery-web --godot <godot> --log-dir build/cliff-kit/export-final` | PASS: final debug Web export, zero engine errors | export-final log; existing missing UID sidecars were recreated from cache, unrelated sidecars are not part of this implementation |
| `node scripts/ci/smoke/cliff-kit-probe.mjs --serve-dir ../cliff-kit-delivery-web --out-dir docs/visuals/cliff-kit/gameplay` | PASS: all 26 final checks, zero engine/browser errors, including actual new layer-eye hide/show | `docs/visuals/cliff-kit/gameplay/result.json` and fresh screenshots |
| `node scripts/ci/smoke/cliff-kit-preview.mjs --serve-dir ../cliff-kit-delivery-web --out-dir build/cliff-kit/preview` | PASS: actual animated cascade/foam capture, zero errors; native capture segment 40.136–46.701 seconds | `capture.json`; normal/half-speed MP4 and GIFs under `docs/visuals/cliff-kit/` |
| FFmpeg trimmed a 5.8-second runtime segment, encoded normal 24 FPS and half-speed via `setpts=2*(PTS-STARTPTS)`, plus 12 FPS cropped GIFs; Pillow decoded every GIF frame | PASS: normal 70 frames / 5,830ms; half-speed 139 frames / 11,580ms; both 640×480, frame visually inspected | normal/half-speed files; `build/cliff-kit/video-check.png` |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <godot> --log-dir build/cliff-kit/resources-final` | PASS: 442 scripts, 30 scenes, two resources, zero failures | resources-final log |
| `python scripts/ci/validate_orders.py`; `python scripts/ci/discover_project.py`; `python scripts/ci/validate_sprite_manifests.py` | PASS: orders, actual project discovery, player manifest | command outputs |
| `python scripts/ci/validate_godot_project.py --project .` | PASS: zero errors / warnings after moving nine temporary `.gd` scratch helpers out of ignored `build/` into sibling `.tools/cliff-kit-scratch/build-script-backup/` | command output; focused helper archived after its executed run |
| `python scripts/ci/godot_ci.py tests --project . --godot <godot> --log-dir build/cliff-kit/full-tests-final` | PASS: 5,130 assertions, zero failures, zero engine errors; includes all 57 modular checks | full-tests-final/tests-builtin.log; expected malformed-sheet negative-test warning only |
| `node scripts/ci/smoke/cliff-kit-preview.mjs --serve-dir ../cliff-kit-delivery-web --layout build/cliff-kit/long-wall.json --still 1 --out-dir build/cliff-kit/long-wall` | PASS: actual browser renders 12 repeated modules / 24 cells, zero errors; native caps/faces visually inspected for gaps | long-wall.png, long-wall-layout.json, long-wall-result.json |

## Issues encountered

- The two named desktop screenshots are absent from available paths. Asked for their location and proceeded using the actual committed approved cliff/stair art after allowing time for a reply. No claim to have inspected missing references.
- A generated-image candidate softened pixels and altered scale. Rejected; no candidate pixels ship. Native cuts preserve approved source colors and scale.
- Initial failures caught wrong player visual-node lookup, missing category classification, duplicate overlapping surface layers, a test actor obstructing the bandit stair mouth, and a repeated-wall fixture overlapping the demo. Fixed, retested; none ignored.
- Browser held-key feedback initially overshot the stair opening under software WebGL. A controlled-clock experiment stalled Godot and was stopped. Discrete real keyboard press/release events plus explicit upper-mouth alignment passed the full 22-check flow. Native traversal retains precise endpoint checks. The final harness removes a redundant lower-mouth height wait while keeping the separate lower-ground elevation/depth assertion.
- Screenshot review revealed that the right-side Layers list enumerated only the static legacy catalog, omitting the new manifest-backed category. Added the new IDs to that list and a native/browser regression check. Final verification includes actual hide/show eye clicks.
- Static project validation initially rejected nine historical/current temporary `.gd` test helpers hidden by `build/.gdignore`. Preserved them outside the Godot project, then validation passed without errors or warnings. No tracked gameplay file was removed.
- First full-suite run reported 5,127 passing assertions but correctly failed its engine-error scan: the new layer test accessed `shell.layer_rows` while booted in gameplay mode, where `shell` is null. Corrected the assertion to check the shared layer registry; actual panel construction/eye clicks remain covered in the browser. Focused rerun passed all 57 checks. Full suite rerun required before commit.
- Recording precise browser input introduced extra latency and oscillation around the stair head. Separated recording into `cliff-kit-preview.mjs`; the final functional probe uses discrete real input without recording. Upper/lower mouth waypoints allow 10/12-pixel positioning tolerance within the 72-pixel stair width, while full-platform 66-pixel height and lower-ground zero height/depth remain required. The precise native physical endpoint tests remain unchanged. Final functional probe passed all 26 checks.
- Waterfall first-fit showed an oversized/floating source mouth. Re-cut the existing falling column, aligned the diagonal lip and basin, and fixed sorting without changing legacy waterfall instances.

## Questions for project owner

None required to finish. Missing desktop screenshots can be compared later if supplied; committed source art is the current visual reference.

## Outstanding work / next steps

Pre-commit implementation, browser, full native, resources, repository checks, normal/half-speed previews and screenshot review are complete. Commit tested implementation, open reviewed PR, pass required CI, integrate through the normal workflow, verify deploy and smoke-postdeploy, then run the browser probe on the exact canonical merged build. Update this report with results and links before marking DONE.

## Live deployment

Pending; no live-delivery claim yet.
