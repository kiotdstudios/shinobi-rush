# ORDER — Investigate player disappearing beneath arena wall (deferred)
- **Agent:** Kiro
- **Status:** REVIEW (2026-10-18): defect found and fixed; PR open, not merged; live build not yet verified. Report: orders/Kiro/reports/2026-10-18-wall-occlusion-report.md
- **Priority:** P2 (reassess after current work completes)
- **Owner:** Kiro
- **Source:** Owner's playable browser screenshot, 2026-10-18 (player near the center-right obstacle, partially covered by the brown placeholder wall/block).
- **Dependency:** Complete currently running workflows, merge/integrate relevant pending changes, and retest current playable build FIRST. Do not interrupt or reprioritize existing work for this.

## Problem / reproduction
Owner can now launch and play the Godot bootstrap build. In the screenshot, the character at approximately the center-right brown placeholder obstacle appears partially behind/under the wall, with parts of the sprite obscured. Determine whether this is correct intentional Y-sort occlusion for a tall object, or an actual rendering/depth/collision bug. Also check whether the known north-arena-boundary camera clipping issue is related, but do not conflate them.

## Required approach (after dependency clears)
1. **Reproduce on latest integrated build first**, with keyboard and controller where available. Capture precise steps, position, screenshot/short clip, Godot version/build SHA. If no longer reproducible, report **RESOLVED BY OTHER WORK — NO CODE CHANGE** with evidence and close the order.
2. If reproducible, inspect Y-sort origins, tile/object layer order, feet/ground contact pivot, obstacle top/front-face drawing, collision shapes, character's visual offset, and camera clipping. Check from above, below, left and right of several obstacles.
3. Clarify desired visual rule: character can be obscured by a wall's *front face* when logically behind it, but should not incorrectly disappear under the wall when in front; collisions must stop the player from walking through solid geometry. Do not indiscriminately draw the player on top of all walls.
4. Apply the **smallest justified fix** (sort origin/visual hierarchy/collision/camera bounds as evidence dictates), preserve the fixed three-quarter faux-isometric view, avoid breaking Codex's 128×128 production sprite scale/foot anchors and Orcha's dynamic camera integration.
5. Add regression test(s) where feasible, include before/after evidence and validate in actual Web browser export. Capture debug logs when telemetry is available; do not block investigation on telemetry if it is still pending.
6. Document whether issue is visual occlusion, actual collision penetration, camera bounds, or intended rendering.

## Acceptance
- After current work completes, either verified non-reproducible (no fix) OR reproducible defect corrected and tested.
- Player remains correctly visible relative to obstacle front/back faces and cannot cross solid walls.
- No regressions to camera movement, sprint, directional animation, HUD or sprite anchor.
- Report to `orders/Kiro/reports/` with SHA, exact tests, before/after evidence, status and PR link. No claim of completion without verification.

## Note
Owner approves Codex's current idle character art and intends to authorize Codex to continue. **This order does not assign Codex work or alter art assets.**

## Status log
- 2026-10-18: investigation closed as DEFECT (east-side draw order, H1+H2). Fix on branch kiro/wall-occlusion, PR: https://github.com/kiotdstudios/shinobi-rush/pulls?q=head%3Akiro%2Fwall-occlusion (REVIEW, not merged).
