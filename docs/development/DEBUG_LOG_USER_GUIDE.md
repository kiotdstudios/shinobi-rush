# Debug log: tester guide

How to capture, download and share a debug log from the browser build. Contract for developers: [DEBUG_LOG_INTERFACE.md](DEBUG_LOG_INTERFACE.md).

## Turn it on (off by default)

- Open the game with `?debug=1` at the end of the URL, for example `https://kiotdstudios.github.io/shinobi-rush/?debug=1`.
- Or press `F9` in the running game to toggle debug on and off (`F9` is `dbg_toggle_debug`).
- A red **DEBUG ON  session <id>** label appears top-right with the buttons **Download Debug Log**, **TXT**, **Copy Bug Report** and an optional note field.
- Without `?debug=1` (or F9) nothing is captured: no listeners are installed and the panel is hidden.

## Reproduce a bug and share it

1. Open the game with `?debug=1` and reproduce the problem.
2. Click **Download Debug Log** (or press `F7`). You get `shinobi-debug-<UTC date>-<time>-<short SHA>.jsonl`.
3. Optional: click **Copy Bug Report** (or press `F8`) after typing a short note. It copies the last ~100 events, the last error and the build and session header.
   If the browser refuses the clipboard, a read-only text box appears: select the text and copy it by hand.
4. Attach the `.jsonl` file to the GitHub issue, or paste the report into it. Tell the agent which build URL and what you did.

Nothing is sent anywhere. Downloading and copying only happen when you click or press the key.

## What is collected (stays in the page until you export)

- Session id, UTC start time and build info (commit, run id, Godot version, page URL without query or hash).
- Browser details: user agent, platform, language, screen size, pixel ratio, CPU thread count, connected gamepad ids.
- Uncaught JavaScript errors and unhandled promise rejections (message, file name, line, sanitized stack) and console warnings and errors.
- Debug toggles, lifecycle events and, when the input telemetry exists, game events (input actions, state changes).
- Counters for what was dropped or coalesced.

Never collected: typed text (the note is only read when you press Copy), cookies, local storage, anything sent over the network, personal file paths
(`file:///C:/Users/<name>/` becomes `<local>`; query strings and token-like strings are removed from stacks and messages).
No data is written to storage and nothing survives a page refresh.

## Limits

At most 5000 events, about 2 MB and the last 10 minutes are kept; repeated errors are merged into one with a count, and a flood of errors is rate-limited
(`dropped` in the header shows how many were skipped).

## Not captured

Not every Godot engine error is exposed to the browser, so engine-internal errors that never reach JavaScript will not appear. GPU frame rate is not logged.

## Build info in the log (`unknown`)

CI bakes the commit SHA into the game build, so deployed builds name the file with the short SHA. A build exported on a laptop without the CI environment
reports `commit_sha` as empty and names the file `...-unknown.jsonl`.

## Mobile and browser caveats

- iOS Safari may open the downloaded file in a new tab or ask where to save it instead of downloading directly; use Share / Save to Files.
- Clipboard writes need a tap or click; if refused, use the fallback text box.
- Gamepads only show up after a button press, and browsers differ in which controllers they expose (not verified here for real hardware).
- Keyboard shortcuts `F7` to `F9` need a physical keyboard.
