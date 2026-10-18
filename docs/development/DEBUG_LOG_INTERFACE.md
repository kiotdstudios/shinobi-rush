# Debug Log Interface Contract

Contract between the in-game event producer (Aki, `DebugTelemetry`) and the browser-side debug layer (Kiro, `BrowserDebug`).
Event fields follow [DEBUG_TELEMETRY_SPEC.md](DEBUG_TELEMETRY_SPEC.md). Either side can merge first; neither requires the other.

## Ownership

| Area | Owner | Location |
|---|---|---|
| Event producer: input, action, interaction, combat, state, warning, error instrumentation; debug HUD; GDScript ring buffer; autoload `DebugTelemetry` | Aki | `scripts/debug/**` |
| Browser side: autoload `BrowserDebug`, JS `error` / `unhandledrejection` bridge, console diagnostics, session/build/browser metadata, export (JSONL, TXT), Copy Bug Report, debug panel, `DebugStore` | Kiro | `scripts/web/**`, debug panel scene |

Kiro does not create files under `scripts/debug/`. Aki does not edit `scripts/web/**`.

## DebugTelemetry (Aki, autoload at `/root/DebugTelemetry`)

```gdscript
var enabled: bool                              # default false
signal event_recorded(event: Dictionary)
func record(type: String, data: Dictionary) -> void
func recent(n: int) -> Array                   # newest last, Array[Dictionary]
func export_jsonl() -> String                  # events only, one JSON object per line
```

`BrowserDebug` uses it when `/root/DebugTelemetry` exists and works without it.

## BrowserDebug (Kiro, autoload)

```gdscript
var enabled: bool                              # true only with ?debug=1 or the documented toggle
var session_id: String
signal debug_toggled(on: bool)
func set_enabled(on: bool) -> void             # also sets DebugTelemetry.enabled when present
func record(type: String, data: Dictionary = {}) -> void   # goes to DebugStore (Kiro-owned events)
func recent(n: int = 100) -> Array             # merged view, ordered by t_ms
func export_jsonl() -> String                  # header line + merged events
func bug_report(note: String = "") -> String   # last ~100 events, last error, context, header
func download_log() -> void                    # explicit user click only
func copy_bug_report(note: String = "") -> void # explicit user click only
```

Producers (Aki) call `DebugTelemetry.record(...)`. Kiro never calls it for browser events.
Aki may call `BrowserDebug.record(...)` for events that should survive without `DebugTelemetry`, but is not required to.

## Event fields

Every event is one JSON object per line. Core fields are set by the recorder and cannot be overridden by `data`.

| Field | Type | Notes |
|---|---|---|
| `t_ms` | int | Milliseconds since session start. Single clock for both sides: `Time.get_ticks_msec() - session_start_ticks`. |
| `utc` | string | `YYYY-MM-DDTHH:MM:SSZ`, derived from session start and `t_ms`. |
| `session` | string | Session id, same value in the header. |
| `build` | string | Commit SHA (short or full). |
| `frame` | int | `Engine.get_process_frames()`. |
| `type` | string | `input`, `action`, `interaction`, `combat`, `state`, `warning`, `error`, `browser_error`. |

Optional per spec: `scene`, `device`, `raw`, `action`, `player` `{x, y, state, facing}`, `category`, `message`, `stack`, `last_action`.
`browser_error` carries `message`, `source` (basename), `line`, `col`, `stack` (sanitized), and `count` / `last_t_ms` when coalesced.
Record press/release only. Never record typed text.

## Session header (first JSONL line)

`type: "session_header"`, `schema`, `session`, `utc_start`, `t_ms`, `build` `{commit_sha, run_id, godot, page_url}`,
`env` `{userAgent, platform, language, screen, devicePixelRatio, gamepads, hardwareConcurrency}`,
`limits` `{max_events, max_bytes, window_ms}`, `dropped` (by reason plus `total`), `coalesced`, `events`, `bytes`.

### Build info source (`build.commit_sha`, `build.run_id`, filename short SHA)

- The debug code makes **no network request** (it does not fetch the served `build-info.json`).
- `scripts/ci/godot_ci.py export` writes an identity-only `res://build-info.json` into the project directory just before the Godot export and
  deletes it again afterwards (`finally`, also when the export fails). It holds `commit_sha`, `head_sha`, `run_id`, `run_attempt`, `ref`,
  `repository`, `built_at`, `godot_version`, taken from the same environment variables as `finalize-export` (`GITHUB_SHA`, `PR_HEAD_SHA`,
  `GITHUB_RUN_ID`, ...). The file is inside the PCK (`include_filter="*.json"`); `BrowserDebug` reads it with `FileAccess`.
- The served `build-info.json` written by `finalize-export` is a different file (it carries file hashes, so it cannot be embedded). The debug
  probe checks that the downloaded header's `build.commit_sha` equals the served file's `commit_sha`, and that the download filename carries
  its first 7 characters (`shinobi-debug-<UTC>-<sha7>.jsonl`). This is enforced when `GITHUB_SHA` is set (CI).
- **Local runs without CI environment** (`GITHUB_SHA` unset, editor runs, `godot_ci.py export` on a laptop): no `res://build-info.json` exists,
  `build.commit_sha` is `""` and the filename says `unknown`. Set `GITHUB_SHA=<40-hex>` before `export` to test the baked path locally.
  `window.__SHINOBI_BUILD_INFO__` (if a page defines it) is merged over the baked values.

## Merge and ordering rules

- The export is ordered by `t_ms`, ascending.
- Ties keep `DebugTelemetry` events before `BrowserDebug` events (stable merge, producer first).
- Within one side, order is record order.
- Events with a missing `t_ms` are treated as 0 and should be avoided.
- Both sides must use the same session clock (`t_ms` above) so merging is meaningful.

## Throttle contract

Producer (Aki) throttles at the source; Kiro's recorder enforces limits again as defense in depth. Do not rely on either side alone.

- Axes: record only on meaningful change (delta >= 0.1, deadzone 0.05, crossing to or from zero, sign flip). No 60 Hz dumps.
- Pointer motion: only after >= 8 px and >= 50 ms.
- Token buckets per type (burst / refill per second): `browser_error` 10 / 2, `error` 20 / 5, `warning` 20 / 5, all others 200 / 200.
  Events over the limit are discarded and counted in `dropped.rate_limited`.
- Identical `error`, `warning` and `browser_error` events (same message, source, line, col) are coalesced into one event with `count`.
- Rolling buffer bounds, all enforced together: 5000 events, 2 MB (approximate JSON text size), 10 minutes.
  Evictions are counted in `dropped.evicted_count`, `evicted_bytes`, `evicted_window`.
- `dropped.total` is exported in the header.

Constants live in `scripts/web/debug_store.gd` and are the source of truth.

## Sanitization

All string fields are sanitized by `DebugSanitizer` before storage: URL query and hash removed, local user paths mapped to `<local>`,
token-like strings (`ghp_`, `gho_`, `github_pat_`, `AKIA`, `Bearer`, long hex, long base64) replaced with `<redacted>`,
text capped at 500 characters, stacks capped at 12 frames and 2000 characters. Producers should still avoid putting secrets in events.

## Privacy

No network calls and no persistence (no localStorage, IndexedDB or cookies) in the debug code. Data lives in memory until the user
explicitly downloads or copies it. A refresh clears it.
