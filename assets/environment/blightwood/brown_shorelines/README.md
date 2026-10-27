# Brown soil banks — land-layer patch

Sixteen land PNGs and sixteen static editor thumbnails, native 72×36 RGBA, anchor (36,18). `brown-shore.art.json` records masks and source paths. Corners set=land, unset=water, same bits as existing shorelines.

Land alpha is exactly the existing dirt-bank alpha; visible RGB comes only from approved brown soil. Runtime water reuses the original `blightwood_shorelines/water_masks/dirt_NN.png`, surface atlas, clock, shader, animation and gameplay rules. No new water animation, geometry, swimming or chakra behavior. Thumbnails are static icons only; runtime water is animated.

Builder IDs `shore_brown_00..15`, category **Brown banks**. Old olive `shore_dirt_*` remains compatible. No forced change to old layouts or automatic bank chooser.
