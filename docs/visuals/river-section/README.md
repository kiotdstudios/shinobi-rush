# Blightwood riverbank starter section

An editable composition based on the owner's forest waterfall reference, assembled from existing game assets. It is a starter section rather than a pixel-identical recreation of the concept image.

Verified live on `9bf429cd29ef859918725549b73b325500ef8c6c`: [Open editor](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&map_editor=1&v=9bf429cd) · [Play section](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&editor=1&v=9bf429cd). All 27 exact-build live checks passed with zero errors. [Live editor screenshot](live-editor.png) · [Live overview](live-overview.png) · [Live result](live-result.json) · [Deployment checks](deployment-checks.json) · [Native results](native-result.json).

## Open and build

Open `?cliffs=river&map_editor=1` on the canonical game. The assembled map and editor open together. The **Blightwood Cliffs** category contains the connected terrace/stair/waterfall pieces. Select to move; Erase to remove; Ctrl+Z/Ctrl+Y for history. **Playtest** opens your edited section, including your spawn marker. **Download** exports your edited JSON for reuse; keep that file. Save writes the separate review file. Opening the starter link again starts from the template; Playtest uses your edited snapshot. Ordinary saved worlds are separate.

The source map is [blightwood-river-section.json](../../../world/demos/blightwood-river-section.json). It uses the existing version-5 editor format. The matching runtime copy lives in `assets/environment/blightwood/cliff_kit/river-section.json`. Rebuild both with `python scripts/art/build_river_section.py`.

## Existing pieces used

| Reference feature | Available implementation |
| --- | --- |
| Raised mossy bank and corners | Connected cliff grass/path cells, one native 66px elevation tier |
| Left stair / alternate approach | Both existing SE and SW stairs, attached to the same walkable terrace |
| Flowing upper stream / waterfall | Existing animated river, lip and independent cascade/foam/droplets |
| Lower catch pool / outflow | Existing grass-shore corner transitions and flowing water |
| Worn lower trail | Existing brown dirt/grass transition family |
| Dense grass | Existing native grass art and shared wind materials, including elevated edge fringes |
| Forest dressing | Existing blossom trees, rocks, lanterns, fireflies and fence pieces |
| Water plants | Existing waterlife system supplies nearby lily/lotus variations under its normal rules |

## Remaining visual gaps

Matching small fern clusters and hanging cliff vines are now supplied by the [foliage batch](../vines-ferns/README.md), with six vines and nine fern placements in this starter. The exact red/blue hanging banners and densely fractured stone columns remain decorative gaps; they do not block the usable stair/river/cliff composition. The live verification above records the original starter revision; the foliage report tracks its subsequent deployment.

## Verification

Actual game/editor screenshots and browser probe results are in `gameplay/`. The job report records native, resource, export, browser and deployment results. Normal worlds, existing engineering demo, terrain auto-blending algorithms, combat and camera controllers are preserved.
