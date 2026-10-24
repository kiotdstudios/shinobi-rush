# Combat Fluidity Milestone B (offensive combat) report

Date: 2026-10-23. Branch `aki/combat-milestone-b`. Started on owner's instruction (jump look redesign deferred; 0.4x air cap unchanged).

## Audit
Milestone A already had the 3-hit light combo, dash attack, buffers, hitstop (buffer survives), single-hit-per-swing and dodge cancel. Missing for B: authored event markers, hit-confirm rules, a finisher that ends the chain (light3 used to wrap to light1 = infinite chain), whiff-restricted cancels, a reusable hit event, and swing/contact FX + audio.

## Changes
- `AttackDef`: `chains_to`, `heavy`, `confirm_window_bonus`, `whiff_cancel_delay`, `confirm_only_cancel`, `event_markers()`, `combo_window_for()`, `dodge_cancel_from_for()`. Tick values unchanged (5/4/9, 6/4/11, 9/5/15, 6/5/13).
- Rules: light1->light2->light3 chain; light3 and dash attack are finishers (no chain). Connected swing widens combo window (+4 ticks) and opens dodge cancel on time; whiffed swing opens it 3 ticks later; whiffed light3/dash attack cannot dodge-cancel at all.
- `PlayerController`: signals `attack_event(name, attack_id)` (startup/active/recovery/combo_open/combo_close/cancel_open/end) and `attack_hit(HitEvent)`; `hit_confirmed` in diagnostics.
- `HitEvent` (new), `HitFx` (new, procedural): slash arc drawn from the same reach/half-angle/facing as the hit test, contact sparks, bright impact silhouette, synthesized swing/hit audio (no audio assets exist). Camera not touched.

## Tests
`tests/test_combat_b.gd` (+43 checks): tick table, hitstop ranges (light 40-60 ms, finisher 70-100 ms), marker order, one hit per swing, hit event data, arc==hitbox, all 8 facings (in/behind/side/out of reach), hit-confirm window, finisher ends chain, whiff cancel blocked / connected cancel works, physics preserved in hitstop.
Command: `python3 scripts/ci/godot_ci.py tests --project . --godot $GODOT` -> `SUMMARY: 1885 passed, 0 failed`, exit 0, no engine error lines.

## Not done / open
- No GIF/screenshots of real gameplay yet; game feel (timings, arc brightness, audio) needs live playtest.
- Swing/hit sounds are placeholder synthesis; arcs are procedural, not Codex art.
- Camera hit kick (CameraImpact) intentionally not wired (camera excluded by order).
- Jump look redesign deferred.
