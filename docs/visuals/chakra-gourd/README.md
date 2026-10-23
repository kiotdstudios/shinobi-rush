# Blue chakra gourd — PixelLab art review

Blue/teal glazed double gourd with worn gold cracks, brown cork and red braided cord/tassel. The existing red health gourd supplied the native pixel scale/style; the owner's blue ceramic reference supplied material and ornaments. No labels or logos are added.

The body was created with PixelLab Pixen and animated with PixelLab pixel tools: a palette-preserving�1.4degree rigid sway at14FPS. This avoids detail flicker or ceramic morphing. Glow and all nine spark frames were recolored with PixelLab's exact `map_colors` operation, so their pixel geometry and alpha are identical to the health pickup. Raw generated alternatives are retained in the Godot-ignored source folder; the comparison-style generated glow and bubble-like generated spark alternative are not used.

## Files and timing

`assets/pickups/chakra_gourd/chakra_gourd.art.json` lists body and independent glow/spark frames. Use body14FPS; effects12FPS; spark frames ping-pong. Match HealthGourd's56px hover,4px rounded bob at2.3rad/s, breathing3.1rad/s, glow rotation0.35rad/s and scale1.25–1.55. Blue floor pool/beam presentation is specified in the manifest. Effects blend additively; the body uses normal alpha.

Keep native scale. Frame canvas padding does not change world-space object size. The existing health gourd is46×78; this body keeps its painted scale on a48×80 transparent canvas. A closing key identical to the input is omitted if present to avoid an extra hold at the seam; original generated frames remain in source/body.

## Review

Open `review.html` through a static server at the repository root. It defaults to half speed and provides normal speed, pause, stepping,2× detail and actual0.665gameplay scale. `normal.gif` and `half-speed.gif` compare health and chakra effects side by side. Preview clock wraps after six seconds; runtime layers use independent continuous clocks like the health pickup. `contact-sheet.png` shows every body key.

This delivery is a separate art pack for review. The existing health pickup, player chakra-charge effect and gameplay controllers are unchanged. No new pickup restoration amount or spawn behavior is introduced. Live game deployment is not applicable to unbound review art.
