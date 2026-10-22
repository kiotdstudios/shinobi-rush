# CODEX — P0 Saturday player and Bandit combat animation integration
- **Status:** QUEUED
- **Priority:** P0

## Objective
**Stop delivering only isolated art harnesses.** Player kunai proof PRs #63/#67 are merged. Audit and hand off exact animation IDs, frames, sockets, contacts and VFX to Aki so the **actual J attack** in the real arena shows kunai attacks. Prioritize finishing the Bandit's missing **real 128×128 red-scarf kunai attack frames**, dodge/flicker and hit reactions, not just tint/arcs; Bandit needs same **core action vocabulary** as player with distinct silhouette and low-level sloppy timing. Existing Bandit locomotion art should remain unless clearly broken.

## Deliverable order
1. **Thursday:** verify player merged assets, 2-hit kunai motion, Body Flicker sprites and VFX are actually consumable by PlayerVisual. Give Aki exact frame event timing/manifest mappings; fix any art-side import/registration problems; push/integrate immediately.
2. **Friday:** **SE-facing Bandit playable** kunai attack 1/2, evade/Body Flicker double-back, hurt/alert, matching established palette, anatomy, pixel density, 128×128 RGBA and stable foot anchor. No dummy lunge. Integrate with Aki's attack state events in normal game; push/integrate.
3. **Saturday:** extend other directions as time allows, but **don't hold up playable combat** for full eight-direction polish; maintain safe directional fallback/flip without character disappearing or weapon popping. Verify at normal zoom. If missing abilities (jump/air) require extra art, reuse established animation convention as safe placeholder and list precise gap; do not claim full parity when missing.

## Boundaries
Codex owns art/manifest/VFX assets; Aki owns gameplay state and damage, Orcha owns reusable Body Flicker VFX, Kiro debug/camera. Coordinate before shared files. No paid PixelLab without owner approval. Prior SE proof owner review still applies for bulk eight-direction production, but owner now prioritizes playable MVP. Report `orders/Codex/reports/2026-10-22-saturday-combat-art-integration-report.md`.

## Shared Saturday milestone and delivery rule
**Deadline: Saturday October 24, 2026, end of day America/New_York.** Read `orders/README.md` and `orders/Codex/README.md`. Owner needs a **playable integrated combat loop in the ONE official live browser game** https://kiotdstudios.github.io/shinobi-rush/, not more disconnected art proofs. Work in small vertical slices; for **each tested meaningful slice**, write evidence, **commit and PUSH immediately**, open/update PR, get required CI, merge into `main`, deploy and verify live before claiming playable. Do not leave local-only uncommitted work or accumulate a huge unreviewable branch. Do not bypass CI, branch protection, or overwrite another agent's files. If CI is pending, say pending and follow it through. Mark DONE only after the actual deployed build is tested. Report PR/SHA/live SHA and blocker promptly. Keep all agents aligned through the integration order and preserve existing 128×128 8-direction art and persistent RPG rules.