# Blightwood hanging vines and fern clusters

Three hanging ivy silhouettes and three small fern clusters generated in PixelLab, using the exact opaque palette sampled from existing `grass9_center.png`. Transparent 128×128 native canvases; nearest-neighbor reduction and fixed alignment only. Raw sources, selected PixelLab object IDs and hashes are retained in `assets/environment/blightwood_foliage/source/` and `foliage.art.json`.

[Contact sheet](contact-sheet.png) · [Normal preview](normal.gif) · [Half-speed preview](half-speed.gif) · [Normal MP4](normal.mp4) · [Half-speed MP4](half-speed.mp4) · [Editor](gameplay/editor.png) · [Waterfall detail](gameplay/cliff-detail.png) · [Overview](gameplay/overview.png) · [Browser results](gameplay/result.json).

## Assets and alignment

| IDs | Variations | Attachment | Editor placement |
| --- | --- | --- | --- |
| `blight_vine_01`–`03` | Short ivy, curled ivy, dense ivy | Native top (64,12), drawn 66px above logical ground position | Place at the cliff base coordinate; top attaches to the existing one-tier cliff lip |
| `blight_fern_01`–`03` | Fan fern, spreading fern, curled fern | Native root (64,116) | Place on bank soil |

Sway uses 96 discrete shader phases at 24 FPS over four seconds, sampling whole source texels. These are shader phases, **not 96 individually generated drawings**. Vine displacement grows toward the free end; fern displacement grows toward the frond tips. Tops and roots remain pinned. PNGs retain the sampled palette, no baked glow, background or floor shadow. The review GIFs compress actual browser playback; the PNGs remain lossless production art.

## Editor and map

The **Blightwood foliage** object category and layer support placing, selecting individual visible leaves, dragging, erasing, undo/redo, visibility/locking and save/reload. Plants have no collision or navigation bodies. Vines retain their draw-order adjustment when moved. The riverbank starter adds six vines and nine ferns, leaving both stairs and the waterfall unobstructed. Its 134 elevated cells remain unchanged; 1,282 total objects load.

Use `?cliffs=river&map_editor=1&foliage=1` on the canonical game after deployment. This optional parameter selects the foliage category; ordinary cliff review links keep their previous category. Starter review storage remains separate from the normal saved world.

## Reproduction and verification

Run `python scripts/art/build_blightwood_foliage.py` then `python scripts/art/build_river_section.py`. The first verifies native source dimensions, binary alpha and sampled palette before exporting; the second rejects fern roots placed in water. `tests/test_blightwood_foliage.gd` adds 45 focused checks; the combined foliage/cliff native run passed 107 assertions. Local actual Web editor probe passed 13 checks with zero browser or engine errors. Deployment and exact live verification are recorded in the job report.
