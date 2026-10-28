# Aki — Automatic multi-material terrain blending in map editor

**Owner:** Aki
**Priority:** P0 — first-map authoring
**Status:** DONE — implementation delivered and audited; PRs #251/#245 integrated as 090d8688, main deploy/postdeploy and 28/28 canonical checks passed. See orders/Codex/reports/2026-10-28-open-pr-completion-report.md. CI speed aspiration remains a measured follow-up.

## Mission
Make the map editor automatically select the correct **16-corner-mask terrain transition tiles** when painting adjacent flat-floor materials. The map creator should paint **Grass, Brown Dirt, Ground/Path, Temple, and Flat Rock** naturally, with no manual search for corner/edge pieces. Retain manual artistic overrides. **Do not regenerate artwork.**

## Already delivered — integrate, don't duplicate
- PR #240 (merged): 7 flat-floor transition families, 308 registered native tiles, 16 brown shoreline land layers, 16 icons, eight builder groups; `assets/environment/blightwood/terrain_transitions/`.
- PR #243 (merged): canonical live deployment proof and seam diagrams; live review `?terraintransitions=review`.
- PR #230 (merged): Ground/Path ↔ Dirt, 16 corner masks × three variants; `assets/environment/blightwood/path_dirt_transitions/`.
- PR #226 (merged): natural brown dirt paths / grass fringe.
- Existing grass/dirt/rock shoreline 16-mask kits and animated water.
- `scripts/editor/auto_tile.gd`: current automatic water/grass/ground/temple edge handling; inspect `scripts/editor/placed_objects.gd`, editor paint/undo/save/load and the latest editor UI before editing.

## Deliverables
1. **Terrain identity registry.** Classify each flat-floor tile (base, blended, shoreline, manual) by logical material. Include Brown Dirt and Flat Rock as first-class paintable terrain types. Treat mixed-mask tiles as having a known per-corner material signature, not a generic `land` fallback. Maintain compatibility with legacy map tile IDs.
2. **Adjacency-driven transition selection.** For all available pairs (Grass↔Dirt, Grass↔Ground/Path, Ground/Path↔Dirt, Grass↔Temple, Dirt↔Temple, Grass↔Flat Rock, Dirt↔Flat Rock, Temple↔Flat Rock), choose the correct corner mask (00–15) from existing registered assets. Use the **bottom=1, left=2, right=4, top=8** corner convention for 16-mask transition kits; verify material bit polarity per family from manifest. Note PR #226's dirt16 **edge** bits use a different convention: never conflate the two. Preserve A/B/C variations deterministically (stable across repaint/reload, unless user requests reroll).
3. **Painting workflow.** User chooses a *material* and paints cells. The affected cells plus necessary neighbors re-tile to continuous seams, including straight boundaries, inside/outside corners, narrow trails, T intersections, four-way junctions, small islands and diagonal adjacency. Support paint drag, fill, erase, undo/redo, move, save/load, and re-edit after reload. Avoid O(map-size) full recompute on each drag event; batch and update local ring only.
4. **Multi-material junctions.** Explicitly handle cells touching **3+ materials**. Do not pretend a two-material tile can represent three at one point. Define deterministic, visually safe precedence/fallback or layered composition with tests, and report any missing tri-material artwork separately. Never silently overwrite the owner's material choice or create opaque seams.
5. **Water boundary protection.** Retain existing animated water, shore family selection (grass/dirt/rock), foam masks and bank styles. Correctly update shorelines when nearby land material changes; never replace animated water with static baked water. Preserve bridge and cliff objects, collisions, player navigation, sorting and object placement.
6. **Manual override.** Keep all 16-mask assets accessible as manual tiles. A user who manually places a specific transition must be able to lock it or opt out of auto-retile, with clear editor behavior and persistent save semantics. Do not automatically repaint existing authored maps upon opening them; new auto-blend should apply on deliberate edits or explicit opt-in migration.
7. **UI integration.** Add logical material brush choices to the latest black editor UI (Tiles browser / search / filters). Do not regress minimap, pan, zoom, layer visibility, or properties. Provide an Auto Blend toggle and readable current brush state; no duplicated confusing categories.
8. **Testing and proof.** Add native unit/integration tests for all 8 material pairs, all 16 corner masks, both material polarities, diagonal/3-way junctions, 121-cell connected demos, paint/erase/undo/redo/save/reload, deterministic variants, manual locks and shoreline updates. Test against actual game/browser editor; attach screenshots/contact sheet of straight, corner, narrow, T, 4-way and island cases. Run CI and verify no console/engine errors.

## Scope boundary
**This order is about flat-floor material auto-blending.** PR #227 cliff/stairs/waterfall geometry is a separate Aki workstream. Add no speculative cliff-face art. Only report any missing landings or waterfall joints discovered during verification.

## Acceptance criteria
- [ ] I can paint a dirt path through grass and every bend/edge joins naturally without picking a transition tile.
- [ ] Painting Ground/Path next to Dirt uses PR #230's correct masks automatically.
- [ ] Painting Grass next to Ground/Path and all PR #240 pairs selects correct registered tiles.
- [ ] Water shorelines still animate and match neighboring land.
- [ ] No unexpected changes to existing saved maps; manual transition overrides persist.
- [ ] Save/reload, undo/redo, erase, multi-material junctions and drag painting pass.
- [ ] Performance remains responsive for normal first-map painting.
- [ ] Live browser proof, test results and concise handoff included in implementation PR.
- [ ] Clearly state which cases remain art-limited rather than calling them complete.

**Aki:** Implement on a code branch and submit an implementation PR with evidence. Do not mark this order itself as proof of implementation.
