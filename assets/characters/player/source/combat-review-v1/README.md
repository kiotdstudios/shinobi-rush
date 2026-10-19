# Combat source work in progress

Inventory and proposed animation IDs were published in PR31 and linked from Aki's PR20 before the first generation. jobs.json records exact PixelLab jobs. Character animations in this folder are experiments, not production assets or owner-approved clips.

Tool choice: PixelLab preserves the existing character/source pipeline. Fast Pixen ready-pose edits often rotated cardinal/back views toward southeast; rejected for those directions. The controlled four-frame Pro edits retain all eight directions and are candidate armed start poses. The katana addition is authorized by the new Combat Art Pack V1 owner instruction.

First MiniMax opening slash was rejected for a baked white trail at frame5 and long ending hold. A separate frame5 correction removes the trail; a V3 motion test requests progressive distinct poses and a thin physical blade. Do not copy the rejected frames into production or use the inspection GIF as a runtime asset.

No contacts, hitbox frames, cancel windows or combat playback FPS have been agreed with Aki yet. These cannot be labeled gameplay-approved. Do not apply the movement animations' half-speed preference by default.

Fixed 128×128 export must preserve original104px anatomical scale, use a common translation based on the reference padding (no per-frame recentering, scaling or truncation of sword pixels), and pass visual QA before manifest integration. Source generated canvas can exceed128 because PixelLab pads it; that does not authorize larger production character frames for this order.
