# Blightwood riverbank starter section

An editable composition based on the owner's forest waterfall reference, assembled from existing game assets. It is a starter section rather than a pixel-identical recreation of the concept image.

## Open and build

After this branch is integrated/deployed, open `?cliffs=river&map_editor=1` on the canonical game. The assembled map and editor open together. The **Blightwood Cliffs** category contains the connected terrace/stair/waterfall pieces. Select to move; Erase to remove; Ctrl+Z/Ctrl+Y for history. **Playtest** opens your edited section, including your spawn marker. File Save exports the layout for reuse; keep that JSON when editing a review preset. Ordinary saved worlds are separate.

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

The exact red/blue hanging banners, matching small fern/bush clusters, hanging cliff vines and densely fractured stone columns in the concept image are not all standalone matching catalog pieces. This map uses current weathered cliff faces, grass and existing decorations. No substitute logos or new raw artwork are introduced. Those decorative art gaps can be authored later; they do not block the usable stair/river/cliff composition.

## Verification

Actual game/editor screenshots and browser probe results are in `gameplay/`. The job report records native, resource, export, browser and deployment results. Normal worlds, existing engineering demo, terrain auto-blending algorithms, combat and camera controllers are preserved.
