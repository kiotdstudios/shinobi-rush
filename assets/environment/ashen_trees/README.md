# Ashen Ruins — volcanic tree set

Three original barren tree silhouettes for Haigakure, the Village Hidden in the Cinders: sentinel, wind-bent and split-trunk elder. Cool charred slate bark, deep molten-red root cracks and restrained orange cores. They share the existing Blightwood320×448 canvas with root anchor160,416 and stand approximately384px tall. No floor tile, baked shadow, leaves, logos or map geometry.

## Motion and separation
-96wind phases /24FPS /4seconds: nearest-sampled branch deformation of original pixels. These are shader poses, not96hand-painted full-tree PNGs. Root area from sourcey346down is geometrically fixed.
- Molten source pixels in lower150px pulse through8brightness steps on a4second cycle. Cold bark remains unchanged. Each tree has a different phase and strength.
- Separate128×128ash atlas:16distinct32×32tumbling charred-flake poses.6FPS tumble,8second drifting/curling/fading life.24reused sprites per tree,72for all three. No unbounded spawning. Ash, wind and root heat can be controlled separately.

`AshenTree` is a standalone Node2D component. Assign one manifest tree record to data before adding it to the scene; position is its root/ground anchor. Call advance(clock,wind_on,ash_on,heat_on) from the owning scene. Preserve nearest filtering. Put the node in the same Y-sorted parent as actors/props. It does not create collisions, navigation, camera or AI behavior.

## Review
Open scenes/art/ashen_trees_review.tscn in Godot. It is intentionally not connected to game startup. Review includes all three trees, approved128px player for scale, optional Blightwood comparison, gameplay-zoom view, clock, normal/half speed, pause/step and independent wind/ash/heat toggles.

Normal and half-speed GIFs under docs/visuals/ashen-trees/ are192actual Godot Web render captures over8seconds source time, not a simulated Python wind animation. Half speed runs16seconds. Source generation used built-in image_gen, separately per tree and one coherent ash sheet. PixelLab access/budget/tool capabilities reviewed; no paid PixelLab requests used for this set.

Reproduce PNG exports with docs/visuals/ashen-trees/export_art.py; isolated Web review setup with prepare_review.py; browser-proof.mjs captures actual Web rendering; make_previews.py packages captures. Source images preserved under source/ and excluded from runtime imports. Root/branch pixel comparisons and renderer controls are documented with validation JSONs. Art review delivery; not placed in live world or builder yet.
