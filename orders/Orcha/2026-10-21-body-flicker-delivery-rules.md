# ORCHA — P0 Body Flicker: Exact File Placement, Integration, Tests and Delivery Rules

- **Agent / Owner:** Orcha
- **Status:** QUEUED
- **Priority:** P0
- **Date:** 2026-10-21
- **Supersedes / clarifies:** Earlier Body Flicker orders and handoff-only scope. Owner explicitly assigned **the complete playable in-game prototype to Orcha**.

## Objective
Finish the **actual Body Flicker animation lab demo**, put every asset/script/report in the right repository folder, safely integrate via PR, publish to the shared browser build, and prove the owner can test **Tab -> Y** in-game. Do not leave a branch-only demo and call it complete.

## Mandatory reading and source
Read `orders/README.md`, `orders/Orcha/README.md`, `skills/README.md`, `docs/visuals/CAMERA_AND_ART_DIRECTION.md`, `docs/vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md`, current player scene, animation lab and manifest before changes. Work from existing implementation branch `orcha/body-flicker-in-game-preview` (reported SHA `8d45f59001c0fb50976b9deeb96ed4a5f7cd77ef`; verify HEAD) and the original `orcha/body-flicker-jutsu` source (reported SHA `5266b9e`). **Reuse current work; do not recreate it.**

## Exact file placement (no files on Desktop or outside repository)
- `assets/vfx/body_flicker/depart_000.png` through `depart_002.png`: departure PNGs
- `assets/vfx/body_flicker/travel_000.png` through `travel_003.png`: transit/afterimages
- `assets/vfx/body_flicker/arrive_000.png` through `arrive_002.png`: arrival PNGs
- `assets/vfx/body_flicker/body_flicker_SE.art.json`: frame order, 24 fps, timing, foot anchor, 56x40 SE preview offset, events
- `assets/vfx/body_flicker/contact_sheet_SE_proof.png`: owner review contact sheet
- `assets/vfx/body_flicker/AKI_HANDOFF.md`: future production mechanics handoff, **not a reason to delegate this demo**
- `scripts/vfx/body_flicker_demo.gd` (+ .uid if Godot creates one): **Orcha-owned visual-only playback logic**
- `scripts/ui/animation_lab.gd`: existing lab integration, Tab opens lab, **Y** triggers Body Flicker, on-screen key legend, normal and 0.5x preview controls; preserve existing shortcuts
- `scenes/player/player.tscn`: minimal demo node wiring only; preserve character hierarchy, animations, foot anchor and controller
- `orders/Orcha/2026-10-21-body-flicker-in-game-preview.md`: status/links
- `orders/Orcha/reports/2026-10-21-body-flicker-in-game-preview-report.md`: **full accurate completion report**, updated with tests and live evidence
- Optional screenshot evidence: `docs/visuals/previews/body_flicker/` (if added, reference exact files in report).
- **Do not bundle unrelated camera implementation:** `scripts/camera/combat_camera_director.gd` belongs to Kiro's camera workstream. Current branch reportedly includes it. Compare to `main`; if unrelated, remove it from the Body Flicker PR or coordinate a separate reviewed PR. No conflicting camera ownership.

## Required demo behavior
1. On the real browser game, press **Tab**, then **Y**. Player visibly vanishes, directional speed streak/afterimages play, then player reappears. Render actual Orcha 10-frame SE assets, **not placeholders**.
2. 24fps 10-frame preview (~417ms); support normal and 0.5x playback. Distinguish Body Flicker from substitution log/smoke and standard dodge.
3. Preview may use **visual-only 56x40 px offset** while keeping collision/body world position unchanged; label this limitation. **Do not implement production teleport, i-frames, cooldown, hit logic or modify permanent controller input mappings.** Aki owns eventual mechanics.
4. Repeated Y presses, leaving/reopening lab, player movement, pause, death and scene transitions must not leave hidden sprites, stuck state, duplicate nodes or orphaned effects. Avoid shortcut collisions (B is already bound; use Y).
5. Preserve 128x128 approved player sprites, transparent VFX on 192x192 canvases as needed, nearest-neighbor filtering, fixed foot anchor and faux-isometric camera.

## Rules: test, PR, deploy, report
1. **Before implementation commit:** run relevant Godot import, automated tests, Web export, browser smoke and actual interactive Tab->Y playback; record exact commands, test counts and outcomes. Existing report says **742 tests passed** but **Web export and browser test were NOT RUN**. Do not mark them passed.
2. Validate 10 PNG alpha/dimensions and manifest, no console errors, missing resources, animation regressions or input conflicts. Test both normal and half speed, repeated triggering, closing lab mid-effect and player visibility restoration. Save real screenshots or browser evidence when possible.
3. Fix failures and rerun; if Web testing unavailable, mark **BLOCKED or REVIEW** with the precise reason. No false completion.
4. Update the report **before committing**, including changed file paths, tests, commands, failures, questions, known risks and PR/commit. Update SHA/link afterward in a report-only follow-up if needed.
5. Push tested code on **dedicated Orcha implementation branch**, open a **real implementation PR** into `main` (not only an order PR). Avoid direct pushes to main and never force/override required checks. Check merge conflicts with Aki/Kiro/Codex; request review when shared files overlap.
6. Once checks/review pass, merge through approved workflow, wait for Pages deployment, then **open https://kiotdstudios.github.io/shinobi-rush/** and actually verify Tab->Y normal/half-speed. Record merged SHA, CI run, deployed SHA/time, URL, live browser outcome in report. If you lack merge/deploy access, state the blocker and give owner the PR URL.
7. Set order to **DONE only after** verified live playtest and complete report. Otherwise REVIEW/BLOCKED with outstanding steps.
8. **Do not expand to eight directions until owner approves the live SE preview. No paid PixelLab calls without explicit owner authorization.** No other agent's task, unrelated camera changes, substitution or kunai art.

## Acceptance criteria
- All exact paths exist in the implementation PR and are correctly referenced.
- Actual browser game has a functioning Tab->Y Body Flicker lab demo with 10 frames, normal/half-speed playback, safe reset and no regressions.
- Automated tests, Web export, browser smoke and deployed live verification all have evidence; report is complete and honest.
- Owner can review the effect before eight-direction work begins.

## Dependencies
**Orcha:** art + demo code + testing + PR + live verification. **Aki:** production movement/combat mechanics later. **Kiro:** camera. **Codex:** kunai and substitution. Coordinate, do not overwrite.
