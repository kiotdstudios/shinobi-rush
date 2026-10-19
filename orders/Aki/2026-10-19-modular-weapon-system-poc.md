# ORDER — Modular weapon attachment proof of concept
- Agent: Aki
- Owner: Aki (programming); collaborator: Codex (art)
- Status: QUEUED
- Priority: P1
- Branch/PR: Separate Aki engineering branch; Codex art branch codex/modular-weapon-art-poc
- Dependencies: Codex art contract/assets under assets/characters/player/modular_poc/; coordinate camera ownership with Kiro

## Objective
Support interchangeable compatible swords through frame-specific hand anchors and separate body, weapon and slash-effect layers. Owner explicitly limits the proof to one player, SE direction, one three-hit combo and two visually distinct one-handed swords. Do not convert847 existing movement frames or expand directions/types before the proof passes alignment/fluidity/quality review.

## Context / References
Owner's Modular Weapon Animation System request; orders/Codex/2026-10-19-modular-weapon-art-poc.md; Codex art metadata and baked comparison. Proposed coordinates: native128 body, foot[64,116]; grip pivot on weapon, blade local+X; clockwise angle in y-down screen space. Aki may coordinate changes to the art contract with Codex.

## Scope / Files owned
Audit SpriteActor/SpriteSet and controller; implement opt-in weapon attachments and frame synchronization. Support per-frame hand positions, orientation, front/behind draw-order changes and hand occlusion where needed. Synchronize movement, hitbox-active/contact events and separate VFX with animation frames. Define reusable compatible sword-family profiles. Keep the fully drawn katana path functional while migrating. Do not overwrite Codex artwork or Kiro camera code.

## Deliverables
Attachment/layer implementation, one-direction three-hit combo profile using Codex body art, two compatible swords swapped without replacing body assets, comparison against fully drawn fallback, tests, own report and reviewed PR/live verification.

## Acceptance Criteria / Tests
Both swords use identical body files. No grip drift, blade teleportation, draw-order errors or stale VFX on frame changes/cancels. Gameplay contact/active/cancel timing must be coordinated with art rather than silently inferred from provisional review FPS. Validate Godot and browser keyboard/controller behavior, switching weapon during legal states, combo progression/cancels, fallback katana compatibility and live deployed build through normal reviewed integration.

## Handoff / Notes
Codex owns art proof, anchors/orientation/draw-order metadata and isolated art comparison harness. Initial audit found no existing runtime weapon socket system on main ce81f6d. Art preview does not establish hitbox/movement integration. No additional weapon families/directions are authorized until proof acceptance.
