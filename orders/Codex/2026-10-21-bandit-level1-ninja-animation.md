# CODEX — P0 Level 1 Bandit ninja animation package

- **Owner:** Codex (character art, animation and VFX)
- **Status:** QUEUED
- **Priority:** P0
- **Date:** 2026-10-21
- **Gameplay counterpart:** `orders/Aki/2026-10-21-bandit-level1-robber-arena.md` (order PR #64, check merge state).

## Owner direction
Bandit currently reads as **idle staring, awkward running and a lunge**, not a real ninja. Make him look like a **low-level but credible bandit** who prowls for travelers to rob, notices the player, chases, threatens, attacks with kunai, retreats with Body Flicker, searches for the player, and gives up. He should be deliberately clumsy in **decision-making**, not broken in animation quality. The player spawns on one side of the arena and Bandit on the far side; Aki handles spawn, walls, AI and pathing.

## Animation package
1. **Alert, watch and idle:** relaxed-but-alert guard, subtle shifting weight, looking around, suspicious turn, spotting a target, brief robber intimidation/threat pose. No frozen mannequin stare.
2. **Patrol and pursuit:** natural foot-planted walk/patrol and agile ninja run/sprint with consistent gait through eight-direction turns, acceleration/deceleration and stops. Eliminate sliding, lunge-style motion and restart-from-frame-zero on every heading change.
3. **Combat:** simple readable **two-hit kunai combo** with distinct windup, contact and recovery; intentionally imperfect timing/longer tells to make this a fair Level 1 enemy. Aki owns hitboxes/damage.
4. **Defense:** one sharp Body Flicker evasive move and **occasional double backward flicker** after attacking. Brief vanish, layered afterimage/streak, reappearance, clean recovery. Reuse Orcha's VFX system with proper owner coordination; do not invent a second incompatible effect.
5. **Reactions:** hit flinch, stagger, lost-target scanning, return-to-patrol transition; preserve existing hurt/death states and silhouette.

## Production rules
- First deliver **SE-facing playable in-game proof** using existing approved **128×128 eight-direction red-scarf Bandit** art and existing `assets/characters/bandit/` manifest/folders; preserve fixed foot anchor, palette, transparent background and nearest-neighbor pixel rendering.
- Avoid replacing all 160+ approved frames unnecessarily. Reuse and repair existing idle/run/sprint where possible; generate only needed new poses/frames and track changed paths.
- Work with **Aki** on AI animation state events and transitions, but do **not** modify AI intelligence, pathfinding, far spawn, collision walls, damage or economy.
- Intelligence is a gameplay tuning value (Aki owns `intelligence_level = 1`); art must support low-skill cues: longer tells, overcommitted attack pose, hesitant reacquisition.
- For any missing sprite art, create original assets, do not trace Naruto frames. Do not call paid PixelLab without owner approval.
- **Do not expand to eight-direction new animations until the owner approves the SE proof**, though existing eight-direction sprites must remain functional.
- Report: `orders/Codex/reports/2026-10-21-bandit-level1-ninja-animation-report.md`. Include source frame count, visual contact sheet, event timing manifest, screenshots/clip at actual game zoom, asset QA, test commands/results, branch/PR and deployment evidence.

## Acceptance criteria
- Bandit looks like a moving ninja while idle/patrolling/running; no stare-and-sprint or visible lunge.
- Kunai two-hit combo and double-backward flicker visibly match the fast player combat language but remain readable/fair.
- Aki's states PATROL/NOTICE/APPROACH/THREATEN/ATTACK/RETREAT/SEARCH/RETURN map to appropriate animations.
- No frame restarts, foot sliding, weapon popping, animation stuck states or ghost trails.
- Godot import, automated tests, Web export, interactive browser test, reviewed PR, successful live deployment and exact SHA in report before DONE.
