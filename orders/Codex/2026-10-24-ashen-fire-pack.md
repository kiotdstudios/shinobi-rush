# Order — Ashen Ruins animated fire pack
- Agent: Codex
- Owner: Codex
- Status: DONE
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

## Live delivery
Implementation59a0e13891f6427bdd1fbeedb7df02487ee87689, PR #153, merge4c3e1ed7d813b336ee6765dd72cb5e375dd87967. Required PR CI40074069277 and deployment CI40074663840 PASS. Exact public build SHA verified;15live builder checks PASS,0errors. Report and live evidence recorded. Delivered for owner art review, with no additional approval claimed.
