# Blightwood bridge kit — art handoff

**NOT LIVE — awaiting gameplay integration.** This PR supplies art and an isolated native render tool. It does not change the map, builder, collision, navigation, camera or player movement.

## Contents
- Three lengths: **4 / 6 / 8 logical tiles**, all **2 tiles wide** on the existing **72x36 diamond grid**.
- Two diagonal axes: `u=(36,18)` and `v=(-36,18)`.
- **13 modules:** repeatable intact/damaged deck, start/end half-tile end caps for each axis; timber and rope rails for each axis; one support post.
- **18 assembled examples:** three lengths x timber/rope/damaged x two axes.
- **72 separate layers:** supports, rear rail, deck and front rail for each example.
- All output PNGs are RGBA with binary transparency, nearest filtering and the same 36-color palette sampled from existing Blightwood wooden-post and grass assets.
- Fixed **448x304** assembly canvases, no subject fit-to-cell scaling. Longer bridges add length while width, posts and rail height stay constant.

## Placement contract
The authoritative machine-readable file is `assets/environment/blightwood_bridges/bridges.art.json`. Sockets are local image coordinates. To position an assembly's start at a world point, subtract its `start_socket` from that point. The end socket is exactly `length_tiles * basis` away. Place subsequent decks at that socket.

For `u`, the two deck-bank corners around the centerline are `(+36,-18)` and `(-36,+18)`. For `v`, mirror the x offsets. Width is 2 logical tiles. Half-tile end caps extend the surface by 0.5 tile; their top vertex `anchor` is supplied. Deck repeat modules cover 2x2 logical cells. Allow rails/posts to overlap the deck edge by their natural pixel outlines.

`support_post` has its deck attachment at `(12,44)`, upper rail attachment `(12,12)` and base `(12,84)` in its 24x84 canvas. Supports extend below the deck. Rail segments span `(72,36)` in `u`; mirrored `v` endpoints use `(-72,36)`. Endpoint coordinates may lie on the boundary just outside the last pixel; use their geometric offset, not image-center snapping.

## Layering / gameplay handoff
Use separate PNG layers for final integration. The composed PNGs are convenient art previews and thumbnails; they cannot provide correct actor occlusion alone. Split/reparent near and far supports as needed when integrating actors. Render support undersides and far rail behind actors, deck below feet, front rail in front of actors where appropriate. The correct dynamic depth strategy belongs to the existing world/camera integration.

Aki should define traversable deck bounds, rail collision, entry/exit elevations, accessible bank placement and water masking before calling bridges playable. **No traversal or collision claim is made by this art delivery.** The damaged gap is visual only; do not infer fall damage or blocked cells from alpha. The rope variant retains timber deck and support posts.

## Generation / reproducibility
Raw art was created with **built-in image_gen**, not PixelLab. PixelLab API instructions and configured service were reviewed; balance checked successfully without exposing credentials. Built-in generation was selected for coordinated modular materials. Three raw outputs are preserved under `source/`, together with cleaned sources and processor QC. The first rope in the accessory atlas was too close to its image edge and was replaced with a fully contained standalone rope generation.

The final prompt set requested: (1) an intact and broken overhead wooden bridge-deck texture, two wide rows, weathered mossy wood and iron nails on flat magenta; (2) an upright square support post plus separate diagonal timber and braided rope rail spans, Blightwood sampled forest tones, flat magenta; (3) a replacement complete rope handrail with two sagging braided ropes, vertical knots and generous margins. Full prompts are preserved in `prompt-set.txt`.

`build_kit.py` performs magenta cleanup, removal of a detached neighboring rope fragment, palette mapping to sampled existing colors, nearest-neighbor resizing, affine deck projection, rail slope alignment, mirrored axes and bitmap composition. All visible bridge material pixels originate from generated artwork; code draws no creative bridge geometry. The original magenta sources are excluded from Godot imports with `source/.gdignore`.

## Verification
Run from the repository root using the installed Python runtime with Pillow and NumPy:

```
python docs/visuals/blightwood-bridges/build_kit.py
python docs/visuals/blightwood-bridges/check_kit.py
godot --path . --script res://tools/shot_blightwood_bridges.gd
```

The last command imports actual textures and saves `godot-render.png`. `contact-sheet.png` is a labeled presentation of delivered bitmaps. There are no requested bridge animations; static props have one frame and zero FPS metadata. No PixelLab generations were consumed.
