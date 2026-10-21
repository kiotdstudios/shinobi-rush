# Report: Combat Fluidity Overhaul V1, Milestone A (audit, buffering, transitions)

- Agent: Aki | Order: `orders/Aki/2026-10-20-combat-fluidity-overhaul-v1.md` | Branch: `aki/combat-fluidity-milestone-a`
- Status: Milestone A delivered; awaiting owner feel feedback before Milestone B.

## 1. Audit (exact code paths, before editing)
All player locomotion and combat live in ONE script, `scripts/player/player_controller.gd`, one `velocity`, one `move_and_slide()` per tick. There is no second script writing velocity or animation, so no cross-script fight exists.

| Concern from the order | Finding |
|---|---|
| Forced idle gaps | None on valid transitions. Attack end, dodge end and jump end all pick MOVE/SPRINT/IDLE from the live input on the same tick. |
| Zeroed velocity | None on action entry. Dodge sets burst speed; attacks ADD lunge; jump leaves velocity alone. Ground attacks bleed velocity via friction (intentional weight). |
| Conflicting animation writes | Only `visual.play_action` / `set_pose` from this script. Animation-finished gates: none; durations come from `visual.action_duration` timers, not signals. |
| Input buffer | Already 0.12s (inside the 100-150ms target), shared by attack, dodge and jump. |
| **GAP 1: hitstop dropped input** | Hitstop returned before presses were read, so a press inside the 3-4 tick freeze was lost and buffers kept decaying. Fixed. |
| **GAP 2: no aerial action** | An attack pressed during JUMP was buffered, expired in 0.12s and never fired. Run -> jump -> aerial attack -> land -> run was not possible. Fixed. |
| **GAP 3: no diagnostics** | Buffer and cancel permissions were invisible. Fixed. |
| "One authoritative transition layer" | Partially true already (single script, fixed priority: attack > dodge > jump in the buffered branch). Rules were scattered across two functions. I did NOT rewrite it; I added `cancel_eligibility()` as the single queryable statement of the rules and made tests and overlay read it. A full table-driven rewrite is a larger refactor I'd propose only if feel testing shows a need. |

## 2. Changes
- Presses captured on every tick including hitstop; buffers do not decay during hitstop (windows resume where they stopped).
- New `AIR_ATTACK` state + `air_attack` def (5/4/10, no lunge, no chain). The jump arc and landing timer keep running underneath; momentum is kept and input steers at air-control rate; the swing hands back to JUMP if still airborne, or lands straight into MOVE/SPRINT/IDLE. No dodge-cancel in the air.
- `cancel_eligibility()` and `debug_snapshot()`; the F1 diagnostics panel now has a Combat block (state/phase/combo, live buffers, combo/dodge/dash/air permissions, hitstop).

## 3. Tests (pre-commit)
Commands: `python scripts/ci/godot_ci.py import|tests|export --project .`, `validate_godot_project.py`, `controls-probe.mjs` (local).
- Full suite: **548 passed, 0 failed** (was 534). 14 new checks: air attack enters and lands into MOVE with no IDLE and no momentum collapse; stale early-dodge attack press expires; press during hitstop is captured and fires once it ends; eligibility/snapshot queries.
- One test caught a real design flaw on the first run: a quarter-strength ground bleed in the air dropped velocity to 39 px/s, so I removed the bleed for aerial swings.
- `validate_godot_project`: 0 errors. Controls probe vs local export: PASS (move-right dx 262.5).
- Browser (Chromium, software render ~5fps): jump then J during the arc gave `AIR_ATTACK > JUMP > MOVE`, 0 console errors. Frame pacing in this headless renderer is far below real hardware, so feel is NOT judged from it.

## 4. Not done / questions
- Controller input was not tested (no gamepad in this environment; keyboard only).
- Existing coverage already handles sprint -> combo, dash attack, attack -> dodge, buffer expiry in-attack; I did not duplicate it.
- Air attack has no art (placeholder). Needs a Codex request if the owner likes it; `air_attack` animation, 8 directions, 128x128.
- Q for owner: after the swing ends mid-air the jump animation restarts from its first frame; acceptable, or should it resume mid-arc?

## 5. Owner test steps
Hold D (run). Tap F to jump, then J mid-air: you should swing without stopping, land and keep running. Mash J on the ground to confirm no restarts. Press F1 (diagnostics toggle) to watch buffers and cancel flags live.

## 6. Commits / PR / deploy
Filled in after merge (see PR).
