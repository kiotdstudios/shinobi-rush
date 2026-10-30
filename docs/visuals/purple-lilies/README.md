# Purple ferns and water-plant recovery

Status: DONE — [PR261](https://github.com/kiotdstudios/shinobi-rush/pull/261) merged and canonical runtime `5a689112e7ce8c14444cd83ec412348b2dc8cd07` verified 2026-10-29T19:35:39.574Z. Main passed 5,209 native assertions, deployment and post-deploy smoke. **16 live feature checks pass, zero errors**.

[Open foliage editor](https://kiotdstudios.github.io/shinobi-rush/?cliffs=river&map_editor=1&foliage=1&v=5a689112) · [Live editor](live/editor.png) · [Live contact](live/contact.png) · [Settled on water](live/settled.png) · [Live results](live/result.json) · [Deployment checks](deployment-checks.json).

Three existing fern silhouettes now use the editable native Godot tint `#d27dff`. Production PNGs and PixelLab sources are unchanged; no bitmap regeneration or extra generation charge. Vines keep their original colors. The same manifest setting colors runtime sprites, editor cards, placement ghosts and copied stamps. Anchors, picking, transparent pixels and 96-phase sway are preserved.

[Purple fern normal preview](../vines-ferns/normal.gif) · [Purple fern half speed](../vines-ferns/half-speed.gif) · [Rendered poses](../vines-ferns/rendered-poses.png) · [Editor screenshot](gameplay/editor.png) · [Local browser result](gameplay/result.json) · [Native result](native-result.json).

## Lily and lotus interaction

`Waterlife` now reacts once when actual wet movement sweeps across a plant's 25×14px contact ellipse. A bounded sideways drift, 2.8–4px downward dip and slight tilt make the contact readable. Subsequent frames inside the same plant do not continually add impulses. Dry movement, standing, teleport-sized displacements, airborne/dead actors and different water elevations do not create new reactions. Existing movement/chakra rules supply eligibility; no controller rules are changed.

Each plant deterministically selects a return rate from 2.6–5.4 per second using its existing variant/phase. Exponential recovery is independent of rendering frame rate and continues while the player is idle or has left the water. Small offsets snap exactly to zero; normal low-amplitude bobbing then continues. Logical anchors never move. Draw position/depth are recalculated from the actual water tier, never from the player's height, so plants cannot accumulate lift or stay hovering after a tier change.

The real-player inspection route `?waterlife=play` has six reproducible pads/lotuses along the crossing. It uses real keyboard/gamepad movement, normal chakra costs and unchanged rarity. Production retains its existing water-based population and 12-plant bound. The staged art route `?waterlife=review` now runs through the plant row; Normal/Half/Pause/Step controls remain available. Its existing forced frog is isolated from production probability.

## Verification

Local feature browser proof: **15 checks pass, zero errors**. Actual keyboard running touches at least three plants with different rates, then all settle while the player remains on water with chakra available. A second crossing is bounded; recovery also completes after a real dry exit. Plant anchors, 32-slot splash pool and one roll per eligible visit remain unchanged. The native focused suite passes **91 checks**, including frame-rate independence, water-tier changes, dry/idle/teleport exclusions and no extra frog rolls.

Reproduce: `node docs/visuals/purple-lilies/browser-proof.mjs --serve-dir <fresh-export> --out-dir <evidence-dir>`. For canonical verification, use `--url https://kiotdstudios.github.io/shinobi-rush/ --expected-sha <merged-sha>`.

Native art QA: `godot --path . --script tools/capture_blightwood_foliage.gd`, then `python scripts/art/validate_foliage_render.py`. All six sprites move, attachment regions remain pinned and rendered colors match source×tint, allowing one 8-bit framebuffer rounding value for tinted pixels (untinted vines remain exact). [Rendered validation](../vines-ferns/render-validation.json).

[Water contact normal preview](normal.gif) · [Water contact half-speed preview](half-speed.gif) · [Normal MP4](normal.mp4) · [Half-speed MP4](half-speed.mp4). Recorded from the actual staged art scene using its Normal/Half controls; its existing forced frog remains preview-only. Production proof uses real keyboard movement with no forced rarity outcome.
