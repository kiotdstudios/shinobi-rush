# Aki handoff — modular sword proof

## Coordinates and layering
All body coordinates are native pixels from the128×128 image's top-left. Foot/root anchor is[64,116]. The attachment origin in actor-local space is `right_hand_px - foot_anchor`. The weapon texture's top-left relative to this mount is `-grip_pivot_px`. Rotate around the mount by weapon_angle_deg, positive clockwise in screen/Godot y-down space. Do not rotate around the weapon image center. Do not scale the player or change camera framing to fit weapons.

Both swords use the same right-hand track and grip pivot[14,32]. Their distinct curves, guards and handle colors are separate textures; the body references/hashes remain identical. Native weapon pixel scale1; no per-frame weapon-size changes. Use nearest texture filtering and no mipmaps.

Relative layers: weapon behind=-1, body=0, weapon front=1, primary-hand occluder=2, VFX=3. The occluder is the specified region of the SAME current body texture, copied at its original body-local position; no extra body art set is needed. Draw it after the weapon only when weapon_layer is front. Preserve actor-foot Y sorting for the whole assembly.

## Draw-order changes (zero-based)
- Light1: front frames0–1; behind2–3 during backswing; front4–7 for the cut/recovery.
- Light2: front0–1; behind2–7 while raised in front of the back-facing torso.
- Light3: behind0; front1–7 during the committed cut and low recovery.

Primary right-hand mount is curated per frame. Existing off-hand support gestures remain in the shared body; check off-hand clearance when introducing a different compatible hilt.

## Timing and events — recommendations, not gameplay approval
All clips have8 timeline frames at proposed24FPS. Playback is0.5× by default in art review only. Aki must map the data to the actual combat configuration, including hit-stop, movement and cancel behavior.

| Clip | Contact | Suggested active | Transition ready | Optional cancel |
| --- | --- | --- | --- | --- |
| light_attack_1 |4 |4–5 |6–7 |6–7 |
| light_attack_2 |1 |1–2 |5–7 |5–7 |
| light_attack_3 |2 |1–2 |5–7 |5–7 |

Fire gameplay contact/VFX events once on entry to the corresponding frame, with deliberate handling of time skipping, pause, restart and cancellation. Root movement and hitbox geometry remain gameplay-owned. Light/heavy trails are independent clips with their own pivot/timing metadata; they can be triggered, oriented and stopped separately. The art preview triggers recommended contacts only; it does not implement combat damage or movement.

## Migration and proof boundary
Keep the existing single-sprite rendering path and the baked_reference frames available while adding the attachment path. The current production manifest and847 unarmed movement frames are untouched. This art JSON is intentionally not named *.manifest.json, so SpriteLibrary does not auto-select it as a runtime replacement. The art harness renders both swords from the same body cache to demonstrate asset reuse; Aki must validate the engine layer, legal swaps, hitboxes, movement and live browser build.

Do not expand beyond SE or these two compatible swords before the proof passes review. Other weapon families may require different body choreography and grip tracks.
