# CODEX — P0 Player kunai combo and Body Flicker dodge animation overhaul

- **Owner:** Codex (art and animation)
- **Status:** QUEUED
- **Priority:** P0
- **Date:** 2026-10-21
- **Supersedes:** the old lunge-style dodge presentation in the kunai preview; extends `orders/Codex/2026-10-21-kunai-primary-combat-animation.md`. Do not duplicate completed kunai assets.

## Owner direction
The current dodge **looks like a lunge and is not acceptable**. Shinobi Rush should play like a fast, fluid ninja game. The intended combat rhythm is **quick kunai hit → quick kunai hit → double backward Body Flicker (“punch punch, back weave”)**. No slow lunging, exaggerated ground slides, dodge rolls, or dead time. This must look good **in the playable game**, not only in contact sheets.

## Exact responsibilities
**Codex:** player body animation frames, kunai hand/socket poses, afterimages/trails art, animation manifest, Godot animation hookup for preview in coordination with Aki, visual QA. **Aki:** input/combo state, damage/hitbox timing, interrupts, directional collision, recovery and movement balance. **Orcha:** reusable Body Flicker VFX integration; coordinate with his PR #61, do not duplicate or overwrite it. **Kiro:** camera. Coordinate shared-file changes via reviewed PRs.

## Deliverable 1 — replace dodge animation
- Design an agile shinobi dodge with a **brief vanish, speed streak, one sharp afterimage, and crisp reappearance**; no forward lunge or sliding animation.
- Dodge direction follows player input; backward evade is away from the current target/facing if requested by Aki. Visually consistent in faux-isometric eight-direction play.
- Start with a **southeast-facing playable proof**, preserve approved player 128×128 RGBA sprite proportions, fixed foot anchor, pixel grid, nearest-neighbor and separate weapon/VFX layers. Expand all eight directions **only after owner approves the in-game proof**.
- Art must be original and readable at actual camera zoom.

## Deliverable 2 — combo into double backward flicker
- Produce distinct **two rapid reverse-grip kunai strikes**, then **two extremely fast backward vanish/reappear beats** with a slight stagger, leaving readable afterimages; visually communicate retreat without the character running backward.
- Supply frame timings and event markers for strike contacts, vanish/reappear, retreat beats and animation completion; hand off to Aki for real movement/collision and buffering.
- Treat double-flicker as a **player-selectable combo escape/finisher option**, **not an unavoidable automatic animation after every combo**; this preserves player agency. Ask owner for a decision if input binding is unresolved. Aki handles the input.
- Fast transition back to neutral/run/attack; no frozen pose, duplicate sprites, stuck invisibility, clipping or ghost residue.

## Exact repository locations
- Existing player animation assets/manifest: inspect approved `assets/characters/player/` hierarchy and **follow its existing structure**, not a parallel custom player folder.
- Reuse Orcha's `assets/vfx/body_flicker/` frames and manifest as a baseline. Add Codex-specific kunai contact trails in existing `assets/vfx/` conventions; avoid replacing Orcha's files.
- Put the report at `orders/Codex/reports/2026-10-21-player-kunai-flicker-combat-rework-report.md`.
- Coordinate animation wiring with Aki; no unilateral rewrites of `scripts/player/` combat logic or camera.

## Test and approval
1. Audit latest main, Codex kunai delivery, Aki combo branch and Orcha's Body Flicker implementation before editing. Reuse good work.
2. Produce southeast in-game proof showing **idle → kunai 1 → kunai 2 → double backward flicker → re-engage** and single dodge.
3. Verify player remains visible after rapid repeated use, direction changes, movement interruption, attack buffering, and entering/exiting Animation Lab.
4. Run asset dimension/alpha/socket QC, Godot import, automated tests, Web export, browser smoke and **actual live keyboard/mouse playtest**. Report honest results.
5. Open implementation PR into `main`, respect required checks, merge through approved process, verify live deployment at https://kiotdstudios.github.io/shinobi-rush/ and record deployed SHA. Do not call DONE until the owner can play it.
6. No paid PixelLab or eight-direction production pass without owner approval.
