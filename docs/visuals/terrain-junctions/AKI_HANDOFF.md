# PR247 terrain art handoff

Art contract audited against PR245 `61b319f91a40cba144e4ece738f3e7a67c47fb4c` and main `7a4cf8b5523e2b43df2902840915ec25497fed99`.
This PR supplies art, registration and an opt-in playable demo. It does not change Aki's vertex voting, managed tile ownership, brushes, auto placement, movement, or the owner's map.

## Material coverage

| Pair | Existing family / new delivery | Set corners |
|---|---|---|
| Grass / Ground | grass_path, PR240 | grass |
| Grass / Dirt | grass_dirt, PR240 | grass |
| Grass / Temple | grass_temple, PR240 | grass |
| Grass / Rock | grass_rock, PR240 | grass |
| Ground / Dirt | path_dirt, PR230 | dirt |
| Dirt / Temple | dirt_temple, PR240 | dirt |
| Dirt / Rock | dirt_rock, PR240 | dirt |
| Temple / Rock | temple_rock, PR240 | temple |
| Ground / Temple | **path_temple, this delivery** | **ground** |
| Ground / Rock | **path_rock, this delivery** | **ground** |

Logical material `ground` is the existing Ground/Path brush, not brown dirt. Files retain the existing `path_` naming convention. Both new families have all 16 masks; pure 00/15 only A, mixed masks A/B/C (44 per family, 88 total). Use bottom=1,left=2,right=4,top=8. PR226's side-bit masks are a different convention.

## Junction representation

`assets/environment/blightwood/terrain_junctions/junctions.art.json` is the machine-readable contract. `scripts/art/terrain_junction_art.gd` supplies an isolated lookup: `TerrainJunctionArt.tile_id([top,right,left,bottom])`. It returns an empty ID for unsupported/unknown signatures, never silently drops a third corner.

All ten triples are included: grass/ground/dirt, grass/ground/temple, grass/ground/rock, grass/dirt/temple, grass/dirt/rock, grass/temple/rock, ground/dirt/temple, ground/dirt/rock, ground/temple/rock, dirt/temple/rock. None is deferred.

There are only **six reusable occupancy source patterns**: 0012,0102,0112,0120,0121,0122. Canonical labels follow first occurrence in top/right/left/bottom order. Permute material slots rather than rotating the bitmap: rotated source stone lighting would be wrong. Each pattern's RGB channels identify its three opaque material regions, alpha the diamond. Six permutations × six patterns = 36 exact signatures per triple. The generator exports 360 small flattened PNGs for the existing unmodified builder texture/save pipeline; it does not author 360 unrelated artworks, generate B/C duplicates, or require a shader per placed tile. Keeping the six masks and manifests permits a future layered renderer without changing the visual contract.

IDs use `junction_T_R_L_B`, where material numbers are grass=0,ground=1,dirt=2,temple=3,rock=4. Example `junction_0_2_4_0` is grass/dirt/rock/grass at top/right/left/bottom. Full triplet, slot mapping, orientation and hash are recorded for every export.

All tiles are native 72×36 RGBA, anchor (36,18), full opaque floor diamond/transparent exterior, nearest/lossless, no mipmaps, no collision. Place **instead of** the cell's floor, on Ground z=-1 beneath actors. No opaque overlay, height offset, padding, scale change or painter-order trick. Mixed regions select approved source pixels without RGB interpolation. Two registered border pixels use the PR240 opposite-edge source signature. PR230 path_dirt keeps its original texture-edge sampling; its logical corner polarity agrees, but pixel-identical border RGB with that older family is not asserted. Original PR230/PR240 assets remain untouched.

## Aki integration steps

1. Add `path_temple: [temple,ground]`, `path_rock: [rock,ground]` to TerrainBlend.FAMILIES. Keep the existing logical material IDs and bit polarity.
2. After choosing a shared, deterministic corner material per vertex, retain all four corner votes. For three distinct materials, use the exact junction lookup instead of `resolve()` dropping a material. Its signature must be recognised on subsequent pin/legacy inspection. All 36 signatures per triple are available.
3. Keep manual placed IDs pinned; preserve managed ownership through move/save/undo in Aki's code. The moving-managed-tile ownership defect remains Aki's task.
4. Do not suppress third-material votes merely to fit pair art. Pair art handles only one/two materials per cell. Junction art handles exactly three. A four-way crossing involving three materials is supported; **four distinct materials inside one diamond is explicitly deferred**, as are water and height/cliff joins.
5. This art PR is separable from PR245. Consume this manifest in that programming PR; no automatic terrain placement is changed here.

## Reproduce the two reported seams

`scripts/art/reproduce_pr245_junctions.py` is a read-only mathematical port of PR245's documented 7×7 grass/dirt/rock test. It reproduces its minority/far-vote/priority rules, third-material candidate scoring and pair fallback, without shipping a second production auto-tiler. Before: contradictory material votes at **(180,0)** and **(216,18)** relative to fixture origin. After exact junction selection: **zero** contradictory vertices. All 49 cell IDs and before/after corner signatures are stored in `pr245-fixture.json`. The port is explicitly a Python reproduction, not a claim to have executed PR245's pending code in this branch.

The actual Godot game renders those exact saved before/after IDs in `?junctions=review`, button **PR245 exact fixture**. The same camera and player are used for both screenshots. The ten other triple demos contain T branches, diagonal strokes, a tiny island and crossing regions. Their “pair-only approximation” comparisons are illustrative and are explicitly not labelled as PR245's voting algorithm.

The review clears only the loaded in-memory copy, disables autosave, and lays an isolated walkable floor at exact lattice centres. It does not alter the authored layout. Press H to hide/show controls; the saved screenshots hide them so all swatches remain visible.

Run the generator, fixture reproduction, native suite, Web export, then `scripts/ci/smoke/terrain-junctions-probe.mjs`. See the job report and saved browser `result.json` for executed checks. Runtime auto-placement acceptance belongs to Aki after consuming this handoff; an art preview alone does not establish that PR245 is fixed.
