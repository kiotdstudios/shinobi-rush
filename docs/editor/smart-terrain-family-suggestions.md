# Smart Terrain Brush and tile families

Open AUTO-TILE & TOOLS, turn on SMART BRUSH, and choose a floor tile in the palette. Known material metadata chooses the existing AutoTile brush. Keep AUTO BLEND on for shared corner transitions. DRAG, RECT, LINE and FILL use the same 72x36 diamond lattice. FILL changes a connected existing region; FILL VOID remains the separate bounded empty-map tool. Erase repairs surrounding edges. Ctrl+Z/Y undo/redo each gesture.

For mixed or unfamiliar tiles, choose REVIEW TILE FAMILY. The dialog shows registry identity and ranks five land materials by average interior color and four native diamond edge bands. These numbers are similarity scores, not probabilities or semantic guarantees. Pixels never approve a family. Select a material and Apply choice, or choose Manual tile only to reject suggestions. Reset override returns to metadata. Approval is saved with the layout, downloaded JSON and Playtest snapshot, and supports undo/redo. It affects future painting only; existing placed art stays intact. Manual Smart Brush painting pins its exact tile against later neighbor adoption. The LOCK TILE control can release individual pins.

## Integration

This completes and incorporates draft #262 on branch codex/smart-terrain-brush. TerrainFamilyMatcher now reads the actual catalog texture paths and existing TerrainBlend/AutoTile registries. Catalog terrain_material metadata has precedence over registry inference. Layout terrain_families overrides have precedence over both. props, tall grass, cliffs and unknown IDs are excluded. Water is recognized through metadata; color suggestions never infer water.

Native 72x36 floor images are sampled without scaling. Existing 112x112 grass canvases use their authored (56,84) foot anchor to sample the same diamond. Transparent/incompatible images produce no pixel ranking. Manual material assignment remains available. No asset importer, novel material generation, new transition artwork or global registry mutation is included. Approved materials paint the existing registered kit; they do not synthesize masks from an arbitrary image.

## Determinism and limits

The established auto-tiler resolves shared edges/corners, ten material pairs and 360 three-material signatures, retaining stable position-based A/B/C variation. Four distinct materials within one diamond still use the existing deterministic fallback and may show seams. Pixel ranking uses simple color statistics and cannot reliably infer artistic intent, collision, corner polarity or material semantics. A human can always override it.

Connected fill uses four edge neighbors, respects locked tiles/categories, stops at the arena boundary and refuses regions larger than 4096 cells before changing anything. Unmanaged mixed art fills only identical IDs; empty space is handled by FILL VOID. Existing maps load without approvals. Save schema remains version 7 with an optional terrain_families field; there is no gameplay or authored-map migration.

## Verification

Native suite: tests/test_smart_terrain.gd and existing tests/test_terrain_blend.gd. Browser probes: scripts/ci/smoke/smart-terrain-probe.mjs and auto-blend-probe.mjs. Job evidence and exact executed commands are recorded in orders/Codex/reports/2026-10-29-smart-terrain-brush-report.md.
