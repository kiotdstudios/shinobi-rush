# Premium Body Flicker — integration and visual review

The normal player dodge and the bandit's evade/retreat now use the same presentation component, `EvadeStreakFx`. It observes existing state, counters, timers, velocity and reached positions. It never changes input bindings, body position/velocity, hitboxes, invulnerability, dash-attack windows, cooldowns or AI choices.

## Review
`?flicker=review` runs real PlayerController/Bandit movement in an isolated collision test stage. Buttons select all eight directions, player/bandit, wall, before/after, normal/half speed. The clock and phase are visible. Half speed changes only the review scene's Engine time scale and resets on leaving. The main game runs at its existing speed.

`?camera=close&kunai_inspect=1` exposes read-only animation/effect state for real keyboard tests in the actual game. `&flicker_before=1` explicitly enables the old six-frame player streak presentation for a controlled comparison; ordinary gameplay never enables it. Existing SE Animation Lab proofs remain historical prototypes and are not the new production dodge.

## Art / frames
This is a presentation improvement built from approved art, **not a regenerated character library**. No new PixelLab or image-generation jobs were used. The player's 12-frame, 128x128 dodge already contains bent-knee launch, low travel and landing/recovery poses in all eight literal directions. The new component selects these poses from gameplay progress instead of leaving a slow free-running or idle frame through the burst. The bandit uses its own bent-knee run and arms-back sprint frames; player textures are never substituted for its red-scarf design. Foot anchor remains `(64,116)` and no body scaling/stretching is applied.

Separate reusable components:
- Three stationary afterimages, actual texture/frame/transform snapshots; maximum three visible at once, 0.13-second life. New samples require at least 16 world pixels of real movement and 0.027 seconds. Positions are never extrapolated/interpolated toward a desired endpoint.
- A brief white silhouette highlight; crisp, quantized silhouette multiples/scanlines form a narrow smear without scaling the body.
- The existing six authored directional streak frames, recolored through a discrete white/pale-blue/blue-gray shader and rotated to the actual heading.
- Existing authored `skid_a` ground dust fixed at the launch position; a compact `ring_a` displacement at the actually reached endpoint. The silhouette smear contracts over 45 ms at arrival.

New machine-readable component/pose metadata is `assets/vfx/body_flicker/premium.art.json`. Original textures and manifests are retained; the shared shader is `premium_silhouette.gdshader`.

## Timing / safety
The brief's suggested 0.38-second sequence does not override existing gameplay. Player dodge remains **0.30 s** with **0.20 s** movement; bandit evade remains **0.20 s**, with retreat hops driven by its profile. Visual phases compress to these timers. Launch pose occupies the first 12%, burst to 40%, travel until the movement window ends, then landing/recovery. Particles may finish for up to 0.14 s afterward, granting no extra gameplay protection.

Movement remains immediate. The component samples only positions reached by `move_and_slide`; a stopped body emits no additional path samples. A collision-shortened arrival uses that location, not the requested dodge distance. Teleport-sized discontinuities cancel the effect instead of bridging a gap. Separate evade/hop identity avoids collisions between counters with equal numeric values. Repeated presentation calls reuse the current instance; a new action clears old transient sprites. Damage, death, dash-attack cancellation and scene destruction cannot leave the actor hidden. Local hitstop pauses the effect without mutating gameplay timing.

The body stays visible and opaque; only the independent silhouette snapshots fade. No smoke teleport, body stretching, camera shake or glow ball was added. Streaks remain decorative; collision/hitbox authority stays entirely in the existing controllers.

## Verification / recordings
`browser-proof.mjs` verifies both actors' eight directions, actual wall stopping and sample bounds, before/after controls and half/normal playback. `gameplay-proof.mjs` uses real keyboard events in the normal game and records both presentations. Captures contain actual Web frames, not generated in-betweens. WebM videos are silent, compressed using the bundled FFmpeg VP9 encoder; GIFs use actual measured screenshot intervals and a shared non-dithered palette.

`tests/test_body_flicker_premium.gd` covers octants at three action speeds, exact sprite identity/anchor/scale, stationary samples, real wall and rounded-obstacle collisions, duplicate triggers, dash-attack interruption, retreat hop counter identity, opacity and teleport cancellation. Existing health/evade, combat, bandit chase and robber tests remain active.

The historical distance assertion at exactly 90% of a discrete dodge distance received a **0.01 px floating-point tolerance**; an observed 134.9992 px used to fail against a strict 135 px comparison. No movement tuning changed.

See the job report for exact pre-commit/native/Web/live test results and the verified deployed SHA. Until canonical deployment verification is recorded, status remains REVIEW rather than DONE.
