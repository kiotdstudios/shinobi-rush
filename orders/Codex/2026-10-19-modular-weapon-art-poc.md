# ORDER — Modular weapon animation art proof of concept
- Agent: Codex
- Owner: Codex (art); Aki (programming)
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/modular-weapon-art-poc
- Dependencies: Aki attachment/event schema and gameplay integration

## Objective
Prove interchangeable swords can share one weaponless body combo. Owner revision supersedes full eight-direction combat-pack expansion until this proof passes visual review.

## Context / References
Owner's Modular Weapon Animation System instruction; approved128×128 player; southeast sword combo being closed out as the fully drawn comparison; existing camera/art direction and art skills.

## Scope / Files owned
One character, SE direction only, three-hit combo, two visually distinct one-handed sword assets, per-frame hand anchor/orientation/draw-order metadata, separate trails, art comparison harness and reports. Preserve all847 movement frames. No gameplay controller, combat state machine, camera edits or additional weapon families/directions. Aki owns engine attachment implementation, event/hitbox synchronization and family profiles.

## Deliverables
Weapon audit; native128 transparent weaponless body frames; separate swords at same pixel scale; per-frame primary-hand coordinates, weapon orientation and draw order; hand occlusion data if required; independent VFX; comparison to baked katana; tested art handoff PR and Aki notes.

## Acceptance Criteria / Tests
Same body files serve both swords with no replacement body library. Foot anchor[64,116], consistent proportions, clean alpha/crisp pixels, believable grip, frame-continuous weapon motion and combo transitions. Godot imports and browser comparison must pass. Gameplay timing recommendations remain proposals until Aki confirms config. No expansion until alignment, fluidity and visual quality are accepted.

## Handoff / Notes
Art proof delivered and tested. See reports/2026-10-19-modular-weapon-art-poc-report.md and assets/characters/player/modular_poc/INTEGRATION_NOTES.md. Visual acceptance and Aki engine integration remain pending; do not expand scope.

Initial audit at ce81f6d:847 production movement PNGs are unarmed; combat source studies bake in katana and occasionally trails. SpriteActor currently renders a single AnimatedSprite2D; SpriteSet supplies whole-frame textures and one foot anchor, with no frame-specific hand sockets. Aki notified on PR31, comment6278805017, before modular art production. Proposed convention:128 body pixel coordinates; weapon grip pivot; blade local+X; clockwise degrees in y-down screen space; front/behind draw order and optional hand occluder. New assets stay opt-in and do not replace current production manifest.
