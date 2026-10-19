# Job Report — Gameplay debug input/interaction telemetry producer
- Agent: Aki
- Order: orders/Aki/2026-10-18-debug-input-telemetry.md
- Date: 2026-10-18
- Final status: REVIEW (not DONE — PR open, awaiting review/merge; do not mark complete per explicit instruction until the full logging system is verified end-to-end post-merge)
- Commit / PR: branch `aki/debug-input-telemetry-producer`; PR to be opened against `main` (order forbids writing to `main` directly)

## Work completed
Implemented the gameplay-side event producer (`DebugTelemetry`, new autoload) that Kiro's already-merged browser-side system (`BrowserDebug`/`DebugStore`/debug panel, PR #10, `0f01f81`) was built to receive, per `docs/development/DEBUG_LOG_INTERFACE.md`.

- New autoload `DebugTelemetry` (`scripts/debug/debug_telemetry.gd`), OFF by default, wired into `project.godot` between `WebBridge` and `BrowserDebug` (ordering matters: `BrowserDebug` toggles `DebugTelemetry.enabled` directly).
- Reuses Kiro's `DebugStore` class by **instantiating** it (never edits `scripts/web/**`), so both sides share one throttle/coalesce/eviction/export implementation and merge cleanly by `t_ms`.
- Captures:
  - **Keyboard**: press/release via `_input`, mapped action name resolved from the live `InputMap`, physical/virtual keycodes only — `.unicode`/`.as_text()` are never read, so no typed text or IME output can leak (unit-tested).
  - **Gamepad**: buttons, axis motion (reuses `DebugStore.record_axis`'s deadzone 0.05 / delta 0.1 / sign-flip throttle), connect/disconnect via `Input.joy_connection_changed`. DualSense/real hardware not independently verified — same caveat Kiro's own report carries for the browser side.
  - **Movement/state**: lazily finds the player (`get_first_node_in_group("player")`), connects to `PlayerController.state_changed`, records position/state/8-point facing snapshots.
  - **Interaction / combat**: `record_interaction()` / `record_combat()` helpers, fully implemented and unit-tested, but currently have no in-game caller — the prototype only has movement implemented (`player_controller.gd`: "Combat, jump, dodge etc. are reserved actions with no behavior yet"). Ready for whoever builds those systems; no fake gameplay was invented to produce traffic.
  - **Warnings/errors**: explicit `record_warning()`/`record_error()`, plus `force_test_error()` (bound to F10) for acceptance criterion #4 — a deterministic, safe, caught test error. Godot 4 has no global exception hook, so this file never claims a full crash dump; real unhandled errors are only visible if they reach the browser console (Kiro's path) or an explicit call here.
- New on-screen overlay (`scripts/debug/debug_telemetry_overlay.gd` + `scenes/debug/debug_telemetry_overlay.tscn`), spawned dynamically by `DebugTelemetry` (same pattern Kiro used for the debug panel — not placed in `main.tscn`). Bottom-left band, positioned to avoid Kiro's top-right panel and the existing top-left `DebugHud`. Shows last input/action, player snapshot, error count, recent events (compact or verbose), filterable by type.
- New input actions (keyboard-only, F6/F10/F11/F12 — verified against every existing `physical_keycode` in `project.godot`, no collisions): `dbg_toggle_telemetry_hud`, `dbg_force_test_error`, `dbg_telemetry_filter_cycle`, `dbg_telemetry_verbosity_cycle`.
- Found and fixed a real bug during testing: the overlay's auto-show logic would silently override a manual F6 hide every frame (the user-hidden state was never tracked) — fixed with an explicit `_user_hidden` flag.

## Files changed
- `scripts/debug/debug_telemetry.gd` (new)
- `scripts/debug/debug_telemetry_overlay.gd` (new)
- `scenes/debug/debug_telemetry_overlay.tscn` (new)
- `tests/test_debug_telemetry.gd` (new, 32 checks)
- `tests/run_tests.gd` (wired the new test file in)
- `project.godot` (new autoload entry; 4 new keyboard-only input actions)
- `orders/Aki/2026-10-18-debug-input-telemetry.md` (status QUEUED → REVIEW)

No files under `scripts/web/**` or `scripts/ui/debug_panel.gd` were touched, per the ownership split in `DEBUG_LOG_INTERFACE.md`.

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot --headless --import` (project import / global class cache) | PASS | clean import, no errors |
| `python scripts/ci/godot_ci.py validate-resources --project .` | PASS | `validated 24 scripts, 5 scenes, 0 resources, 0 failures` |
| `python scripts/ci/validate_godot_project.py --project . --repo-root .` | PASS | `0 error(s), 0 warning(s)` |
| `python scripts/ci/validate_orders.py` | PASS | `Agent READMEs and order structure validated.` |
| `python scripts/ci/godot_ci.py tests --project .` (full headless GDScript suite incl. new `test_debug_telemetry.gd`) | PASS | `SUMMARY: 289 passed, 0 failed`, exit 0, only one pre-existing unrelated WARNING |
| `python scripts/ci/godot_ci.py export --project . --out <tmp>/index.html` (Web DEBUG export) | PASS | clean export, no SCRIPT ERROR lines |
| `node scripts/ci/smoke/debug-probe.mjs` against the exported build (real headless Chromium) | 25/26 checks PASS | Keyboard/error capture, flood-safety (20k induced errors → bounded 9.4KB/39 events), no typed-text leak, no network/storage writes, download/copy flows all verified live in-browser. 1 FAIL: `build-identity` — expects a 40-hex commit SHA in `build-info.json`, which the export step itself logs is skipped locally (`GITHUB_SHA unset`); this is a known CI-environment-only gap, not a regression from this change. |
| `node scripts/ci/smoke/controls-probe.mjs` against the exported build (debug OFF, default) | PASS | movement/sprint/wall-collision/responsiveness unchanged with the new autoload loaded; 0 console errors — confirms criterion #6 (minimal overhead when OFF) |
| Ad-hoc Playwright check: sprint with `?debug=1` | PASS | `dx 349.6, state SPRINT, sprinting true, fps 5, 0 console errors` — confirms criterion #5 (gameplay stays responsive with telemetry capturing live input) |

## Issues encountered
- First test run failed because the global GDScript class cache hadn't been built yet (`godot --headless --import` must run before `--script res://tests/run_tests.gd`, matching `godot_ci.py`'s own step order) — not a code bug, just a missing step on my first local run.
- Two real bugs found and fixed during test-writing (see Work completed): the overlay's F6-hide-gets-overridden bug, and `get_node()`/`get_tree()` calls in `_sync_session()` / `_player_snapshot()` / `_current_scene_name()` throwing when the node isn't inside the scene tree (now guarded with `is_inside_tree()` checks; harmless in the real game since the autoload is always in the tree, but it made the unit tests noisy and was worth guarding properly anyway).
- `record_interaction()` / `record_combat()` have no real caller yet — the prototype has no combat/interaction/NPC gameplay implemented (confirmed via repo-wide search, nothing under those names exists outside the player/movement/debug scripts). This is a known, expected gap, not something I should fabricate behavior to paper over.
- No dedicated CPU/memory profiling run was done under *sustained* play (acceptance criterion #6's "inspect memory/CPU under sustained play" is only partially covered — by the flood-safety numbers and the controls-probe parity check, not a long-running profiler session).

## Questions for project owner
- Should `record_interaction`/`record_combat` be wired up now as stub calls somewhere, or left fully dormant until Orcha/whoever builds those gameplay systems actually exists? I left them dormant per "do not change game behavior just to collect logs."
- Is a dedicated sustained-play CPU/memory profiling pass required before this can go DONE, or is the flood-safety + responsiveness-parity evidence above sufficient?

## Outstanding work / next steps
1. Open PR from `aki/debug-input-telemetry-producer` → `main`, referencing this order.
2. Coordinate with Kiro / project owner on review and merge (order explicitly forbids writing to `main` directly).
3. After merge: update/verify the live Web test build per `orders/README.md`'s deployment sequence, re-run the browser smoke probes against the deployed build, and only then move this order to DONE with a follow-up report note.
