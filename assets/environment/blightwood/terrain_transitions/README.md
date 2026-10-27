# Missing flat terrain transitions

Seven families, **308 registered native 72×36 RGBA PNGs**, anchor **(36,18)**; 44 distinct images per family. Pure material pixels are intentionally shared across different families, with no redundant B/C pure-fill variants within a family. Existing palettes and exact source pixels; no new raw art, rescaling or interpolation. `transitions.art.json` records provenance, hashes, IDs and corner meaning for every family.

| Family | Unset corner (0) | Set corner (1) |
| --- | --- | --- |
| grass_path | olive path | grass |
| grass_temple | temple stone | grass |
| dirt_temple | temple stone | brown dirt |
| grass_rock | rocky fill | grass |
| dirt_rock | rocky fill | brown dirt |
| temple_rock | rocky fill | temple stone |
| grass_dirt | brown dirt | grass |

Bits: bottom=1, left=2, right=4, top=8. Each family has all 16 masks: pure 00/15 only A; mixed 01–14 A/B/C. Select A for pure fills. Nine-role aliases are unnecessary: the editor exposes all masks directly. Full opaque floor diamonds, transparent exterior, binary alpha, nearest filtering, no mipmaps or collision. These are **flat-floor surfaces**, never cliff faces or height transitions.

Two native boundary pixels follow a shared material signature. Every compatible pair of masks/variants agrees at shared edge samples (976 checks/family, 6832 total). Contours vary only in the interior; all colors remain exact existing material colors. Source grass padding is sampled at its registered floor region; existing 112×112 grass files and their overhang are untouched. This new reusable corner family does not replace PR226's authored natural clearing or PR230's path/dirt set.

Builder: separate named categories for each family. Standard place/select/move/delete/undo/redo/save/reload. No automatic map painting or modifications to AutoTile: pair selection remains manual until Aki's material identity/blending task is implemented.

Build/check: `python scripts/art/build_remaining_transitions.py`. It writes only the new assets/manifests/previews and the clearly marked generated catalog/category additions. Source PNGs are never modified. Contacts and connected examples: `docs/visuals/terrain-transitions/`. Actual in-game demonstration: `?terraintransitions=review`; switches seven families, includes all 16 masks and brown shoreline swatches; nonpersistent, autosave disabled.
