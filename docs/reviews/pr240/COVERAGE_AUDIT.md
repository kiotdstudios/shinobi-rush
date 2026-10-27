# PR240 — existing work versus remaining terrain needs

Audit: 2026-10-27. PR240 originally adds **one 59-line order, no assets or runtime implementation**. Reviewed source main `3b0a4f60` and original order head `0dcde1c3`; merged current main into the review branch to retain the new editor. Canonical browser proof identifies runtime `4ebda47269945600bfde7e4aac59a80e4d13d3fd` (the later main changes concern CI). No terrain, map, controller, editor or auto-tile implementation changed in this audit.

## What actually exists

| Work | Current delivery | Limitation against PR240 |
| --- | --- | --- |
| Grass | Nine flat roles, four tall variants; flat PNG 112×112, floor anchor (56,84), logical 72×36 | Nine silhouette roles do not supply a second material at every corner. Preserve padding/overhang. |
| Ground / paths | Nine native 72×36 olive earth/slate-gravel tiles, exact existing grass palette | Distinct from brown soil and temple slabs. Repeat joins documented as organic, not guaranteed pixel-identical. |
| Brown dirt / grass | Nine aliases, **16 exposed-side masks**, plus 676-entry authored natural-path atlas (317 dirt + 359 grass cells) | This is NOT a general 16-corner material family. Atlas selects by original material ID and exact world position; custom/moved cells do not inherit the continuous authored clearing mask. `dirt9`/`dirt16` are not registered builder IDs. |
| Ground ↔ brown dirt (#230) | All 16 corner masks × A/B/C, 48 catalog entries, 27 nine-role file aliases, own filter | 44 unique images: 42 mixed variants + two pure fills. Pure A/B/C duplicates intentional; don't generate duplicate pure fills in future kits. Hand-placeable, not automatically selected by land-material adjacency. |
| Grass / old dirt / rocky shore ↔ water | Three complete 16-mask families, separate stationary land and moving-water masks; own filters | Existing **dirt bank palette came from olive `ground9_center`**, before the brown dirt revision. It is not brown-soil shore coverage. Rocky family is sampled from temple stone, while `rock_15` is also used for cliff fill. |
| Temple | 13 catalog entries: centers/cracked/mossy + four sides/four corners | These are exposed-floor silhouettes, not grass/soil material blends. |
| Bridges | 13 modules including four end caps, 18 assemblies across two axes, separate layers; runtime Bridge and builder entries exist | End caps already exist: don't commission them again. Soil/grass overlap at bank sockets still needs fit evidence before requesting small landing overlays. Old art handoff still says NOT LIVE despite later runtime integration. |
| Stairs/cliff | SE and SW stairs, one SE ledge, snap/ramp/landing geometry | Full modular cliff kit is still Aki's separate order. An adjacency against cliff fill is not automatically a flat blend; preserve height semantics. |
| Waterfall | Existing 16-frame fall, foam and droplets, separately placeable | Fixed offsets: fall (0,-73), foam (0,-1). No general cliff-cap opening / upper-river lip / height-dependent foot registration; belongs with Aki's proof-of-fit. |

Sources: `scripts/editor/placed_objects.gd`, `auto_tile.gd`, `scripts/environment/natural_dirt_path.gd`, `blightwood_water.gd`, `bridge.gd`, asset manifests and `orders/Aki/2026-10-26-blightwood-modular-cliff-kit.md`. `existing-materials.png` shows actual source pixels at nearest scale; `authored-material-map.png` is an explicitly labeled source diagram, not gameplay proof.

## Material adjacency matrix and decisions

Counts below are **shared edges in the authored base grid**, each counted once, before shoreline retiling, stair landing overwrite, props and presentation overrides. They measure where to inspect, not the number of new tiles to create. Base cells: grass 1439, ground IDs/brown presentation 317, temple 185, cliff fill 776, water 391. Exact counts/coordinates/source hashes: `coverage-data.json`.

| Pair / join | Status | Evidence and needed work |
| --- | --- | --- |
| Grass ↔ brown dirt | **EXISTING / NEEDS INTEGRATION** | 205 base g–d edges. Authored natural clearing is already delivered and live; preserve it. For arbitrary editor layouts, reuse existing soil/grass art and add a corner-compatible reusable family only if general blending is approved; the side masks cannot be relabeled as corner masks. |
| Grass ↔ olive ground/path | **NEEDS ART** (first recommended family) | No mixed-material catalog set. Ground cells in the default clearing are rendered brown, so 205 g–d edges are not proof of 205 olive-path joins. Still required for editor-authored olive paths. Complete 16 corner masks, mixed A/B/C variations; exact source pixels. |
| Grass ↔ temple | **NEEDS ART** | **37** base g–s shared edges. Temple nine-role silhouettes only respond to void, so these are real first-map material joins, not a hypothetical combination. Recommend complete 16-corner family after grass/path. |
| Brown dirt ↔ olive ground/path | **EXISTING / NEEDS INTEGRATION** | PR230 complete. No new artwork. Aki's automatic material-pair selection remains separate; source terrain model currently has no independent brown terrain identity. |
| Brown dirt ↔ temple | **NEEDS ART** (low extent) | **1** base d–s edge. Temple slabs are visibly distinct from olive path, so #230 cannot be called temple coverage. Verify the actual junction after landing/cliff layout settles; full 16-mask family only if this material pair remains required. |
| Grass ↔ exposed rocky floor | **NEEDS ART / NEEDS INTEGRATION**, conditional height decision | `shore_rock_15` is independently placeable and visibly distinct; **344** base g–c edges. Many are intended cliff borders. Aki must classify flat joins versus elevated cliff edges before a flat 16-mask kit is produced. Do not smear grass across a vertical wall. |
| Brown dirt ↔ exposed rocky floor | **NEEDS ART / NEEDS INTEGRATION**, same condition | **33** d–c edges. Not covered by #230 (different rock material). Flat-only family if justified; cliff-foot/cap connectors otherwise. |
| Temple ↔ cliff rock | **NEEDS INTEGRATION** first | **90** s–c edges. Source pixels differ. Resolve actual cliff geometry/material at the top/foot before commissioning another flat family. |
| Olive path ↔ temple / rocky floor | **NOT NEEDED FOR FIRST MAP as separate olive pairs**, pending custom-layout needs | Every authored d cell has brown presentation; do not count it as both brown and olive. Do not generate two extra editor-only families without a demonstrated use. |
| Grass ↔ water | **EXISTING** | 66 base g–w edges; 16 valid masks, animated current retained. Live review works. No demonstrated missing mask. |
| Olive ground/path ↔ water | **EXISTING** | Existing shoreline family is named `dirt` but palette source is olive ground/path; AutoTile maps ground→dirt bank. Preserve compatibility. |
| Brown soil ↔ water | **NEEDS ART** (land-layer patch) | Five base d–w edges, before retiling. Existing `dirt_15` fill has six opaque colors; zero overlap with the brown fill's 24-color palette. Live Dirt focus is visibly olive. Reuse all existing water masks/animation and add matching brown bank land layers; do not regenerate water or claim existing family is absent. |
| Temple / rocky shore ↔ water | **EXISTING / NEEDS INTEGRATION** | 189 c–w edges; no direct s–w shared edge in base map. Existing rock family works; chooser maps temple→rock. Cliff fill (`shore_rock_15`) is a generic `land` semantic but preserves explicit shore family. Check mixed-bank corners rather than generate another full family. |
| Path ↔ bridge sockets | **NEEDS INTEGRATION** | Four end caps already supplied. Two axes and existing sockets need a connected bank fit test. Only commission 2–4 substrate overlays if a visible gap remains. |
| Path ↔ stair/cliff landings | **NEEDS INTEGRATION** | Existing landing fill and real ramp geometry. Resolve with Aki's modular cliff kit; overlays must not change collision/elevation. |
| Waterfall lip/foot/shore | **NEEDS INTEGRATION** | Existing animated fall and foam are usable. Aki's order expressly requires proof-of-fit before additional water art. Request lip/foam/rock-edge patches only from that measured failure. |

## Engineering gaps versus art gaps

`AutoTile.TERRAINS` has water/grass/ground/temple only. `role_for()` checks whether a neighbor has **any floor**, not whether it is the same material: adjacent grass, stone and ground all produce center pieces. Water alone uses material-aware corner masks. Hand-placed `path_dirt_*` returns generic `land` and isn't auto-blended. Thus adding PNGs alone will not make the paint tool blend materials.

Codex: new justified material layers, corner manifests, seam proof, stable IDs/filter, nonpersistent connected demo, source provenance. Aki: explicit material identity (especially brown versus olive), corner ownership and automatic selection, mixed-material junction policy, cliff height and waterfall fit. Keep this separate from Aki's active auto-tile implementation.

## Recommended sequence

1. Approve this matrix/scope. No new art has been generated by this audit.
2. Grass↔olive path: one focused family and builder/demo PR. Use corner bits bottom=1, left=2, right=4, top=8; grass padding stays registered, not shrunk to 72×36. Two pure fills plus 14 mixed masks × meaningful A/B/C = up to **44 unique images**, not 48 new unique frames by padding duplicates.
3. Grass↔temple (37 actual base edges); brown shoreline land-only patch reusing existing masks. Keep source palettes and native scale.
4. Review the one soil/temple join, then approve full family only if justified. Hold rock blends and landing/waterfall overlays until Aki's geometry fit determines flat versus vertical joins.
5. For each new family: test shared seam signatures for all compatible neighboring masks/variants, narrow strips, inside/outside corners, split masks 6/9, T/four-way junctions and connected natural layouts. Verify place/move/delete, **undo/redo**, filtering, save/reload and real player movement. Existing #230 test covers move/delete/filter/save but does not explicitly exercise undo/redo or exhaustive pairwise pixel seams; don't reuse it as proof of those extra criteria.

## Fresh verification and limits

- `python docs/reviews/pr240/audit_coverage.py`: PASS. All three shoreline mask ranges 0–15; all 48 land/water layers binary and exact complementary diamond; all 48 path/dirt native opaque diamonds and manifest hashes valid. No asset regeneration.
- `natural-path-probe.mjs --url https://kiotdstudios.github.io/shinobi-rush/ --out-dir docs/reviews/pr240/live`: **9/9 PASS**, 3154 entries and 103 obstacles unchanged, real movement, zero errors. Same-camera screenshots inspected. Capture UTC `2026-10-27T21:08:03.949Z`.
- `browser-proof.mjs https://kiotdstudios.github.io/shinobi-rush/ docs/reviews/pr240/shore-live --no-capture`: **12/12 boolean checks PASS**, current moves, land rooted, half-speed/pause/step and family focus work, zero errors. `captured: 0` is intentional: no new GIF was requested. Exact runtime SHA recorded by probe; UTC `2026-10-27T21:08:56.294Z`. Inspected actual live dirt-bank screenshot.
- This is an audit, not new terrain implementation. No new editor undo/persistence claims, new-family seam proof, cliff traversal or waterfall fit test. Native full suite/export not rerun for documentation-only analysis. Live deployment of this audit: not applicable.

**Conclusion:** PR240's broad goal is valid, but it should not be executed as a blanket set-generation job. Existing work covers much of it. The next useful work is narrowly scoped land blends and a brown-shore land patch, followed by Aki-owned material/height integration. Entire transition order remains IN_PROGRESS; this first coverage deliverable is ready for owner review, not “all transitions complete.”
