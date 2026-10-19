# ORDER — Implement in-game debug input and interaction telemetry
- Agent: Aki
- Status: DONE — PR #13 merged into main at 0f940721cb73f41821bf7c1659a6f75d15fc691b. Key rebind (F6/F10/F11/F12 -> Ctrl+Alt+H/G/B/X) applied per Kiro's flag. Post-merge live-build verification and 3-min sustained CPU/memory profiling both passed, no leak. Hardware/engine limitations documented (no real gamepad hardware, no global GDScript exception hook, Ctrl+Alt layout variations not exhaustively tested). See orders/Aki/reports/2026-10-18-aki-chief-report.md and orders/Aki/reports/2026-10-18-debug-input-telemetry-report.md for full detail.
- Priority: P0
- Owner: Aki (runtime gameplay instrumentation)
- Collaborator: Kiro (browser capture/export/QA)
- Branch/PR: aki/debug-input-telemetry-producer -> PR to be opened against main (per order: do not write to main)
- Dependencies: Actual Godot project/controller code; coordinate if not yet present
- Report: orders/Aki/reports/2026-10-18-debug-input-telemetry-report.md

## Objective
Implement an **opt-in debug log** for Shinobi Rush playtesting that records input, controller actions, interactions, gameplay transitions, and errors so bugs can be reproduced precisely.

## Context / References
Read `docs/development/DEBUG_TELEMETRY_SPEC.md`, `orders/README.md`, and locked gameplay rules. Do not change game behavior just to collect logs.

## Scope / Files owned
Runtime Godot input/event instrumentation and debug HUD/overlay. Coordinate files with Kiro; Kiro owns browser export and downloadable logs.

## Deliverables
- Toggleable DEBUG mode (off by default in release; on/opt-in in test builds), visible DEBUG indicator and session ID.
- Timestamped structured records with monotonic elapsed time, frame number, scene/map, player position, facing, state, equipped action, source device and event type.
- Keyboard: key down/up, scancodes/keycodes and mapped actions; ignore OS text/IME and never record typed text/passwords.
- Gamepad: device connect/disconnect, controller name/ID, buttons down/up, D-pad, left/right stick axis values **with deadzone and change thresholds**, triggers, input mapping and resulting actions. Include DualSense where supported, but gracefully handle browser limitations.
- Interactions: nearby prompt, interact attempt, target ID/type, accepted/rejected and reason, inventory/equip changes, attacks, hitboxes/hits, dodge/perfect dodge, jutsu, cooldown, NPC dialogue, item pickup, scene transitions, saves.
- Errors: Godot errors/warnings where exposed, script exceptions, missing resources, unexpected states, failed actions, collision/animation errors and uncaught Web runtime errors via Kiro's integration. Never claim all engine errors are capturable if runtime APIs do not expose them.
- On-screen compact debug HUD showing recent events, last input, mapped action, player state and error count; filters for INPUT, GAMEPAD, INTERACTION, COMBAT, ERROR and adjustable verbosity.
- Circular buffer and throttling/coalescing to avoid huge logs; preserve important errors and state changes. Reproduce bugs without debug instrumentation materially changing input latency.

## Acceptance Criteria / Tests
1. Verify keyboard press/release and mapped action appear together, with no typed text captured.
2. Verify joystick drift/deadzone, both sticks, buttons, triggers, D-pad and connect/disconnect where devices/browser support them.
3. Verify successful and failed interactions record target, outcome and reason.
4. Force a safe test error and ensure a clearly labeled ERROR record with context; explain limits of Godot error capture.
5. Reproduce input during sprint/dodge/attack/jump and confirm gameplay remains responsive.
6. Check DEBUG off incurs minimal overhead; inspect memory/CPU under sustained play.
7. Playtest actual Godot Web build with Kiro; include exact test evidence or blockers.

## Handoff / Report
Write `orders/Aki/reports/YYYY-MM-DD-debug-input-telemetry-report.md`, list test results, screenshots, commits, PR, questions and browser deployment verification. If the Godot project is absent, report BLOCKED and coordinate rather than inventing a working implementation.
