# Blue charge V2 — owner-reference candidate

The downloaded source is a288×32 transparent strip: nine32×32 frames. This candidate follows its upward curling motion in blue-white, with96 distinct generated drawings and256×256 transparent VFX cells. Detail is increased through finer nested strands, shaded blue ribbons and rising glints; “10 times more detailed” is a creative target, not a measured aesthetic score.

| Sequence | Frames, zero based | Authored playback |
| --- | --- | --- |
| Buildup |0–15|24fps,0.667s|
| Sustained charge |16–79|24fps,2.667s repeating|
| Release |80–95|24fps,0.667s|

Half-speed previews run at12fps. Complete sequence is4s normal or8s half speed. The PNGs contain the VFX only. Body composites use the approved SE idle as a scale reference; they do not revive or approve the previously rejected charge-body animation. No gameplay/controller/camera files or production charge binding are changed.

Open `review.html` through a local HTTP server for normal/half speed, pause, single-frame stepping, scrub and continuous-charge mode. `character-preview-half-speed.gif` shows the full sequence over the existing idle; `effect-preview-half-speed.gif` shows VFX alone. Sustain-only half-speed versions isolate the repeating phase. `contact-sheet.png` identifies every frame.

Assets: `assets/vfx/chakra_charge_blue_v2/frames/`, `sheet.png` (8columns×12rows), `manifest.json`. Root is(128,224). Place the256px texture at character-foot position minus this anchor. Effects deliberately extend beyond the128px body canvas. Keep the native256px scale initially; align the root before adjusting camera presentation. Body remains separate and unchanged.

Original reference and raw generated sources are preserved under ignored `source/`. The raw art comes from built-in image generation, not procedural drawing. Processing removes the flat magenta background, extracts fixed grid cells, applies nearest sampling and a uniform translation per sheet. It does not generate tween frames or pad frame counts with duplicates. Early drafts with cross-cell tips were rejected and regenerated with a repeated art/anchor template. PixelLab documentation/access were reviewed; PixelLab was not used to generate this candidate.

This is an isolated art review package. Production chakra integration and charge-body animation remain paused pending owner feedback on the replacement candidate. Live deployment is not applicable: no runtime scene/script references these assets.
