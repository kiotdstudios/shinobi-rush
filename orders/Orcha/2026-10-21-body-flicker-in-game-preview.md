# ORCHA — P0 Body Flicker In-Game Preview (Owner Directive)

- **Agent:** Orcha
- **Status:** REVIEW -- in-game demo implemented and tests passing; Web export + live browser smoke test pending
- **Priority:** P0
- **Date:** 2026-10-21
- **Owner directive:** "make orcha do it its his project"

## Objective
**Orcha personally owns implementation and deployment of a playable, visual-only Body Flicker preview in the real Shinobi Rush browser game.** Do not delegate this prototype to Aki or leave it as a contact sheet. The owner needs to **press a key/button and see the actual effect on the ninja in the live game** before approving full eight-direction production.

## Source and dependencies
- Continue from Orcha's existing branch `orcha/body-flicker-jutsu` commit `5266b9e` (verify the actual branch head before cherry-pick/merge). Reuse the 10 transparent 192x192 SE VFX frames, manifest `assets/vfx/body_flicker/body_flicker_SE.art.json`, and handoff; do not regenerate them.
- Read `orders/README.md`, `orders/Orcha/README.md`, the player scene/controller, Animation Lab, camera framing, `ninja_evade` VFX layering and current input map.
- Codex owns kunai and substitution art. Aki retains ownership of **production** player combat/controller architecture; coordinate before editing shared gameplay files. **Orcha owns the temporary demo wiring and all testing for this order.**
- The original Orcha Lightning Clone assignment is superseded. No paid PixelLab generation without owner approval.

## Required implementation
1. **In-game demo**: Add an obvious **Body Flicker** action/button to the existing Animation Lab (opened with Tab), plus an available keyboard test shortcut documented in the lab HUD. Use the actual Orcha SE departure/travel/arrival frames, with player visually vanishing and reappearing. At minimum it must work in the official browser game at close-camera zoom. No separate external viewer, no GIF-only substitute.
2. **Visual-only safe prototype**: No combat damage, cooldown economy, multiplayer, enemy AI or permanent input-map changes. Keep the test isolated to the lab. Use safe movement/displacement (proposed SE +56x/+40y) and restore player visibility/collision/state reliably after playback, even if lab closes mid-effect. If world movement is unsafe, keep body at original collision location and preview displacement using visual-only offsets; clearly label this limitation.
3. **Real animation timing**: Use the manifest events rather than a single particle burst. Playback at 24 fps / 10 frames (~417ms) with normal-speed and 0.5x-speed controls. Keep foot anchors correct, nearest-neighbor filtering, no frame clipping, no ghost residue. Show the effect at actual player scale, not oversized on-screen.
4. **Repeatable demo**: Can trigger repeatedly without accumulating sprites or corrupting movement, including moving/paused camera and after closing/reopening lab. Expose a simple on-screen legend.
5. **Browser validation**: Import assets, run Godot tests and Web export, browser smoke and actual click/key test; capture a screenshot or short sequence from the running game proving departure/travel/arrival. Test no JS/Godot errors and no stuck invisible player.
6. **Delivery**: Create a dedicated implementation PR with the actual game code and assets (not merely this order); run required checks, merge via normal protected-branch process when permitted, and **verify deployment** at https://kiotdstudios.github.io/shinobi-rush/ including deployed SHA and reproduction steps. If blocked, report exact blocker and keep status REVIEW/BLOCKED, never claim it is live.
7. **Report**: `orders/Orcha/reports/2026-10-21-body-flicker-in-game-preview-report.md` including changed files, evidence, tests, PR, and owner-ready instructions.

## Acceptance criteria
Owner can open https://kiotdstudios.github.io/shinobi-rush/, open the Animation Lab with Tab, press **Body Flicker**, see the ninja disappear/travel/reappear using Orcha's frames, compare normal and half speed, and repeat without breaking gameplay. The demo is visibly separate from substitution, lightning clone and standard dodge. **Do not proceed to eight-direction production until owner approves this in-game SE proof.**

## Ownership
**Orcha: demo code + art + browser verification.** Aki: production mechanic review/handoff later. Codex: kunai/substitution. Kiro: camera. This order intentionally assigns prototype integration to Orcha, overriding the earlier handoff-only interpretation.
