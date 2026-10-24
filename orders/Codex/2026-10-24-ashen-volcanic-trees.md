# Order — Ashen Ruins volcanic trees
- Agent: Codex
- Owner: Codex
- Status: IN_PROGRESS
- Priority: P1
- Branch: codex/ashen-volcanic-trees
- Dependencies: User reference, approved Blightwood scale/camera and ash animation source; satisfied.

## Objective
Direct owner request: create barren volcanic trees for the Ashen Ruins entrance in the Village Hidden in the Cinders, surrounded by dormant volcanoes. Molten-red roots and detailed motion comparable to Blightwood; independent falling ash/petals.

## Context / References
User attached97F3CB95-ED7C-42D2-864F-B5F8C4679649/1-Pasted-Image-1.jpg; existingBlightwoodtrees and three-quarter camera. Story bible canon consulted on story/haigakure-cinders-legacy without importing its proposed narrative changes.

## Scope / Deliverables
Three native320×448RGBA tree silhouettes;96phase rooted wind, molten root pulse; separate16pose ash atlas and bounded emitter; standalone reviewscene, actual Godot captureGIFs at normal/half speed, contact sheets, provenance, tests and PR. New art/review components only; no existing game scene, combat, camera, map or spawn changes.

## Acceptance Criteria
Crisp transparent art, consistent root anchors and size, barren branches and readable red roots, detailed independent ash, stable rooted motion, wrap-continuity and bounded pool, Godot and browser previews without errors. Owner visual review follows technical validation.

## Handoff
Asset manifest assets/environment/ashen_trees/ashen-trees.art.json. Owner approved the trees and explicitly requested builder registration, dedicated filter and live deployment. Integration checks in progress; deploy after required CI and verify exact live build.
