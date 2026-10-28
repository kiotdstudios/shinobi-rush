# PR247 — Missing terrain pairs and three-material junction art

Status: DONE for Codex art delivery, manual builder registration and live preview. Separate implementation PR248 merged and verified live. PR247 itself remains an unchanged draft specification; Aki's automatic placement acceptance remains separate.

## Scope and ownership

Audited current main `7a4cf8b5523e2b43df2902840915ec25497fed99`, PR245 `61b319f91a40cba144e4ece738f3e7a67c47fb4c`, its TerrainBlend/AutoTile/registry/test/demo, and existing PR230/240 manifests. Full ten-pair matrix and Aki consumption contract: `docs/visuals/terrain-junctions/AKI_HANDOFF.md`.

Delivered files: two new 44-tile pair families, six reusable occupancy masks, 360 flattened three-material exports (all ten triples × 36 corner signatures), machine-readable manifest/source hashes, twelve contact sheets, deterministic generator, exact-corner art lookup, twelve builder categories, opt-in actual-map review and a reproducible browser probe. Original source terrain, authored map, AutoTile, camera and gameplay controllers are not changed. Existing generator category append is made safe alongside the new category constant.

Native 72×36 RGBA, (36,18) anchor, transparent exterior/opaque floor diamond, nearest/lossless/no mipmaps/no collision. No raw generated art, RGB interpolation, redundant B/C pure fills or rotated lighting. Junction source complexity is six shared patterns; flattened exports preserve existing builder/save compatibility.

## Verification executed before implementation commit

- Initial Godot import: PASS, all 454 new PNGs imported; production sidecars retained.
- Resource validation: PASS, 434 scripts / 30 scenes / 2 resources, zero failures.
- Generator: PASS, 88 pair tiles, all ten triple combinations, 360 junctions, 6 source masks, 1,952 within-pair adjacency checks, **26,776 exact edge comparisons** including actual existing PR240 PNGs; approved palette membership and exact alpha passed. PR230's older texture-edge RGB protocol is explicitly excluded from exact-RGB claims; no old assets are overwritten.
- PR245 fixture mathematical reproduction: PASS, its documented 49-cell grass/dirt/rock case produces the same two conflicting vertices `(180,0)` and `(216,18)`. Exact-corner junction selection yields zero. This is explicitly a read-only Python port, not execution of PR245's pending programming branch. Saved before/after IDs are rendered by the Godot review.
- Order structure validator: PASS.
- Sprite manifest validator: PASS, 1 manifest, zero errors.
- `git diff --check`: PASS.
- Full native regression: **PASS, 4,986 passed / zero failed**, including 101 new art/lookup/import/builder assertions. Expected intentional malformed SpriteSet fixture warning only. Following isolated preview improvements, the final Web export/probe was rerun; CI will repeat the full suite on the submitted head.
- Combined old/new generator idempotence: PASS, 456 registry/PNG/manifest files unchanged after rerunning both generators; zero existing art/map file diffs. Each new pair has 44 unique images and each triple 36.
- Final local exported Web playtest/screenshots: **PASS, 15/15**, all 13 real button selections (two pairs, ten triples, exact 49-cell PR245 fixture), connected samples, autosave disabled, real player movement and zero engine/browser errors. `docs/visuals/terrain-junctions/gameplay/result.json`; full and clipped before/after screenshots at identical camera. Initial visual inspection caught a 10-pixel demo-origin offset and obscuring original props; the final preview uses the exact diamond lattice and an isolated in-memory floor, without modifying any authored map file. H hides controls for unobstructed inspection. Manifest parsing is cached once per review instance.
- Required PR CI: PASS, Godot CI `40620237089`, repository checks `40620237114`, pipeline self-test `40620237117`. CI repeated **4,986/0** and resource **434/30/2, zero failures** on the submitted head.
- Full browser regression: PASS, run `40620237087`, including smoke, debug-log and the full controls/vision probe (zero console errors).
- Reviewed integration: PR248 merged normally after required checks, with protected-main strict status policy active and zero required approving reviews; no bypass or force push. Main pipeline **40621591903 passed every job**, including deploy, smoke-postdeploy and gate.
- Canonical live verification: **16/16 PASS** at **2026-10-27 22:47:49 America/New_York**, exact deployed SHA `7fa1a1677d22ad3b86031986c7ed46618ed8e556`. All thirteen review samples, actual movement, autosave off, no engine/browser errors; published screenshots visually inspected. Evidence: `docs/visuals/terrain-junctions/live-gameplay/`, `main-deployment.json`, and `LIVE_DELIVERY.md`.

## Remaining integration / limits

Aki must consume the two new family polarities and exact three-material signatures in PR245; managed-tile movement/ownership, vertex voting and brush behavior remain Aki's code. No triple combination is deferred. Four distinct materials inside one diamond, water/shore algorithms, height/cliffs/stairs/waterfalls are outside this art contract. Four-way intersections involving only three materials are supported.

Questions: None. Blocking access failures: None observed.

Implementation commit: `6c9a332cc87c16ca73e7b883b80e96d51123e0bc`.
Implementation PR: https://github.com/kiotdstudios/shinobi-rush/pull/248 (separate from the unchanged draft order PR247).
Runtime merge: `7fa1a1677d22ad3b86031986c7ed46618ed8e556`.
Main CI: https://github.com/kiotdstudios/shinobi-rush/actions/runs/40621591903 — merged-build native suite passed 4,986/0; resource validation 434 scripts / 30 scenes / 2 resources, zero failures. Deployment and post-deploy smoke passed.
Live review: https://kiotdstudios.github.io/shinobi-rush/?junctions=review&v=7fa1a167

Evidence/report follow-up is documentation/screenshots only. **Live deployment: not applicable** to that follow-up: no runtime files change, and the implementation's canonical deployment was verified at the exact SHA above.
