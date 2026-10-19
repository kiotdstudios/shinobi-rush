# Job Report — Combat System V1, Milestone A (Offensive Combat)
- Agent: Aki
- Order: orders/Aki/2026-10-19-combat-system-v1-milestone-a.md
- Date: 2026-10-19
- Final status: DONE — code+tests complete, CI green locally, browser demo verified, PR open
- Commit / PR: aki/combat-v1-milestone-a @ b384f9b, PR TBD (link once opened)

## What shipped

**Attack state machine** (`scripts/player/player_controller.gd`): four new states (`LIGHT1`,
`LIGHT2`, `LIGHT3`, `DASH_ATTACK`) layered onto the existing shared movement/dodge/jump state
machine — no separate combat controller fighting for velocity/animation ownership, per the order's
explicit instruction. Each attack runs STARTUP -> ACTIVE -> RECOVERY (timings from the order's own
60tps frame table, converted to seconds). Velocity is never reset: a `lunge` burst is *added* to
whatever velocity the player already had (same philosophy as the existing dodge burst), then decays
through `friction` for the rest of the swing — weighty, but momentum-preserving.

**Combo chaining**: a buffered/fresh `attack_light` press landing within an attack's `combo_window`
(measured from the start of recovery) cuts the remaining recovery short and begins the next hit;
light3 wraps back to light1 (no light4). Facing locks for the duration of a combo in progress; a
fresh (non-chained) light1 re-aims to whatever direction is currently held, so running into the
attack button throws the swing the way you're moving.

**Dash attack**: triggers either in the last 0.08s of an active dodge (cancels the dodge outright)
or within 0.15s after a dodge ends (a short "post-dodge grace" window). Both windows are short
enough that a deliberate plain light1 thrown a beat later still lands as a plain light1, which is
what the order's "ATTACK -> DODGE -> ATTACK" sequence needs.

**Dodge-cancel**: once an attack's recovery has committed past its `dodge_cancel_from` point, a
dodge press cancels the remaining recovery and begins a normal dodge — velocity carries straight
through, same as any other dodge entry.

**Hit registration**: deliberately NOT Area2D/collision layers. `_check_attack_hits()` is a manual
geometric check — reach + forward-arc around `facing8` — against every node in the `"enemy"` group,
each swing hitting a given enemy at most once (tracked in `_hit_targets`, cleared per swing). This
was the simplest option, is directly unit-testable as pure math, and satisfies "hitboxes register
accurately in every supported direction" by construction, since the arc is defined in the same
facing8 every other system in the file already uses.

**Hitstop**: local-only (`_hitstop_timer` on the player, mirrored on the Bandit), explicitly NOT
`Engine.time_scale`. While active it pauses only that entity's own velocity/position integration;
input buffers and attack timers elsewhere are untouched, per the order's explicit ban on a global
freeze that would desync input buffering/gameplay timers.

**Basic Bandit** (`scripts/enemy/bandit.gd` + `bandit_visual.gd` + `scenes/enemy/bandit.tscn`):
Idle -> Approach -> (take damage ->) Hit-react -> Die. Spawned by `training_arena.gd` a short walk
from the player's own spawn point. Milestone A scope only — attack/block/parry-reaction/guard-break
are explicitly Milestone B, same split the parent order itself uses. `take_damage()` applies
knockback + local hitstop + hit-flash, transitions to `DEAD` at 0 HP.

**Shared helper**: `WorldScale.snap8()` — the 8-direction snapping math was duplicated as a private
static on `PlayerController`; moved to `WorldScale` so the Bandit can use the exact same facing-8
convention without reaching into the player's internals.

## Zero new art required

`PlayerVisual.play_action()` already falls back cleanly to the procedural placeholder when an
animation id isn't in the manifest, so every new player action (`light1`/`light2`/`light3`/
`dash_attack`) and the entire Bandit (which has no character art at all yet) render as readable
placeholders and are fully playable and testable right now. Filed
`orders/Codex/2026-10-19-combat-v1-animation-request.md` listing exactly what's missing, following
the project's locked 128x128/8-direction/24fps art standard, plus an explicit owner-decision flag
on whether the Bandit gets real character art now or stays placeholder longer.

## Tests

New `tests/test_combat.gd` (registered in `tests/run_tests.gd`), covering the order's acceptance
tests that are in Milestone A's scope:
- Run -> 3-hit combo -> run, no idle state anywhere in the sequence, resumes MOVE immediately.
- Dodge -> dash attack without the velocity ever collapsing toward 0 across the transition.
- Attack -> dodge (cancelling recovery) -> a later plain light1 (not a dash attack, grace lapsed).
- Dodge-cancel right at an arena wall still respects collision (doesn't clip through).
- Mashing the attack button during startup/active never restarts or skips ahead in the combo.
- A Bandit takes exactly one hit per swing (hp drops once, not repeatedly during one active window),
  enters hit-react (checked at the instant the hit lands, not after its short reaction window has
  already expired), and dies at 0 HP after enough swings.

Full suite: **534 passed, 0 failed** (up from the 514-test baseline inherited from PR #30; 20 new
combat tests, all passing). `validate_godot_project.py` and `godot_ci.py import` both clean, zero
parse errors across all new/edited files.

Two bugs were caught and fixed during test authoring — both in the *test harness*, not gameplay
code: (1) a single-physics-frame `Input.action_press`+`release` doesn't reliably register as a
`just_pressed` edge in this headless harness (same issue `run_tests.gd`'s own helper already works
around) — fixed by holding for 3 frames; (2) the bandit hit-react assertion was reading `state`
after a 40-frame loop had already run past the ~13-frame hit-react duration, always seeing it
reverted to `APPROACH` — fixed by capturing state at the instant the hit is detected.

## Incidental fix

`scripts/ui/debug_hud.gd`'s on-screen control legend still listed `J` (light attack) under
"Reserved (no behavior yet)" alongside K/Q/E. Since J is now live gameplay, left it unfixed would
have shipped an inaccurate control legend as part of this very order's own "control mapping"
deliverable — moved it out of the reserved list into the live controls line.

## Browser verification

Exported the Web build and drove it with a self-contained Playwright script (serves the export dir
and controls Chromium in the same process): ran idle -> run -> 3-hit combo while still running ->
dodge -> dash attack -> walked to the Bandit -> landed several light attacks -> Bandit died
(confirmed via its on-screen "BANDIT (DEAD)" label and collapsed death pose in the final
screenshot). No console errors, no page errors, engine booted and ran the whole sequence cleanly.
`smoke.mjs` against the local export dir passes `webgl2-available`; its `build-info` check fails
locally by design (that file is only written when `GITHUB_SHA` is set, i.e. in real CI) — same as
every prior PR's local smoke run this session.

## Control mapping (current)

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD | Left stick / D-pad |
| Sprint | Shift | R1 |
| Dodge | Space | — (button 1) |
| Jump | F | — (button 0) |
| **Light attack (combo)** | **J** | **— (button 2)** |
| Pause | Esc | Options |
| Heavy attack, substitution, heal | K, Q, E | reserved, no behavior yet |

## Remaining art dependencies
See `orders/Codex/2026-10-19-combat-v1-animation-request.md`: player needs `light1`/`light2`/
`light3`/`dash_attack` (8-direction, 128x128, 24fps); Bandit has no art at all yet (owner decision
flagged on whether to produce it now or keep placeholder longer).

## Next steps
Milestone B (block, perfect parry, posture/guard-break, enemy attack telegraphs) and Milestone C
(hitstop/knockback/VFX/SFX polish, debug overlay, full acceptance-test closure) are separate,
later orders per the parent order's own milestone split — holding for owner confirmation before
starting either.
