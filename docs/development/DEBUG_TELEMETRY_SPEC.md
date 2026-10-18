# Shinobi Rush — Debug Input, Controller and Error Telemetry (P0)

## Purpose
While testing the Godot 4 Web game, the owner needs a **downloadable, timestamped debug trace** to diagnose control bugs, missed inputs, joystick issues, collisions, failed interactions, and runtime errors. Aki owns gameplay instrumentation; Kiro owns browser error bridge, export and smoke tests.

## Event schema (JSONL suggested)
```json
{"t_ms":12345,"utc":"2026-10-18T10:00:00Z","session":"local-test-id","build":"git-sha","frame":740,"scene":"forest_a","type":"input","device":"gamepad:0","raw":{"control":"axis_left_x","value":0.8},"action":"move_right","player":{"x":120,"y":44,"state":"run","facing":"E"}}
```
Use event types `input`, `action`, `interaction`, `combat`, `state`, `warning`, `error`, `browser_error`. Error entries include category, sanitized message/stack if available, last relevant action and scene. Record press/release, not arbitrary text. Record interaction attempt + result + reason.

## User experience
- Clearly visible **DEBUG ON** indicator in test builds, with a keyboard/controller-accessible toggle and filterable recent-event HUD.
- **Download Debug Log** and **Copy Bug Report** in the Web UI; local only unless user explicitly shares.
- Include time, build SHA, game state and last 100 events in quick reports.
- Joystick axes recorded on meaningful changes only (e.g. threshold ~0.1 or meaningful directional crossing), with configurable deadzone and sampling; no 60Hz unbounded dumps.
- A rolling buffer prevents unlimited memory growth. Preserve errors and recent causally relevant inputs.
- Never capture arbitrary text entry, passwords, API keys, personal data, or upload logs automatically.
- Default OFF for production builds; performance measured with telemetry on/off.

## Error-capture limitations
Godot may not expose every engine error to a GDScript logger. Capture gameplay assertions and explicit failures at source, plus exposed engine/browser errors; describe what is not captured. Browser console/JavaScript error bridging may require Web export configuration. Do not imply a complete crash dump is guaranteed.

## Validation scenarios
Keyboard movement; gamepad stick and D-pad; button mapping; R1 sprint; Circle dodge; Cross jump; L1 heal; L2 substitution; R2+face jutsu; Square/Triangle combat; interact/pickup/equip; rejected interaction; device disconnect/reconnect; forced safe error; download and inspect JSONL; 10-minute performance and buffer test.
