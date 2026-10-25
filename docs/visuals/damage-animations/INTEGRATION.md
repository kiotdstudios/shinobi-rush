# Damage animation integration notes — Player and Bandit

## Delivered art
Both manifests now include `hit_react` (8frames), `knockback` (12frames), and `death` (16frames) in S/SE/E/NE/N/NW/W/SW. Every frame is native128x128 RGBA with anchor64,116; no resampling, floor shadow, weapon or baked effect. All48clips/576frames have unique frame hashes within their clip. See each character's damage/damage.art.json for frame counts, timing/event recommendations, source jobs, frame hashes and bounds.

24FPS is the nominal authored art clock; half-speed review is12FPS. Durations are0.333/0.5/0.667seconds before gameplay retiming. All three actions are non-looping. Death ends fully prone and holds frame15 indefinitely. Recovery-ready recommendations are the last2frames of hit/stagger. Incoming impact is frame0; these are reactions, with no offensive hitbox-active frames.

## Binding guidance for Aki
Art is present in the main manifests and an isolated browser review. Gameplay binding is deliberately still pending. This delivery does not change HP, damage, movement, hitstop, AI, substitution, respawn or death policy.

- Choose the frame direction from the actor's retained facing. The knockback vector is independent of facing. Each heading is literal art; no mirroring/fallback is needed.
- Sample SpriteActor.show_animation_at using normalized progress from existing timers, preserving gameplay timing. Bandit HIT_REACT currently lasts0.22seconds; the art's nominal24FPS does not replace that timer.
- Ordinary hits can use hit_react; stronger knockback can use knockback with world displacement controlled by the existing physics. The artwork includes bracing footwork, but exported root motion is zero. Review's Travel button is a demonstration only.
- Hide the KunaiWeaponVisual/trails when showing damage art so no stale weapon hangs in the old hand position.
- BanditVisual currently hides its art in DEAD and freezes the previous body during HIT_REACT. Binding these new clips needs a visual hook, including suppressing the old procedural death fallback.
- PlayerController.take_hit currently emits downed and calls respawn immediately at zero HP. A visible pre-respawn death interval requires an explicit gameplay integration decision; this art PR does not silently delay respawn or alter persistence rules.
- On death, keep facing stable and hold the terminal pose. Do not call a looping locomotion update or restart a completed one-shot each frame.

## Review
Canonical game with ?damage=review after deployment. All16actors can be inspected together; heading buttons give a native3x enlarged view of both characters. Normal/Half speed, Pause, Step and Replay are provided. Death holds at the end; Replay explicitly starts again. Preview GIFs replay for inspection; production clips are non-looping.

## Source / QC
PixelLab animate_image was seeded from approved actual in-game idle frames, avoiding animate_character's automatic canvas expansion. Original source frame0 is preserved and verified pixel-identical to the approved idle input; production uses generated frames1..N. Raw/rejected versions are retained under each damage/source/.gdignore. Three edited prone endpoints were aligned by whole-pixel translation only before pinned-endpoint animation. Four rejected death clips and two unwanted-white-streak knockbacks were replaced before delivery. See queue.json/state.json and pilot/motion receipts for provenance. No secrets recorded.
