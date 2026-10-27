# Natural Blightwood path revision

The original nine/16-role pack and rectangular illustration are retained as source/reference. **The runtime uses `natural-path-atlas.png`, not that rectangular illustration.**

The new atlas contains registered, fully opaque 72×36 floor diamonds on 112×112 canvases with anchor `(56,84)`. A continuous map-space mask rounds the authored dirt clearing and connections before the material is cut into cells. Existing generated soil is sampled continuously across diamonds; approved grass pixels supply the broken fringe, tufts and interior vegetation pockets. Darker soil occupies the transition band, with lighter compacted earth toward the center. No new palette or grass artwork was generated.

`natural-path.json` maps each atlas region to its authored world position and original terrain family. `NaturalDirtPath` changes presentation only when both match. Floor IDs, saved layouts, footprints, collision, stairs, navigation and prop positions are unchanged. Repainting a different material wins. Moving a tile refreshes its presentation; moving outside the authored region restores its original art. This is an authored-map treatment, not a procedural terrain generator. If the source map route changes, rerun `scripts/art/build_natural_dirt.py` and review the new atlas.

## Actual-game comparison

Open the normal game with `?path=review` for the new treatment, or `?path=review&path_before=1` for the unmodified main-map presentation. Both use the actual main scene, map, player controller and identical optional inspection camera `(0,80)`, zoom `0.72`. No replacement mockup scene is involved. Normal play keeps its usual camera.

`gameplay/before.png` and `gameplay/after.png` are Web-game screenshots at that camera. The before image shows the previously integrated green ground: the rejected rectangular **brown art** had not been integrated into main. Its separate old illustration remains `grass-blend-preview.png`, explicitly superseded by this revision. The screenshots must not be described as evidence of a previously published brown implementation.

The automated probe drives real keyboard movement after each capture and compares object/collision counts. `gameplay/result.json` records checks, state and time. `natural-path-layout.png` is only an asset-compositing inspection sheet, not a game screenshot.

Live status and exact test/build evidence are tracked in `orders/Codex/reports/2026-10-26-natural-dirt-path-report.md`.
