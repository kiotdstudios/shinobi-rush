# Automatic multi-material terrain blending

Implements `orders/Aki/2026-10-27-automatic-multimaterial-terrain-blending.md` (PR #244).

- `scripts/editor/terrain_blend.gd`: material identity (grass, ground, dirt, temple, rock), all 10 (zero, one) families from PR #230 / #240 / #248 and all 360 exact three-material signatures, corner bits bottom=1 left=2 right=4 top=8, deterministic A/B/C variants.
- `scripts/editor/auto_tile.gd`: `blend` mode. Vertex-based: each painted cell owns a material, each shared corner takes the minority owner (thin trails/islands survive), ties go to priority rock > dirt > ground > temple > grass. Local 25-cell retile per painted cell.
- Ownership is stored in `PlacedObjects.cell_mat` (saved as an optional `"mat"` key per floor item, undo/redo aware). Maps without it are never touched on open; legacy pure tiles join blending only when a deliberate edit touches their neighbourhood; mixed legacy / hand-placed tiles are pinned.
- Builder: DIRT and ROCK brushes, AUTO BLEND toggle (default on), LOCK TILE (manual override, saved).
- Proof sheet: `blend.png` / `blend_zoom.png` (tools/shot_terrain_blend.gd, real game, 1280x720).

Current proof: `?autoblend=review` exercises actual material-brush logic for all ten pairs and ten triples, with 121-cell fields, undo/redo, save/reload and real pointer painting. The original blend.png screenshots are historical pre-integration evidence.

Art-limited: four distinct materials inside one diamond have no authored kit and use deterministic pair fallback; they are not claimed seam-free. All three-material combinations and both previously missing pairs are now covered. Cliff/stair/waterfall are untouched. Explicit variant reroll remains a future enhancement.
