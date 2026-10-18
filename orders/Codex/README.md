# Codex — Art Department Orders

**Role: Art production owner for Shinobi Rush.** This is Codex's dedicated order inbox: `orders/Codex/`.

Read [master agent orders and execution rules](../README.md) **before working**. When you see a `QUEUED` order assigned to Codex, start immediately without waiting for another prompt. Set it to `IN_PROGRESS`. Do not take implementation orders owned by Aki, Orcha, or Kiro without explicit reassignment.

## Art responsibilities
- Produce and refine original game-ready **character sprites, directional poses, sprite sheets, animations, VFX, environments, tiles, props, and UI art** when assigned.
- Follow the [locked baseline player design](../../docs/prototype/BASELINE_PLAYER_CHARACTER.md) and **inspect the approved PNG** at `assets/characters/player/references/baseline_turnaround.png` before making player art.
- For the player, include a distinct **Naruto-inspired forward-leaning, arms-back ninja sprint** triggered by R1; create original frames rather than copying Naruto assets. Keep the player unmasked and without cape or sword.
- Match the project's faux-isometric 2D camera, sprite scale, foot anchor, directional consistency, animation states, and performance constraints. Export organized, usable assets with descriptive names and transparent backgrounds when appropriate.
- Coordinate integration requirements with gameplay agents; do not silently edit their code.

## Mandatory job workflow
1. Read queued Codex orders and **start immediately**.
2. Produce the art and verify visual quality, dimensions, transparency, file integrity, and directional/animation consistency **before committing**. When assets are used in-game, preview/test them in Godot and the browser test build where access is available.
3. Commit and push completed, tested assets using the approved branch/PR workflow; integrate and publish updated art to the **live browser-playable test game automatically** when runtime-visible. Verify the live result. Do not bypass protections or claim deployment success without checking.
4. **After every job, write a report** in `orders/Codex/reports/YYYY-MM-DD-task-name-report.md` covering work completed, changed files, tests/results, issues, questions for the owner, next steps, commit/PR, and live-build verification. If blocked, still file the report and identify the blocker.
5. Do not mark an order `DONE` until testing, integration, applicable live deployment, and reporting are complete.

## Current orders
No orders assigned by creating this folder. Previous Codex character handoff in `docs/prototype/` is reference material; a new order should specify what Codex is to execute.


## Mandatory art camera standard
All Codex art orders must follow [Shinobi Rush camera and art direction](../../docs/visuals/CAMERA_AND_ART_DIRECTION.md) and the [three-quarter art skill](../../skills/three-quarter-game-art/SKILL.md). **Gameplay is 2D three-quarter overhead faux-isometric**, not side-scrolling. The baseline PNG is a character appearance turnaround, not the gameplay camera. Test an in-engine sample before mass-producing sprite frames.


## Locked art scale and fluidity
Follow [Order 01 high-detail production requirements](./order_01.md): 128×128 RGBA standard frames, approximately 100–112 px standing character height, fixed foot anchor, eight-direction coverage, purposeful 24 fps authored animation, high-detail layered equippables and separate directional VFX. Bigger frame counts are useful only when timing and poses improve; verify Web performance.


## Premium roguelike-inspired game vision
**Required reading:** [Shinobi Rush quality and inspiration brief](../../docs/vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md). Aim for premium AAA-level polish in combat, animation, VFX, enemy readability and replay appeal. **Do not change the locked persistent RPG progression, world layout, death/save rules, or add permadeath/procedural run resets without owner approval.**


## Mandatory PixelLab API art-generation policy
**All new generated pixel-art assets for Shinobi Rush must be created through the PixelLab API** (characters, directional sprites, animations, equipment, enemies, tiles, props, environment art, UI pixel art and pixel VFX). Read [PixelLab API art pipeline](../../docs/visuals/PIXELLAB_API_ART_PIPELINE.md) before art work. Codex owns generation; other agents request assets from Codex rather than using alternative generators. Manual pixel cleanup, sprite compositing, shaders, particle systems, and programmatic Godot integration are permitted post-processing—not substitutes for PixelLab-generated source art. Never embed or commit API keys. If PixelLab API credentials, features, quotas or outputs are unavailable, report BLOCKED; do not silently switch generators.
