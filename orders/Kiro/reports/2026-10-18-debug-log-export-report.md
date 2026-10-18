# Job Report — Browser debug log export and error capture
- Agent: Kiro
- Order: orders/Kiro/2026-10-18-debug-log-export-and-browser-errors.md
- Date: 2026-10-18
- Final status: REVIEW (not DONE; not deployed; PR CI evidence is added in a follow-up commit)
- Commit / PR: branch `kiro/debug-log-export`; PR URL and head SHA are added in the report-only follow-up commit

## Work completed
- Opt-in debug (`?debug=1` or F9, off by default) with a `BrowserDebug` autoload and a canvas-drawn panel: DEBUG ON label + session id, Download Debug Log (JSONL), TXT, Copy Bug Report with clipboard fallback text box, optional tester note.
- JS `error`, `unhandledrejection` and console warn/error capture, sanitized (query strings, local paths, token-like strings, length and frame caps), coalesced and rate limited.
- Bounded buffer (5000 events / ~2 MB / 10 min), `dropped` counters, per-type throttles. Works with or without Aki's `DebugTelemetry` (merge by `t_ms`). No Aki code existed on main when this was written.
- Build identity: `godot_ci.py export` bakes `res://build-info.json` into the PCK when `GITHUB_SHA` is set, so the log header carries the commit SHA; local exports report an empty SHA and `-unknown` in the file name.
- Playwright `debug-probe.mjs` added to the pre-deploy smoke job only (post-deploy smoke not extended: not provably deterministic).
- Docs: DEBUG_LOG_USER_GUIDE.md, DEBUG_LOG_INTERFACE.md, small additive note in GODOT_PROJECT_HANDOFF.md.

## Files changed
scripts/web/ (browser_debug, debug_store, debug_sanitizer, debug_export), scripts/ui/debug_panel.gd, scenes/ui/debug_panel.tscn, project.godot (autoload + dbg_toggle_debug F9, dbg_download_log F7, dbg_copy_report F8), tests/ (test_debug_store, test_browser_debug, test_debug_export, bench_debug, run_tests wiring), scripts/ci/smoke/ (debug-probe.mjs, lib/debug-probe-lib.mjs + test), scripts/ci/godot_ci.py + scripts/ci/tests/test_project_build_info.py, .gitignore, .github/workflows/godot-ci.yml (probe step only), docs/development/ (USER_GUIDE, INTERFACE, HANDOFF), this report, order Status line.

## Tests run before commit
All local results are VERIFIED on Windows with Godot 4.7.2 and Playwright 1.64.1 Chromium headless-shell (SwiftShader).

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import`, `validate-resources` | exit 0, 20 scripts, 0 failures | local run |
| `check_workflows.py`, `validate_orders.py`, `validate_godot_project.py --project .` | OK / OK / PASS 0 err 0 warn | local run |
| `godot --headless --script tests/run_tests.gd` (also via `godot_ci.py tests`) | 245 passed, 0 failed, no leak warnings | local run; a Node leak in test_debug_export was found and fixed |
| `python -m unittest discover` in scripts/ci/tests | 140 OK (also with GITHUB_SHA set) | local run |
| `node --test` in scripts/ci/smoke | 36 pass, 0 fail | local run |
| `godot_ci.py export`, `finalize-export`, `check-export --expect-sha` | exit 0, build-info.json in PCK, file removed afterwards | local run |
| `smoke.mjs --serve-dir` (real Chromium) | PASS 11/11, no fatal console events | local run, screenshots opened and checked |
| `controls-probe.mjs` | VERDICT PASS | local run |
| `debug-probe.mjs` | VERDICT PASS: hooks, JSONL header, ordered events, induced error and rejection with sanitized stack, no typed text, 20k flood bounded (~4.3 KB, dropped >0), bug report ~4.3 KB, no network, no storage writes, OFF by default | local run, evidence JSONL kept in ev/debug (not committed); build-identity check enforced when GITHUB_SHA is set |
| Screenshots with `?debug=1` and without | Panel top-right does not overlap the HUD (an overlap was found and fixed); OFF looks like the normal game | opened and inspected |
| Microbenchmark `tests/bench_debug.gd` (headless GDScript, Windows native) | record 120.8 us/call (~8.3k/s), 140.6 bytes/event, export of 20000 events 2.81 MB in 0.46 s, disabled record 1.41 us/call | local run, manual, not in CI |
| Soak (30 virtual minutes, injected clock, 1.53M record calls) | PASS: kept=5000, max bytes 687 KB (cap 2 MB), static memory +96 B after warm-up | local run; virtual clock, NOT a wall-clock 10 minute run |
| GitHub PR checks | PENDING at the time of writing | filled in by the follow-up commit with run URLs |

## Issues encountered
- Not verifiable here (ASSUMED, not tested): real controller hardware, DualSense in browsers, iOS Safari download and share behavior, mobile clipboard permissions, GPU frame rate (SwiftShader FPS of 3-6 is not meaningful, with debug on or off), wasm-side per-event cost (benchmark is native).
- Not every Godot engine error is exposed to JavaScript, so engine-internal errors may be missing from the log.
- Panel buttons are canvas-drawn, so the probe triggers Download and Copy with F7/F8 key presses, not button clicks.
- Running Godot in the console interactively once hung at a `debugger>` prompt; output was redirected to a file.
- No reply from Aki on PR #2; the interface was written to work without `DebugTelemetry`.
- The full manual download/copy flow on the deployed URL is NOT done and must be done after merge and deploy.

## Questions for project owner
None.

## Outstanding work / next steps
- Orchestrator: review, merge, then verify the deployed build (download and copy flow on the live URL, live smoke result) before any DONE.
- Aki: integrate `DebugTelemetry` per DEBUG_LOG_INTERFACE.md (summary posted on PR #2).
- Orcha: camera events can be logged through `record()` once the camera lands.
- Live deployment: not yet done; not claimed.
