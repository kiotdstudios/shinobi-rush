# Bandit chase and evade audit

The owner-reported walk uses the existing **run** clip; there is no separate walk action. All 160 approved body frames remain 128x128, transparent, unique within each direction/action, anchored at [64,116].

## Runtime faults corrected
- SpriteActor intentionally resets on animation/direction changes. The enemy now retains normalized gait phase and subframe progress locally across running octants and run/sprint transitions. Player animation behavior is unchanged.
- Approach previously moved at160px/s versus player393.75px/s and never selected sprint. Bandit now uses470 chase /320 near approach, sprint hysteresis250/185px, and spacing deadband130/154px.
- Evade uses the current arms-back sprint, a separate generated dark-streak layer (6 frames,30fps,.20sec),640px/s lateral/away movement, full-path collider checks and1.25sec cooldown. Both blocked directions refuse a burst; damage still interrupts. No invulnerability or enemy attack added.
- L / R3 toggles target selection. It does not rotate or change the camera, steer the player, or alter combat hitboxes.

## Source-art observations
`run-before-contact.png` labels every source pose. `run-cycle-audit.json` measures silhouette difference, **not** perceptual quality. Several lateral/diagonal last-to-first seams remain stronger than internal transitions. Dropping frame0 did not improve these consistently and would remove gait poses. Frame order and approved body PNGs therefore remain unchanged; this delivery fixes live playback restarting and threshold chatter, rather than claiming a newly redrawn run cycle. `locomotion.gif` is runtime-speed source playback; `locomotion-half.gif` is half speed. Top row regular run, bottom row sprint.

## VFX provenance and processing
Original built-in image_gen six-cell 3x2 transparent sheet, generated2026-10-21. Prompt: original black/charcoal ninja lateral traversal streaks, small pale-gray edge accents; six phases buildup/burst/peak/fragments/dissipation; sharp stepped clusters; no body, logos, floor or shadow. Fixed512px cell crops sampled nearest to160px inside192px transparent canvases; alpha threshold100 and six grayscale values. No generated body replacements, morphing or blurred interpolation. Runtime rotates finished VFX to dodge motion. Metadata: assets/vfx/ninja_evade/ninja_evade.art.json.

## Integration
Only bandit AI/visual, separate PlayerLockOn helper/scene child, controls legend and additive read-only WebBridge diagnostics change. Kunai, player combat controller and camera systems remain untouched. See order/report for executed tests and live evidence.
