# Job report — Five exact reference trees and independent falling foliage

- Agent: Codex
- Order: `orders/Codex/2026-10-22-reference-blossom-trees.md` (direct owner request)
- Date: 2026-10-22 America/New_York
- Final status: IN_PROGRESS — local implementation tested, integration/live verification pending
- Commit / PR: Not committed; this report precedes implementation commit.

## Work completed

Extracted all five original tree designs at source pixel scale into 320×448 RGBA canvases, preserving distinctive canopy silhouettes, twisted trunks, rocks, palette and fine detail. The JPEG's white background was removed; silhouette antialias was unmatted without a generative tree redraw. Connected components prevent neighboring trees leaking into a cutout. Native source, reproducible processor, source rectangles, individual anchors and checksums are included.

Added 96-phase / 24 FPS / 4-second wind animation per tree using bounded, nearest-sampled shader deformation. This is 96 runtime poses, not a claim of 96 hand-drawn sprites. Roots/rocks remain fixed, canopy tips move independently, and each tree has a different phase/strength. Added separate original 16-frame blue-lavender leaf and 16-frame blush-pink petal tumble sheets, with independent per-particle drift/sway, tumble, curl and fade. Birth points are sampled from actual opaque canopy pixels. Pool bounded to24/tree, 120 total, 6–10second lifetimes.

Placed all five in the actual training courtyard, west of the spawn/combat lane. One additive scene node, with nested root-based Y sorting; no gameplay/AI/controller/camera edits. These are nonblocking decorative props, preserving existing collision and navigation. `?trees=review` provides whole-grove and individual tree views, normal/half speed, pause/frame-step, independent wind/foliage toggles and Follow player. Its diagnostic hiding and review camera are query-only.

## Files changed

- `assets/environment/blossom_trees/`: source JPEG, five cutouts, art manifest, import settings and integration README.
- `assets/vfx/falling_foliage/`: two raw generated sheets (excluded from runtime), cleaned 4×4 tumble sheets, timing metadata/import settings.
- `scripts/environment/{blossom_grove,blossom_tree,falling_foliage}.gd` and `blossom_wind.gdshader`, UID sidecars.
- Additive `BlossomGrove` node in `scenes/arena/training_arena.tscn`.
- `tests/test_blossom_trees.gd`, test runner; browser proof and real shader capture scripts.
- `docs/visuals/blossom-trees/`: deterministic exporters, contact sheets, screenshots/probe evidence and animation preview.

## Tests performed before commit

Environment: Windows PowerShell, pinned Godot4.7.2, bundled Python/Pillow/NumPy, bundled Node/Playwright Chromium with SwiftShader. Commands run from dedicated `.tools/kunai-combat` checkout, branch `codex/blossom-trees`, base `6288ae30ece2d9d9d92c2612630484d3a0c4822f`. `python` / `node` below mean the bundled executables. Godot commands use `GODOT_BIN=<repository>/.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.

| Exact command / check | Observed result | Evidence |
| --- | --- | --- |
| `python docs/visuals/blossom-trees/extract_reference.py` | PASS five unique native cutouts, background cleanup, safe margins/anchors, sampled real canopy emitters | source, hashes, `tree-contact.png` |
| `python docs/visuals/blossom-trees/export_foliage.py` | PASS two transparent 16-frame32RGBA sheets, unique tumble poses | `foliage-contact.png`, manifest hashes |
| `python scripts/ci/godot_ci.py import --project . --log-dir build/trees-import` | PASS textures/scripts/shader imported | import log |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/trees-validate` | PASS 58 scripts, 8 scenes, zero failures | validation log |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/trees-tests` | PASS **1193 assertions, zero failures** | `build/trees-tests/tests-builtin.log` |
| `python scripts/ci/godot_ci.py export --project . --out ../blossom-trees-web-3 --log-dir build/trees-export-3` | PASS Web build | export log |
| `python scripts/ci/godot_ci.py finalize-export --project . --out ../blossom-trees-web-3 --kind game --commit-sha 6288ae30ece2d9d9d92c2612630484d3a0c4822f` | PASS 39MiB package, local base SHA only, not a deployed tree build | local build-info |
| `node scripts/ci/smoke/trees-proof-probe.mjs --serve-dir ../blossom-trees-web-3 --out-dir build/trees-browser` | PASS **all16 checks**, zero browser errors | `browser-evidence.json`, individual screenshots |
| Browser pixel comparison after 24 manually stepped wind phases, leaves hidden | Canopy changed38.2331%; sampled root changed **0%** | probe canopy/root statistics |
| `node scripts/ci/smoke/controls-probe.mjs --serve-dir ../blossom-trees-web-3 --out-dir build/trees-controls` | PASS normal-game movement/sprint/wall, Animation Lab, camera and vision overlay regression checks, zero errors | controls artifacts |
| `node scripts/ci/smoke/smoke.mjs --serve-dir ../blossom-trees-web-3 --out-dir build/trees-smoke --label blossom-trees-local` | PASS all smoke checks, zero fatal errors | smoke artifacts |
| `node scripts/ci/smoke/capture-tree-loop.mjs` | PASS 96 unique actual shader renders, start/end phase6, exact cycle wrap | `build/trees-loop/capture.json` |

Tests specifically cover real canopy source pixels, exact cycle wrap, fixed sprite anchor, independent wind/leaf lifetime, one-minute bounded particle simulation, emitter drain and restart. Browser drives actual mouse events through every tour and control, checks renderer movement against the fixed root, and samples bounded particle counts. Screenshots were inspected at native review scale and actual wide gameplay scale.

## Issues encountered

Initial background extraction exposed a neighboring silhouette fragment and JPEG white edging; fixed using full-image connected-component assignment and boundary unmatting. Corrected shader tint handling to avoid sampling the source texture twice. Review-only diagnostic text was hidden to keep art controls readable; normal diagnostics remain unchanged. The expected malformed-sheet unit fixture warning remains. Software Chromium is not a hardware performance benchmark; the five-tree effect has a fixed 120-particle pool and keeps full tree atlases out of Web texture memory.

## Questions for project owner

None required to deliver this requested art. Wind/leaf density can be adjusted after live review.

## Outstanding work / next steps

Finish recording animation preview, write final pre-commit results, integrate through required PR checks, deploy and verify exact public SHA, rerun live proof, then update this report with evidence. Live deployment pending; no public-update claim yet.

Preview assembly: python docs/visuals/blossom-trees/package_previews.py PASS; 96-frame/4second weeping-sway-96.gif and separate16-frame foliage-tumble.gif. Captured source PNGs remain local build evidence; delivered GIF/evidence JSON are versioned. Asset exporter rerun after metadata clarification preserved pixel checksums. No tests or browser errors remain.
