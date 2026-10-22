# Job report — Builder grass, filters and scroll isolation
- Agent: Codex
- Order: orders/Codex/2026-10-22-builder-grass-filters.md
- Date: 2026-10-22 America/New_York
- Status: IN_PROGRESS — tested implementation, PR/publication pending
- Commit / PR: not committed; report created before implementation commit

## Work completed
Direct owner request authorizes this job in Aki-owned builder code. Added nine grass terrain entries and four tall accents, native thumbnails and placement ghosts. Starting247ground/111tall tiles now use the same editable object model as new placements. Shared original wind materials/anchors/nearest filtering preserve the approved look. Grass adds no solid bodies or nav obstacles. Snap uses existing72x36 isometric grid; Snap Off remains free placement.

Save format4 includes grass so original tile deletions survive reload. Version1–3 layouts retain their trees/walls and receive the original meadow once. Four checked-by-default type filters (Trees, Walls, Grass, Tall grass) hide palette sections, world artwork, overlays and picking without removing layout data or solid collision. Hidden selected/placement type cancels editing that invisible type. Filters are session visibility controls, not saved deletions.

Builder panel stops scroll propagation even at list limits. Animation Lab's wheel zoom also rejects input while a hovered Control belongs to the builder, leaving outside-wheel zoom operational. Existing save/Ctrl+S/download retained.

## Files changed
scripts/editor/placed_objects.gd (catalog, decorative grass lifecycle, visibility/picking, save migration); world_editor.gd (palette, filters, snapping, read-only browser evidence); scripts/environment/wind_grass_field.gd (shared wind sprites and actual editable counts); additive arena adoption hook; scoped wheel guard in scripts/ui/animation_lab.gd; tests/test_world_editor.gd; scripts/ci/smoke/builder-grass-probe.mjs.

## Tests before commit
Bundled Python/Node/Playwright; pinned Godot4.7.2 Windows console via GODOT_BIN. Base e561574c8a1c146f6496b42763dc3fdaf640d7af. Command paths relative to clean checkout .tools/kunai-combat.
- godot_ci.py import --project . --log-dir build/builder-grass-import: PASS.
- godot_ci.py validate-resources --project . --log-dir build/builder-grass-validation: PASS70scripts/8scenes/zero failures.
- godot_ci.py tests --project . --log-dir build/builder-grass-tests: PASS1344/zero failures before final grid-snap refinement.
- godot_ci.py export/finalize-export --project . --out ../builder-grass-final-web (kind game, full base SHA): PASS39MiB. Local identity is the base, not a public update claim.
- builder-grass-probe.mjs --serve-dir ../builder-grass-web --out-dir build/builder-grass-browser-2: all17checks PASS. Actual wheel at top/bottom/header, outside zoom, filters, placement, select, drag, delete, explicit save+reload, zero browser errors.
- controls-probe.mjs --serve-dir ../builder-grass-web --out-dir build/builder-grass-controls: PASS movement/sprint/wall, lab/camera and vision regressions; zero errors.
- grass-proof-probe.mjs --serve-dir ../builder-grass-final-web --out-dir build/builder-grass-wind-regression: all15PASS, rooted motion/half speed/step/gust/allviews preserved.

## Issues encountered
First browser save probe scrolled the second grass card in the wrong direction and clicked outside its viewport; fixed the probe to seek by visible card position and assert second placement before Save. Save/reload then passed. Initial finalize-export rejected a short SHA; rerun with full40character base passed. Expected malformed-sheet fixture warning only in passing unit suite. No implementation failures hidden or committed.

## Questions for owner
None.

## Outstanding work
Final grid-snapping suite/browser evidence, required PR checks, merge/deployment and exact live verification. Mobile hardware performance not benchmarked. Existing F3 overlap between sense-debug and builder was inherited; this job preserves key bindings.

## Final checks before implementation commit
Final grid-snap suite: godot_ci.py tests --project . --log-dir build/builder-grass-final-tests PASS1345/zero failures. Final export builder-grass-probe.mjs --serve-dir ../builder-grass-final-web --out-dir build/builder-grass-final-browser: all17checks PASS; screenshot/persistent JSON copied to docs/visuals/builder-grass/. Final wind-regression probe all15PASS. Latest main checked unchanged. git diff --check and order validator passed.
