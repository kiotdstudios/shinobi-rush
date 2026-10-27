# Codex — Blightwood remaining terrain transition kits (art + builder-ready assets)

**Owner:** Codex (pixel art and asset delivery)  
**Priority:** P1 — map visual cohesion  
**Type:** Coverage audit plus missing flat terrain families and brown-bank land patch.
**Status:** REVIEW — requested Codex files delivered/live at bf96f014; 4412/0 native, 10/10 canonical checks, main deploy/postdeploy and full browser regression passed. Aki geometry/auto-blending and owner final world acceptance remain separate.

## Owner continuation / implementation
Owner explicitly requested “create all files still needed” after reviewing the audit. Implemented seven scoped flat families (grass/path, grass/temple, dirt/temple, grass/rock, dirt/rock, temple/rock, reusable grass/dirt), 308 registered tiles, plus 16 brown shore land layers and 16 editor icons. No duplicate existing path/dirt set, water animation or bridge end caps. Flat rock material assets are delivered for manual placement; vertical cliff geometry and measured landing/waterfall fit remain Aki's integration tasks, documented in `docs/visuals/terrain-transitions/AKI_HANDOFF.md`. Original audit below is historical, before this implementation.

## Coverage audit — October 27
See [precise matrix and recommended scope](../../docs/reviews/pr240/COVERAGE_AUDIT.md), actual material comparison, authored shared-edge counts and canonical browser evidence. Key corrections: the natural dirt atlas is position-bound and uses exposed-side masks rather than a reusable corner family; old `shore_dirt` is olive path palette, not new brown soil; temple joins are present (37 grass/temple, one dirt/temple base shared edge); bridge end caps already exist. Do not duplicate those kits. No new asset/runtime implementation in this audit; remaining checklist is intentionally unapproved/uncompleted.

## Goal
Finish the **missing terrain-to-terrain transition combinations** for the first Blightwood map so grass, dirt, existing ground/path, stone/rock, and river shorelines blend organically in the locked isometric pixel style. Reuse the existing tile sets; **do not recreate** PR #230's ground/path→dirt 16-mask kit or PR #226's brown dirt/grass-fringe work.

## Verified assets already in main
- `assets/environment/blightwood/path_dirt_transitions/`: PR #230, 16 corner masks × A/B/C variants; 72×36 logical diamonds, anchor (36,18); editor category **Path to dirt**.
- `assets/environment/blightwood/brown_dirt_path/`: nine-role dirt pack, 16 dirt edge variants and natural path atlas.
- `assets/environment/blightwood/ground_path/`: nine-piece ground/path set.
- Existing grass9 and temple floor sets in placed objects; inspect their exact source art and registration.
- `assets/environment/blightwood_shorelines/`: **three existing 16-mask shoreline families**, grass/water, dirt/water, rocky/water; preserve animated-water masking.
- `assets/environment/blightwood_water/`: animated water, foam, waterfall.
- `assets/environment/blightwood/stairs/`: existing cliff ledge and earth stairs.
- `assets/environment/blightwood_bridges/`: bridge modules and prefabs.
- `scripts/editor/auto_tile.gd`: currently auto-tiles water/grass/ground/temple and shoreline masks; separate task for advanced material-pair auto-blending.

## First deliverable: precise coverage audit (before making art)
Build a **material adjacency matrix** and visually inspect existing runtime and art, not just filenames. For each pair, mark EXISTING / NEEDS ART / NEEDS INTEGRATION / NOT NEEDED FOR FIRST MAP. Confirm with owner if the proposed material is genuinely distinct:
1. Grass ↔ brown dirt: inspect PR #226's 16 edge variants, actual grass source, corners and narrow paths. Only fill true gaps; don't regenerate existing pieces.
2. Grass ↔ ground/path (stone-like surface): **primary candidate for new 16-corner-mask transition kit**, plus 3 irregular interior variants where useful.
3. Brown dirt ↔ stone/rock: **primary candidate**, but compare with PR #230 (ground/path→dirt) and avoid duplicates. Only create if the stone/rock material is genuinely different from `ground_path`.
4. Grass ↔ exposed rocky terrain (if independently paintable): candidate for a separate 16-mask kit.
5. Temple floor ↔ grass / dirt / ground: audit whether the first map actually needs these joins; use only justified pairs, not indiscriminate combinatorial explosion.
6. Shoreline grass/dirt/rock ↔ water: existing 16-mask sets. Inspect visual corner cases, tight bends and small ponds; make **patch assets only** if demonstrably missing.
7. Paths ↔ bridge landings and cliff-top/stair landings: assess need for 2–4 directional entrance/end-cap/landing overlay tiles; coordinate with Aki's modular cliff kit PR #227. Do not overwrite bridge or cliff assets.
8. Waterfall lip, waterfall foot and rock/shoreline joins: **flag for Aki's cliff integration**; generate matching lip/foam/rock-edge assets only if needed after visual inspection.

## Asset specification
- Use existing approved Blightwood palettes and exact source pixels wherever possible. Pixel art, not smooth/blurry paint.
- Lock **72×36 logical isometric diamond** and **(36,18) anchor** for material-to-material transitions, consistent with PR #230; inspect actual source canvas/overhang rules before choosing PNG dimensions.
- For each **approved missing terrain pair**, supply **all 16 corner-bit combinations (00–15)**, not only nine familiar roles; use **bottom=1, left=2, right=4, top=8** as in PR #230 and shoreline sets. Document which bit denotes which material. Include A/B/C organic variants when beneficial, but do not pad with duplicate pure-fill variants.
- Straight edges, outside corners, inside corners, narrow trails, T-junctions, isolated islands, multi-cell strips, 90-degree turns, and 4-way intersections must align without seams. Neighboring corners must agree.
- No opaque rectangular backgrounds, alpha halos, softened pixels, mismatched lighting, scale changes, or off-grid anchors.
- Preserve nearest filtering, transparent exterior, correct sorting and floor/no-collision semantics.
- Avoid painting a square-looking checkerboard: irregular edge contours and natural variation inside diamonds, while shared seam pixels remain compatible.
- Keep source files, provenance/manifest, generation scripts if applicable, and final importable PNGs under clearly named `assets/environment/blightwood/` subfolders.

## Integration deliverables (Codex-owned)
- Register all new assets with stable IDs in `scripts/editor/placed_objects.gd` and expose organized categories/filters in the current map editor. Preserve all editor redesign work merged since PR #230.
- Ensure paint, select, move, delete, undo/redo, save/load and reload all work. No map auto-repainting.
- Include optional nonpersistent `?terraintransitions=review` or equivalent **in-game** demo showing all 16 masks of each new family, a connected organic sample map, and a real player walking across it.
- Coordinate with Aki on future **automatic material-pair blending** in `scripts/editor/auto_tile.gd`. Codex must not silently replace Aki's auto-tile implementation. If adding auto-blending is feasible and conflict-free, propose it as a separate scoped implementation PR with tests.
- Produce visual contact sheets, seam-check diagrams, and actual Godot/browser screenshots (not just generated concept sheets).
- Test alpha, dimensions, palette matching, all 16 masks, adjacency seams, resource import, builder registration and save/reload. Run repo-required CI.
- Keep work in separate logical PRs per approved material family if scope is large; report exact delivered combinations and any deferred combinations.

## Completion checklist
- [ ] Coverage matrix approved; no redundant regeneration of existing PR #230 / #226 / shoreline assets.
- [ ] All **actually missing and first-map-required** terrain pairs covered by complete 16-mask sets or explicitly justified smaller connector kits.
- [ ] Natural connected seams proven with screenshots of bends, thin trails, corners and junctions.
- [ ] Editor asset registration, category filtering, undo, persistence and reload verified.
- [ ] Real in-game demo, test evidence, manifest/source and concise handoff report delivered.
- [ ] Remaining auto-blending / cliff-waterfall integration work clearly assigned to Aki.

**Do not claim “all map transitions complete” until the material adjacency matrix, in-game tests, and owner approval confirm it.**

## Codex file-delivery completion
[PR240](https://github.com/kiotdstudios/shinobi-rush/pull/240) merged as `bf96f014dd10887cbed45b0f433c271d6db22740`; [main deployment](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40595087133) and exact canonical verification passed. See `docs/visuals/terrain-transitions/LIVE_DELIVERY.md` and `reports/2026-10-27-remaining-terrain-files-report.md`. Flat families, brown bank layers, builder categories, tests, contacts, seam diagrams and live demo are delivered. Existing bridge caps/water frames reused. Remaining Aki-owned integrations are in `docs/visuals/terrain-transitions/AKI_HANDOFF.md`; this status intentionally does not approve all map geometry or automatic blending.
