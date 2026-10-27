# P0 — Player + Bandit Movement Transition Polish

**Owner: Aki (animation creation, integration, testing)**  
**Priority: P0 — gameplay feel**  
**Status: REVIEW � owner reassigned execution to Codex via PR #224; implementation and local tests complete, integration/live verification pending.**

Implementation branch: `codex/movement-transitions` (submitted to this PR's existing head branch). Visual drivers only; existing gameplay state, physics, camera and attack timing remain authoritative.

## Objective
Make both the **player and bandit** feel alive, weighty, and responsive during ordinary traversal. Deliver **all three** P0 transitions for **both actors**: (1) idle-to-run/start, (2) run-to-idle/stop, (3) sharp-direction pivot/turn. This is six actor/transition deliverables, including art **and** runtime wiring. Don't finish only the player.

## Audit first
- Inspect `scripts/player/player_controller.gd`, the player visual/animation driver, and the bandit controller/visual animation driver.
- Inventory current idle, move, sprint, and directional sprite sets, frame timing, and available transitions. Reuse any suitable art rather than duplicating it.
- Record existing eight-direction conventions, art pixel scale, origin/feet anchor, draw order, sprite mirroring rules, and bandit movement speeds. Avoid assuming the player and bandit have identical rigs.
- Verify where AI locomotion changes direction and where movement/animation transitions are triggered; don't implement transitions by changing combat AI state arbitrarily.

## Required transitions — BOTH PLAYER AND BANDIT

### A. START / LAUNCH (idle -> move/run/sprint)
- Create a brief anticipation/weight-transfer launch: lead foot pushes off, torso leans into travel, arms/clothing trail; then hand off seamlessly to existing locomotion loop.
- Target visual duration ~70–130ms, tuned in game. **Actual movement begins immediately on input/AI movement**; no frozen anticipation or startup latency.
- Sprint start can use a stronger launch or a speed-aware variation; don't create redundant art if it reads well at both speeds.

### B. STOP / BRAKE (move/run/sprint -> idle)
- Add short planted-foot deceleration pose(s), torso recoil and subtle clothing follow-through; settle naturally to idle.
- Target ~90–160ms, tuned to actual velocity/friction; stop animation should not slide while physics velocity is already zero.
- Cancel immediately on new movement, dodge, attack, hit reaction, jutsu, death, etc. Never force a fixed recovery lock.

### C. PIVOT / SHARP TURN (moving -> strongly different heading)
- On substantial heading reversal or sharp angle, show planted foot, body lean/rotation, then resume the appropriate movement loop.
- Handle 90-degree turns and 180-degree reversals; small steering changes should not trigger pivots every frame.
- Use facing/velocity dot-product or signed angle with a short cooldown/hysteresis to prevent flicker. Respect all supported directional facings and mirroring conventions.
- Do not rotate the entire 2D sprite unnaturally as a substitute for correct pixel art.

## Animation art standards
- Match each actor's **existing** sprite design, proportions, palette, pixel density, outline, and ground-contact anchor. Player and bandit must remain visually distinct.
- Deliver all supported directions, using verified mirror reuse only where appropriate. No stretched sprites, muddy interpolation, or foot sliding.
- Sprite timing should be snappy: launch ~2–4 distinct frames, stop ~2–4, pivot ~3–5, adjusted for real in-game FPS. These are guides, not mandatory frame counts.
- Add subtle dust/foot-contact effects only where appropriate and reuse existing VFX; do not bury silhouettes in particles.
- Keep animation naming/manifest conventions compatible with existing loaders; export transparent pixel-perfect sprites.

## Runtime wiring
- Implement a **visual locomotion transition layer** or equivalent for each actor, without disrupting the existing authoritative gameplay state machine.
- Player currently has `IDLE`, `MOVE`, `SPRINT`, `DODGE`, `JUMP`, etc. Do **not** introduce input delay or interrupt existing dodge, jump, combat combos, Chidori, substitution, or charge.
- Bandit transitions must work while AI patrols, approaches, repositions, searches, retreats, and changes direction. Preserve attack telegraphs and hit/death priorities.
- Transition triggers should use meaningful velocity and movement intent; animation playback must survive changing target speeds and rapid toggles.
- Establish animation priority: death/hit/attack/jutsu/dodge > locomotion transitions > movement loops > idle. Use actual existing priority contracts where different.
- Preserve momentum/acceleration/friction and movement hitboxes. Avoid animation-driven teleportation/root motion unless existing gameplay explicitly requires it.
- Provide graceful fallback to existing locomotion frames if a directional transition asset is missing; no blank frames or missing-action errors.
- Prevent footstep sounds/dust from firing twice when transitioning between loops.

## Acceptance tests
- [ ] Player idle -> walk/run and sprint launch smoothly in all supported directions.
- [ ] Bandit idle -> patrol/approach launch smoothly in all supported directions.
- [ ] Both brake into idle without snapping, foot sliding, or delayed controls.
- [ ] Both pivot cleanly at ~90° and 180°, without oscillating under rapid input/AI steering.
- [ ] Player run -> dodge/attack/jump/jutsu interrupts transitions instantly.
- [ ] Bandit patrol -> alert/attack/hit/death interrupts transitions instantly.
- [ ] Bandit pathing/repositioning does not stutter or freeze due to animation.
- [ ] Existing movement speeds, collision, combat timing, and eight-direction facing remain unchanged.
- [ ] Test at native game resolution, including 30/60 FPS behavior and browser build.
- [ ] Capture before/after short gameplay clips of BOTH player and bandit doing starts, stops, and pivots, plus a sprite preview sheet for each.

## Deliverables
1. Source sprite assets and exported animations for player AND bandit, with metadata/manifest updates.
2. Fully wired controller/visual changes and relevant automated tests.
3. Browser gameplay validation and before/after clips.
4. Implementation report listing changed files, animation timing, fallback logic, and remaining limitations.

**Definition of done:** Not merely art files or a visual mockup. Both actors must visibly execute all three transitions during real gameplay, without degraded responsiveness.