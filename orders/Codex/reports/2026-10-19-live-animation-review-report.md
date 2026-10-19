# Job report - Live character animation review
- Agent: Codex
- Order: Order01 / explicit owner approval to publish all passed animations live
- Date: 2026-10-19
- Status: REVIEW - local verification passed; awaiting CI/merge/deploy
- Branch / PR: codex/player-128-runtime-assets / PR23

## Work
Added actual128RGBA jump v2 (192PNG) and dodge v1 (96PNG) to the existing runtime manifest with loop=false. All six animations now available in the game/lab. Existing idle/walk/run/sprint pixels unchanged. Jump/dodge remain animation review; no new controller physics/inputs added. Owner explicitly asked to review these in the live game.

Integration camera blockers: loaded art auto-opened lab, invalidating toggle behavior. Lab now always starts closed; tests explicitly open it. Browser camera probe now uses loaded figure height rather than assuming108px placeholder. WebBridge publishes read-only figure/sprite/lab metadata and physics frame count. Sprint-speed probe compares displacement per simulation tick to avoid uneven wall-clock sample intervals in slow software-rendered browsers; input displacement/state assertions remain required.

## Tests before commit
PinnedGodot4.7.2 import and resource validation PASS. Built-in test suite493PASS/0FAIL. PNG manifest validation PASS. Web debug export PASS. Final browser controls/smoke results appended before commit.847 runtime import sidecars generated with pinned engine and included; no .godot cache or Web export committed.

## Scope / ownership
Changes are limited to the authorized asset-to-live integration and necessary camera/lab verification corrections. Gameplay locomotion/state machine untouched; remaining combat/movement mechanics remain their assigned owners' work. Full Order01 remains incomplete.

## Issues
Browser software rendering caused uneven elapsed sampling in old sprint comparison; normalized physics ticks fix the measurement. Initial lab tests assumed auto-open; updated to assert startup closed and explicit open. All failures fixed and tests repeated before commit.

## Questions
None.

## Outstanding
Commit/push; wait for CI; merge approved PR without bypassing checks; verify Pages deployment SHA and browser game/lab. Status remains in progress until live verification.

## Final pre-commit verification
- python scripts/ci/validate_sprite_manifests.py: PASS847PNG/6animations,128RGBA.
- Pinned4.7.2 godot_ci.py import,validate-resources,tests: PASS493/0tests.
- godot_ci.py export/finalize-export to fresh external directory: PASS, single-threaded debug Web.
- PinnedPlaywright1.64.1 controls-probe.mjs: allPASS, including real jump/dodge lab selections, normalized sprint-speed check and both previous camera failures.
- smoke.mjs: allPASS, served-file hashes, build metadata, renderer/engine start, visible/nonblank1280x720canvas,input effect,zero fatal console messages.
- Evidence outside runtime tree: .tools/live-browser-checks/controls-final and smoke-final; Godot logs in isolated clone/godot-ci-logs. Local export is dirty working-tree test of parenta6fdfdde, not claimed as a deployed commit. CI will build exact pushed commit.
