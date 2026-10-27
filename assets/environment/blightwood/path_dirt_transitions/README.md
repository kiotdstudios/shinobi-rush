# Existing ground/path → brown dirt

Companion to PR226's grass-to-dirt work. These pieces blend the actual **Ground / paths** material into brown earth, without adding grass blades or replacing the original source art.

- Native canvas/logical diamond **72×36**, anchor **(36,18)**; nearest filtering, no mipmaps.
- **16 corner masks × 3 variations** (`path_dirt_00_a` … `path_dirt_15_c`). Full diamond coverage; transparent outside only; no collision.
- Nine familiar role aliases in three variations, supplied for integrations that use a nine-piece set.
- Builder category and checkbox: **Path to dirt**. Standard floor paint, move, delete, and persistence.

Mask convention matches shoreline **corners**, not the old brown pack's exposed-side bits: bottom=1, left=2, right=4, top=8. A set corner is dirt; an unset corner is original ground/path. Mask 0 is pure original ground; mask 15 is pure earth. Adjacent tiles must agree on their shared corner materials. The nine aliases are documented in `path-dirt.art.json`; additional masks support inner bends and split transitions.

Corner blending is continuous across matching seams; interior irregularity differs between A/B/C. The final image uses only exact existing ground and soil pixels, never a blurred alpha ramp. The two pure-fill masks deliberately have identical A/B/C pixels. No old material is overwritten and no saved map is automatically repainted.

Build: `scripts/art/build_path_dirt_transitions.py`. Source paths and SHA256 values are in the manifest. Pixel-level compositing edits existing art; no new raw art or palette was generated.

Preview: `docs/visuals/path-dirt-transitions/contact-sheet.png` and `blend-layout.png` are asset sheets. `?pathdirt=review` is an opt-in floor demonstration **inside the actual game**, with the real player and builder. It paints a temporary 121-cell demonstration and disables autosave; ordinary play/maps are unchanged.

Live state is recorded in `orders/Codex/reports/2026-10-26-path-dirt-transitions-report.md`; an unmerged PR/local Web demonstration is not the shared live game.
