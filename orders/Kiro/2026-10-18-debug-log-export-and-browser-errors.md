# ORDER — Browser debug log export and error capture
- Agent: Kiro
- Status: QUEUED
- Priority: P0
- Owner: Kiro (Web build, diagnostic export and QA)
- Collaborator: Aki (Godot runtime event producer)
- Branch/PR: Dedicated branch and PR, coordinate to avoid overlapping edits
- Dependencies: Actual Godot project, Web export/deployment and Aki telemetry events; may implement in parallel with CI bootstrap

## Objective
Make it easy for the owner to capture and share a reproducible debug session when testing Shinobi Rush in the browser.

## Context / References
Read `docs/development/DEBUG_TELEMETRY_SPEC.md` and `orders/Kiro/order_01.md`. Do not falsely claim a live build exists.

## Scope / Deliverables
- **Download Debug Log** control available in opt-in browser test builds; export structured JSONL (preferred) or JSON and optionally readable TXT with session ID, UTC start time, build SHA/version, engine/browser/platform details when available, event timestamps, frame and recent input/action/error history.
- **Copy Bug Report** action with last ~100 meaningful events, last error and steps/context for easy pasting; manual tester note field optional, must not collect typed content as raw keystroke events.
- Browser JavaScript `error` and `unhandledrejection` capture when exposed; bridge safely to Godot telemetry. Include Godot console diagnostics where feasible without promising inaccessible engine internals.
- Retain a bounded rolling buffer (e.g. last 5–10 minutes or capped count/size) and protect against floods; throttle high-frequency axis/mouse motion.
- Respect privacy: local-only by default, no background uploading, no secret/key capture, explicit user action for exporting or sharing, clear debug-on indicator. Keep release builds off by default.
- Browser refresh should not silently upload or persist logs; if optional persistence is proposed, request approval first.
- Add automated/smoke tests for export integrity, controller support where testable, and error capture. Verify browser download works on desktop; document mobile restrictions.
- Add instructions for tester to reproduce a bug, download log, and attach to an issue or share with agent.

## Acceptance Criteria / Tests
1. Download contains accurate build/session metadata and ordered keyboard/controller/interaction events from Aki instrumentation.
2. Induced browser error appears when supported, with timestamp and sanitized stack.
3. No keys, secrets, arbitrary typed strings, or hidden background telemetry captured.
4. Sustained play remains performant; buffer and throttle limits work.
5. Browser smoke test actually executed and logged, or explicit BLOCKED with missing Godot/Web setup.

## Handoff / Report
Write `orders/Kiro/reports/YYYY-MM-DD-debug-log-export-report.md`, record changed files, tests, issues, PR/commit and live URL/build ID when verified.
