# ORDER — Combat Fluidity Overhaul V1

- Agent: **Aki**
- Status: **QUEUED**
- Priority: **P0**
- Owner: **Aki — gameplay and integration**
- Branch/PR: Create a dedicated implementation branch and PR for each milestone; this order is proposed in a separate order-only PR.
- Dependencies: Existing combat controller and approved player art; coordinate with Codex for combat animation and Orcha for Lightning Clone VFX. Do not wait for unfinished production art to complete mechanics tests.

## Objective
Make Shinobi Rush combat fluid, aggressive, readable and responsive like the owner's 53.4-second pixel-art combat reference video. Preserve control continuity across sprint, sword attacks, dodge, aerial actions and hit confirms. Match the *feel* rather than assuming the source game's internal timings are known.

## Context / References
- Owner-provided 53.4-second, 720x480, 30fps pixel-art combat recording. Earlier visual review of first 180 recorded frames (0–6s) highlighted rapid approach, white impact silhouettes, circular sword arcs, yellow contact sparks and multiple enemies. Recording frames are not necessarily distinct authored sprite frames. Do not invent frame-exact timings or claim to have the original source code.
- Design pillars: Hades fluid chaining/momentum; Sekiro precise defensive timing/posture; Ghost of Tsushima weighty katana contact.
- Read `orders/README.md`, `orders/Aki/README.md`, `docs/vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md`, current player manifest and current combat code.
- Locked player standard: 128x128 transparent RGBA sprites; approved close-camera test framing; preserve game/world/progression rules.

## Scope and work plan

### Milestone A — Audit, movement and state transitions (DO THIS FIRST)
1. Inspect actual player controller, action/animation states, input mapping, attacks, hitboxes, jump, dodge, enemy controller and animation events. Identify forced idle gaps, zeroed velocity, conflicting animation writes and animation-finished gates. Document exact code paths before editing.
2. Establish one authoritative action/state transition layer with clear priority, eligibility, interruption and cancel rules. Avoid multiple scripts fighting to set animations.
3. Implement initial **100–150ms** buffered combat inputs with expiry; expose active buffer and cancel eligibility in dev diagnostics.
4. Preserve intentional momentum for run→attack, run→dodge→run, run→jump→land→run, attack→attack and dodge→eligible attack. No forced idle between valid transitions. Heavy recovery and failed defensive actions may remain committed.
5. Provide live playable Milestone A and owner-facing test steps BEFORE expanding the combat overhaul.

### Milestone B — Offensive combat
1. Three-hit sword combo plus dash attack with data-driven startup/active/recovery and attack event markers. **Initial 60Hz physics tick proposals only:** light1 5/4/9, light2 6/4/11, light3 9/5/15, dash attack 6/5/13.
2. Explicit combo buffer windows, hit-confirm follow-ups and limited attack→dodge cancels; prevent infinite chaining or universal cancellation.
3. Match collision hitboxes to visible sword arcs, controlled forward displacement, no repeat hits on one target per attack unless explicitly designed.
4. Reusable hit events drive contact sparks, bright impact silhouettes, slash arcs, audio and hitstop. Suggested light hitstop 40–60ms, heavy 70–100ms, tune in playtest; buffered inputs must survive hitstop.
5. Support current movement directions; coordinate visual frame timings and layering with Codex rather than redrawing the character.

### Milestone C — Defensive combat
1. Collision-aware dodge with initial total duration 0.25–0.35s and i-frames 0.10–0.17s; tune in playtest. Do not freeze velocity or introduce speed spikes.
2. Block, precision parry (initial 0.12–0.17s), posture damage, guard break, hitstun priority and recovery.
3. Keep Orcha's **Lightning Clone Substitution** as a separate integration handoff, not a prerequisite for A–C: timed L2 around incoming attack; decoy takes apparent hit, cracks into electricity, briefly stuns attacker, real player instantaneously appears at a collision-safe position behind attacker. Aki owns input/validation/i-frames/rear spawn/stun/counter window, but do NOT ship without approved art and explicit mechanic validation. Codex separately owns Chidori.

### Milestone D — Enemy and polish
1. One Rogue Ninja Bandit with telegraphed melee strike, approach/spacing, hitstun, knockback, optional block/dodge only if supported; test one-on-one before testing three bandits and crowd-hit behavior.
2. Development-only toggleable overlay: player state/animation, startup-active-recovery, buffer expiry, cancel permissions, velocity, target, hit confirm, enemy hitstun/posture.
3. Validate attack VFX separate from character sprites and align to world-space collision points. Avoid overlapping or unreadable debug UI.

## Deliverables
- **A:** concise audit report, code changes, automated transition tests, playable browser demonstration, owner test instructions.
- **B:** three-hit and dash attack, hitbox/hitstop tests, video/GIF or screenshots showing actual gameplay, PR.
- **C:** dodge/block/parry/posture with tests, PR.
- **D:** bandit one-on-one then three-enemy tests, diagnostics, polished VFX handoff, PR.
- Mandatory report for **every job**, including blocked work, in `orders/Aki/reports/YYYY-MM-DD-task-name-report.md` with pre-commit tests, exact commands, actual results, issues, questions, commits/PRs and deployed test URL/build ID after verified smoke test.

## Acceptance criteria / tests
- Sprint→light combo 1→2→3 without involuntary idle or momentum reset.
- Buffer attack shortly before cancel window; it executes once on eligibility and expires when stale.
- Attack→dodge only during legal cancel window; heavy/failed actions retain designed recovery.
- Run→jump→aerial attack→land→run and dodge→run have no unexpected idle animation.
- One enemy takes no unintended multiple hits per attack; knockback/stun direction matches impact.
- Hitstop does not lose input or corrupt physics state.
- Parry increases posture and guard break fires at correct threshold.
- Test keyboard and controller where supported, including browser export; record actual observed behavior, performance/frame pacing and console errors.
- Playtest at approved close camera scale; verify sprite foot alignment, collision, attack arcs and no clipping/regressions.
- For each gameplay milestone: test BEFORE implementation commit, create report, commit/push on dedicated branch, PR/integrate under repository policy, deploy to shared live browser test build, open it and verify; never claim done without live verification.

## Ownership and exclusions
**Aki:** controller, combat logic, hitboxes, enemy AI, defense, animation events and browser testing.
**Codex:** production character combat sprites, sword/slash and Chidori art.
**Orcha:** PixelLab Lightning Clone Substitution art prototype.
**Kiro:** no assignment.
Do not overwrite other agents' work, change camera/occlusion, create a full new enemy roster, bulk-regenerate character frames, or change RPG progression/world/death rules.

## Handoff / Notes
Start **Milestone A immediately when this QUEUED order reaches Aki's inbox on main**. Publish the first playable checkpoint and seek owner feel feedback before moving to B. The numerical windows above are **tuning hypotheses**, not extracted frame measurements.
