# CODEX — P0 Kunai-First Combat Animation

- **Status:** QUEUED
- **Date:** 2026-10-21
- **Owner direction:** Make Naruto-inspired kunai, not sword, the basic/default shinobi weapon.

## Objective
Prioritize an **original, fast, one-handed kunai combat animation set** for Shinobi Rush. This **supersedes sword-first priorities** in unmerged Codex order PR #40. Sword becomes an optional future weapon, not current default. Do not copy specific Naruto frames or character designs.

## Context
Read orders/README.md and orders/Codex/README.md; audit the existing kunai study PR #48 and sword art studies PRs #33/#42 before creating new assets. Reuse compatible kunai work rather than duplicate it. Keep approved 128×128 RGBA transparent player body, fixed foot anchor, eight-direction conventions, and independent weapon/VFX layers. Preserve the player's approved identity and silhouette. Do not change gameplay controller; Aki owns timing and hit logic. Kiro owns camera impact; Orcha owns Lightning Clone. Avoid paid PixelLab generation without owner approval.

## Scope and deliverables
1. **One-direction southeast proof for owner review first:** Guard/idle -> kunai light1 -> light2 -> light3 -> dodge -> dash kunai strike -> run, with a compact kunai, stable hand socket, strong silhouettes and in-game preview. Do not expand to eight directions before approval.
2. **Distinct three-hit combo:** Quick forward stab/slash, reverse-grip cross-cut and turning finisher. Use an active off-hand, tight elbow-driven movements, pivots, snappy anticipation/contact/recovery, impact holds, smear frames and separate short blade-swipe effects. It must look like kunai fighting, never a long sword.
3. **Mobility/defense:** Kunai dash attack, airborne strike, dodge recovery, block/parry/deflect, hurt reaction; no unintended weapon disappearance or snap between actions.
4. **Production:** Once proof approved, eight directions; transparent body and independent kunai/impact VFX, manifest, frame and hand-anchor metadata, contact event markers, previews at game zoom.
5. **Handoff:** Document attack event timings, hit direction and weapon socket for Aki. Integrate through reviewed PR and verify on https://kiotdstudios.github.io/shinobi-rush/ after merge, green main CI and actual live browser test.

## Acceptance criteria
Kunai is clearly the default melee weapon; three distinct legible strikes; stable sockets and foot anchor; no sword silhouettes; no abrupt run/dodge/air transitions; no regressions in buffered combat. Run asset QC, Godot tests, web export and browser smoke before commit; report results, limitations and exact deployed SHA. Required report: orders/Codex/reports/2026-10-21-kunai-primary-combat-animation-report.md.

## Dependencies / status
Codex art only, Aki gameplay integration. Existing Chidori task is separate and should not be silently discarded; flag schedule conflicts. PR #40's sword-first order is superseded and should not be merged as a second active P0. PR #48 can serve as implementation base if appropriate.
