# Automatic multi-material terrain blending

Implements `orders/Aki/2026-10-27-automatic-multimaterial-terrain-blending.md` (PR #244).

- `scripts/editor/terrain_blend.gd`: material identity (grass, ground, dirt, temple, rock), the 8 (zero, one) families from PR #230 / #240, corner bits bottom=1 left=2 right=4 top=8, deterministic A/B/C variants.
- `scripts/editor/auto_tile.gd`: `blend` mode. Vertex-based: each painted cell owns a material, each shared corner takes the minority owner (thin trails/islands survive), ties go to priority rock > dirt > ground > temple > grass. Local 25-cell retile per painted cell.
- Ownership is stored in `PlacedObjects.cell_mat` (saved as an optional `"mat"` key per floor item, undo/redo aware). Maps without it are never touched on open; legacy pure tiles join blending only when a deliberate edit touches their neighbourhood; mixed legacy / hand-placed tiles are pinned.
- Builder: DIRT and ROCK brushes, AUTO BLEND toggle (default on), LOCK TILE (manual override, saved).
- Proof sheet: `blend.png` / `blend_zoom.png` (tools/shot_terrain_blend.gd, real game, 1280x720).

Art-limited: no tri-material tiles (a 3-material vertex can show a seam, counted in the test), no ground<->temple or ground<->rock pair (falls back to a pure tile), cliff/stair/waterfall untouched. Reroll of variants is not implemented.
