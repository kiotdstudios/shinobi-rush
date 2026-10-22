# Five owner-reference blossom trees

The five original source silhouettes are retained: tiered, windswept, weeping, branching and sparse. Each texture is a **320×448 RGBA canvas at the source's native pixel scale**; trees were not reduced to the character's 128px canvas. Rocks and original ground petals are part of each source design. The white JPEG background is removed; antialias pixels along its boundary are decontaminated. Interior RGB is preserved. Source and deterministic extractor are included.

`blossom_trees.art.json` records source rectangles, shared canvas, individual ground anchors, checksums, phase/strength and 24 sampled canopy emission points per tree. Nearest filtering and zero mipmaps preserve fine clusters.

## Animation

Each tree uses a **96-phase, 24 FPS, 4-second** wind loop. These are runtime shader poses of the exact texture, **not 96 newly painted PNGs**. Bounded UV deformation bends upper branches/canopies and adds local tip flutter; lower 70px of the trunk above the root, rocks and base remain fixed. Five phase/strength settings avoid synchronized motion. At most 7px horizontal and 1px vertical displacement fits transparent margins. The loop is periodic, with no first-frame duplicate or abrupt root translation.

The full source texture stays detailed and compact instead of packing 480 near-identical large tree frames into Web memory. A 96-frame capture from the actual Godot Web shader documents the loop. Animation clock is controlled by `BlossomGrove` so pause, frame step and half speed affect the complete art view consistently.

## Falling foliage is separate

`assets/vfx/falling_foliage/` contains independent pink petal and blue-lavender leaf tumble sheets, **16 distinct 32×32 poses per sheet**. They were made with built-in image generation, then fixed-grid nearest extraction/alpha cleanup. Source sheets and metadata are preserved. No paid PixelLab generation used.

`FallingFoliage` is an independent node/component: sampled canopy birth points, slow downward travel, side-to-side sway, per-particle tumble, curl and ground fade. 6–10 second lifetimes, 1.8 births/sec/tree, hard pool cap24/tree (120 for the five placements). Hidden leaves finish their lifetime safely; there is no unbounded pile of particles or nodes. Turning tree wind off does not stop leaf motion. Turning leaves off does not stop tree sway.

## Placement and review

`scenes/arena/training_arena.tscn` adds one nested Y-sorted decorative grove. Five trees occupy the courtyard's west side; the spawn, normal control-probe lanes, Bandit route, walls, combat and navigation remain unchanged. These are **nonblocking decorative props**; this art delivery does not add collision/navigation obstacles. All normal startup trees animate by default. Existing player/AI/camera controller sources were not changed.

Open `?trees=review` for All five / individual native-scale tours, normal / half speed, pause / step, independent wind / leaf toggles, and Follow player. Only this optional art view hides diagnostic layers and supplies its own review camera. Normal gameplay camera and Animation Lab remain unchanged. Feet are sorting anchors, so canopy is in front of actors behind a tree and behind actors in front of it.

## Reproduction

From the repository root, using Python with Pillow and NumPy:

```
python docs/visuals/blossom-trees/extract_reference.py
python docs/visuals/blossom-trees/export_foliage.py
```

PixelLab's read-only capability review found object animation may redraw the reference and limits native object/custom-frame scale below these ~370px trees. Source extraction plus a non-destructive Godot wind rig was chosen to honor the owner's exact designs. PixelLab account secrets were not printed and no paid jobs submitted.
