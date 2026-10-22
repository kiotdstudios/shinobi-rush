# ORCHA — P0 Body Flicker Jutsu Visual Prototype

- **Status:** REVIEW -- SE proof committed, pending owner visual approval before 8-direction expansion
- **Date:** 2026-10-21
- **Supersedes:** Orcha Lightning Clone Substitution visual order. Do NOT duplicate Codex's log/smoke Substitution Jutsu assets in PR #37.

## Objective
Create original **Naruto-inspired Body Flicker (Shunshin)** visuals: ninja vanishes in a sudden burst of speed, moves in a short directional streak, and reappears ready for action. It is extreme speed, **not** a teleport spell, Lightning Clone or substitution log.

## Visual direction
Departure: 1–3-frame anticipation, sharp compression/afterimage, brief directional dust/speed burst. Transit: fast directional smear and fading ghost silhouettes. Arrival: abrupt reappearance with small skid/dust, instantly ready to chain into **kunai combat**. Original poses/effects only, no copying anime frames. Do not use Codex's distinctive substitution log or smoke design.

## Scope and deliverables
1. Audit orders/README.md, orders/Orcha/README.md, player manifests, approved 128x128 RGBA transparent art, foot anchors and existing VFX.
2. **SE one-direction proof first** with departure, travel and arrival, normal-speed and slow preview at the official close-camera framing. Ask for owner approval before eight-direction expansion.
3. Independent transparent afterimage, streak and arrival-dust layers; pixel-perfect scale, no baked backgrounds/shadows, no sword; timing manifest and event markers: flicker_start, hide_player, flicker_travel, reappear, recover. Document any larger VFX canvas and its root.
4. Provide **Aki handoff**, not gameplay code: propose 100–220ms traversal and directional movement, safe arrival collision handling, possible cooldown/i-frame choices and transition into movement/kunai strike. Aki owns final mechanics and input mapping.
5. Validate alpha/dimensions, no ghost lingering, alignment, frame distinctness, Godot import and gameplay-scale preview; provide previews/contact sheet, tests, branch PR and report orders/Orcha/reports/2026-10-21-body-flicker-jutsu-report.md.
6. Verify integrated effect at https://kiotdstudios.github.io/shinobi-rush/ only **after** merge, successful main CI and real live browser test; record SHA. An art PR alone is NOT live.

## Acceptance criteria
Reads as movement too fast to track; compact and responsive, not slow teleport or substitution; stable scale and foot position; clear directional exit/entry; transitions cleanly into kunai combat; separate reusable VFX and metadata. No changes to Aki's controller, Codex's kunai/substitution art or Kiro's camera. No paid PixelLab generation without approval.

## Handoff / dependencies
Orcha: Body Flicker visuals. Codex: kunai animations and existing substitution art PR #37. Aki: Body Flicker/substitution mechanics. Kiro: camera. Old Orcha Lightning Clone order in unmerged PR #34 is superseded and must not be activated as a concurrent assignment.
