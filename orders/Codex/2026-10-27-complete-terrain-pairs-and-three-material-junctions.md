# Codex — Close missing terrain art gaps for Aki's automatic blending

**Owner:** Codex (pixel art, asset registration and visual validation)
**Priority:** P0
**Depends on:** PR #245 (Aki's automatic multi-material terrain blending; currently under review).
**Status:** REVIEW — implementation and integration audited; final canonical evidence will be recorded in the Codex completion report.

## Why this order exists
Aki's PR #245 implements automatic flat-floor transitions across eight supported material pairs using PR #230 and PR #240 assets. Its implementation report explicitly identifies **missing Ground/Path ↔ Temple and Ground/Path ↔ Flat Rock art** and **visible seams where three materials meet at one vertex**. We need art and precise handoff for those cases. Do not recreate the 308 flat tiles in PR #240, PR #230 Ground/Path↔Dirt, or existing shoreline sets.

## Phase 1: audit actual source and coordinate with Aki
1. Inspect PR #245 head, the latest `main`, `scripts/editor/auto_tile.gd`, `scripts/editor/placed_objects.gd`, the existing terrain transition manifests and contact sheets. Confirm exact material IDs, 0/1 mask polarity, pixel dimensions, anchor, source palette, registration and editor brush semantics.
2. Produce a material-pair coverage matrix including all five paintable types: Grass, Dirt, Ground/Path, Temple and Flat Rock. There are ten unordered pairs; identify the eight already covered and the **two missing** listed below. Do not create unnecessary duplicates.
3. Coordinate asset IDs and manifest schema with Aki so she can integrate new pair families without breaking automatic painting or manual tile locks. Keep Codex's art PR separable from Aki's PR #245 code changes.

## Phase 2: finish the two missing two-material transition families
- **Ground/Path ↔ Temple**: full connected 16-corner-mask family.
- **Ground/Path ↔ Flat Rock**: full connected 16-corner-mask family.
- Use **bottom=1, left=2, right=4, top=8** as the mask convention. Document exactly which material occupies the set bits. Follow approved PR #240 native **72×36 RGBA diamond, (36,18) anchor**, nearest/lossless import, no mipmaps, transparent outside. Reuse exact approved source pixels/palette; no blurry resampling.
- Provide all 16 masks, with A/B/C natural variations for mixed tiles where beneficial; don't duplicate identical pure-fill B/C images. Ensure seam-compatible edge pixels and convincing non-square curves.
- Deliver source files, manifest/hashes, individual PNGs, contact sheet, connected layouts and seam tests. Register stable IDs and builder categories without overwriting existing categories or source art.

## Phase 3: solve three-material junctions rather than hiding them
- Reproduce the **two visible 3-material junction seams** acknowledged in PR #245's demo. Enumerate all distinct relevant triple combinations for five materials (10 triples), then determine which actually require unique junction art. Do not claim a pairwise tile alone can represent three materials at one vertex.
- Propose a consistent, minimal **junction overlay/cap system** or dedicated tri-material junction tile kit that works for corner orientation, ordering, alpha and painter sorting. Prioritize actual first-map combinations; report any intentionally deferred triples.
- Generate matching 3-way junction assets for approved combinations, including rotated/oriented variants as needed. Provide explicit machine-readable metadata: material triplet, orientation, anchor, draw order, occupancy, edge compatibility, and placement rules.
- Verify seam-free examples of T junctions, diagonals, tiny islands, 4-way intersections and crossings where three materials touch. Avoid a huge combinatorial art dump if a reusable cap system achieves the same result.
- **Important integration boundary:** Codex may add art and registry support, but coordinate actual automatic junction placement logic with Aki; do not silently rewrite Aki's pending PR #245 implementation. If integration code is required, separate it clearly and request Aki to consume the manifest.

## Phase 4: proof and delivery
- Build a real editor/game test scene that demonstrates both missing pairs, all 16 masks, A/B/C variants and the new 3-material junctions. No edits to the owner's authored map; use opt-in demo and disable autosave.
- Capture contact sheets and **actual Godot/browser screenshots**, not mockups only; include before/after seam comparisons and show player movement over the joins.
- Validate native Godot import, correct dimensions/alpha/palette, no opaque rectangles, all edge adjacency cases, 0/1 polarity, save/reload, manual placement and category filtering. Run repo CI and browser checks.
- Include a handoff report identifying new asset IDs, the exact files Aki must reference, triple-material coverage, any art-limited gaps and reproducible verification steps.

## Explicitly NOT Codex's assignment
- **Moving managed tiles losing terrain ownership** is an **Aki code/state persistence bug**; flag to Aki on PR #245, do not attempt to solve it with art.
- Variant reroll UI and algorithm are Aki editor behavior.
- Cliff faces, cliff elevation, stairs, waterfall, bridge geometry and collision are separate from flat-floor transitions.

## Acceptance
- [ ] Both missing pairs have full, correct 16-mask transition kits, tested against existing source tiles.
- [ ] Three-material seams are eliminated for the approved first-map combinations with documented junction assets and placement contract; any remaining unsupported cases are explicitly enumerated.
- [ ] No duplicate regeneration or damage to PR #230/#240 art and no conflicts with PR #245.
- [ ] Editor registration, test scenes, screenshot proof, source/manifests, CI and Aki handoff delivered.
- [ ] Codex opens a separate implementation PR with evidence. **Do not mark this order as implemented.**
