# Order — Ashen Ruins animated fire pack
- Agent: Codex
- Owner: Codex
- Status: REVIEW
- Priority: P1
- Branch: codex/ashen-fire-pack
- Dependencies: PixelLab access and existing stone palette; satisfied.

## Objective
Recreate the owner's five fire fixture concepts as original transparent PixelLab assets in the actual dark weathered stone palette. Fire must feel alive.

## Context / References
Owner attachment A7C9CCA5-2488-4FCC-A934-FF8FB8F6E021/1-Photo-1.jpg, existing Kosen/Ashen floor tiles and three-quarter camera direction.

## Scope / Deliverables
Tall pillar, short brazier, tripod brazier, wall brazier, ground pit.12unique flame frames at12FPS; independent smoke, sparks, coals, warm tile illumination and synchronized crackle audio. Native assets/metadata, review scene, normal/half-speed Godot previews, builder category/integration, tests and reviewed PR/live verification. Shared builder files are the minimum registration changes needed for the owner's request. No combat or camera edits.

## Acceptance Criteria
Transparent crisp art matching sampled floor palette; consistent perspective/root anchors;12unique registered flame frames, irregular independently timed effects, bounded particle pools, positional event-synchronized audio. Five builder cards; scroll without zoom; placement/selection/move/delete/filter cancellation and save/reload; import/native/Web checks; exact deployed SHA and live browser verification.

## Handoff
Manifest assets/environment/ashen_fire/ashen-fire.art.json. Runtime scripts/environment/ashen_fire_prop.gd. Builder filter Ashen fire. Current status pending final browser checks, commit, required CI and deployment.

## Pre-commit result
2264native tests PASS,15builder browser checks PASS, review controls/audio synchronization PASS,192captured frames per normal/half-speed preview;0runtime errors. Required reviewed PR and exact live deployment verification next.
