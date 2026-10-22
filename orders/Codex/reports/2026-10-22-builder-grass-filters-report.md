# Job report — Builder grass, filters and scroll isolation
- Agent: Codex
- Order: orders/Codex/2026-10-22-builder-grass-filters.md
- Date: 2026-10-22 America/New_York
- Status: DONE — integrated, published and live verified
- Commit / PR: initial e210457; PR https://github.com/kiotdstudios/shinobi-rush/pull/93; reviewed head78575ff608d246580314335982eba2f3d709bf0d; merged runtime028b46e11236b508a3bde6836c9a8bbdf961fc90. Report created before implementation commit.

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

## Latest-main integration before merge commit
Aki dock-tabs PR92 advanced main to874b4e4d7fa80ff5c7e9720edb38b118c8fe1da9. Clean merge, including Animation Lab; wheel guard preserved. Ran import, tests (build/builder-dock-tests):1345PASS/zero failures; fresh export/finalize ../builder-dock-web PASS; controls-probe (build/builder-dock-controls) PASS including updated tab lip; builder-grass-probe (build/builder-dock-browser-2) all17PASS,zeroerrors. Browser save flush is asynchronous:2.5second wait was intermittent, so probe now allows8seconds before reload; the round-trip then passed. No save behavior bypass or runtime API mutation used. Updated preserved evidence before this commit.

## Chase-fix integration before merge commit
Main advanced to b2fc2f75f3c0fc8747abe588805d9371a0d953f9 (PR89,4-line bandit fix plus test). Clean merge; builder and wheel source unchanged. Ran full suite build/builder-chase-tests, fresh export/finalization ../builder-chase-web, and smoke.mjs --serve-dir ../builder-chase-web --out-dir build/builder-chase-smoke --label builder-chase-integration. Web smoke PASS9file hashes,real keyboard response33.314%,zero fatal errors. Existing17builder browser checks remain valid for unchanged builder code; final public17checks will repeat after deployment.

Full chase-integration suite PASS1346/zero failures,expected malformed-sheet fixture warning only.

## HUD zoom integration before commit
Required checks for2c9afb2passed, but main advanced at merge to0e841440632467c536e8dbda12d104a06a47095f(PR94). Clean merge of Animation Lab; guard preserved. Full suite build/builder-hud-tests1346PASS; fresh export/finalization ../builder-hud-web PASS; builder-hud-browser all17PASS; builder-hud-controls PASS,zeroerrors,baseline0.665 and ceiling1.5 preserved. Main then advanced again to104e9b4(PR95). Recording tested intermediate merge before integrating that separate change.

## Health/flicker integration before merge commit
Main104e9b490bd622ae8b3b3798274ae2f7e5c4c80d(PR95) merged cleanly. No Codex edits to health/combat logic. Import PASS; generated missing tests/test_health_flicker.gd.uid included as required Godot sidecar. Full suite build/builder-health-tests1361PASS/zero failures. Fresh export/finalization ../builder-health-web PASS. Builder probe build/builder-health-browser all17PASS/zeroerrors,including save/reload and scroll isolation with current0.665baseline. Updated screenshot/JSON. Pending renewed required checks and live publication.

## HUD restyle integration before commit
Main41781fe2a45945445265a35ae3ef4fe430ef9a98(PR88) changes builder scrollbar/card styling and HUD. One insertion conflict resolved by preserving both set_type_filter and _fat_scrollbar. Gutter/card styles and scoped wheel guard preserved. Full suite build/builder-style-tests1361PASS/zero failures; fresh export/finalization ../builder-style-web PASS; builder-style-browser all17PASS/zeroerrors including save/reload and top/bottom/header wheel isolation. Updated evidence before merge commit. Main confirmed unchanged at commit time.

## Orcha leash integration before merge commit
Main7a1ec5094512e7d66e17ec1dd0fa0db3dbd73e34(PR96) merged cleanly; builder files unchanged. Full suite build/builder-leash-tests1365PASS/zero failures; fresh export/finalize ../builder-leash-web PASS; smoke.mjs --serve-dir ../builder-leash-web --out-dir build/builder-leash-smoke --label builder-leash PASS9hashes,rendered canvas,real keyboard effect26.550%,zero fatal errors. Existing17builder checks from unchanged UI remain valid; repeat on public deployment planned.

## Final live delivery (supersedes pending notes above)
Completed2026-10-22T20:39:56Z (16:39 America/New_York). PR93 merged with required checks; no bypass. Exact published runtime028b46e11236b508a3bde6836c9a8bbdf961fc90. Workflow39849344461 build,pre-deploy browser,Pages publication,post-deploy live smoke and gate all confirmed success.
Live builder: https://kiotdstudios.github.io/shinobi-rush/?editor=1&v=028b46e
- builder-grass-probe.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --out-dir build/builder-grass-live: all17PASS,zeroerrors. Real wheel at list top/bottom/header leaves zoom fixed; outside zoom works. Actual palette placement,select,drag,Delete,checkbox filters,reveal,Ctrl+S and reload persistence pass.
- smoke.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha 028b46e11236b508a3bde6836c9a8bbdf961fc90 --out-dir build/builder-live-smoke --label builder-live: PASS exact public SHA,nine file hashes,rendered canvas,keyboard effect29.422%,zero fatal errors,four nonfatal engine warnings.
- Opened public builder in Codex browser,clicked Trees/Walls off,observed palette and world change,scrolled to Tall grass with world zoom unchanged,restored asset visibility and retained tab.
Preserved live-palette.png,live-proof.json and live-smoke.json in docs/visuals/builder-grass/.
Final automated suite1365PASS/zero failed. No unresolved implementation failures. Incoming Orcha order formatting cleaned (trailing whitespace/EOF/control character) during integration; no runtime change.
This report/order/evidence follow-up does not represent a second runtime deployment. Remaining recommendations: mobile hardware performance benchmarking; inherited F3 overlap remains separate. No owner decision needed for completed builder delivery. Other queued art orders are separate.