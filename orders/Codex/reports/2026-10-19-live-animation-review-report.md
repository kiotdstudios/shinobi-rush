# Job report - Live character animation review
- Agent: Codex
- Order: Order01 / explicit owner approval to publish all passed animations live
- Date: 2026-10-19
- Status: DONE - live publication job verified; full Order01 remains IN_PROGRESS
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

## Final integration follow-up before commit
Removed engine-added ground ellipse in SpriteActor and placeholder visual, matching owner's shadow-free request. Native source PNGs unchanged. Python CI commit-ID fixture now uses its temporary project for fake-PCK validation instead of scanning newly added production sprites; production export validation remains strict. Before commit:140Python tests PASS,36Node tests PASS,493Godot tests PASS, fresh Web export PASS, shadow-free browser smoke PASS. Inspected settled game screenshot: actual player_128 sprites, no ellipse beneath player. Controls probe previously passed allmovement/sprint/camera/jump/dodge selections and its code is unchanged by this visual/fixture follow-up.

## Verified live publication
- Asset/integration commits7bd1a3bbf30a0a15e34fba84aabac97ccd23b7b4 and5f12842f944df3cd401ded1e6e7217965f35ad3a.
- PR23 merged after all three PR workflows passed. Merge/deployed SHA:d9ebccfbc77400424fcd1e1558e2daeaaa612d7a.
- Pages pipeline run39223465511: import/build/export,pre-deploy browser,Pages deployment,post-deploy live smoke and final gate allSUCCESS.
- Live URL:https://kiotdstudios.github.io/shinobi-rush/?camera=close. build-info.json fetched and matched exact deployedSHA,kindgame.
- Own Playwright1.64.1 live smoke PASS: HTTP200,all9served file hashes matchbuild,engine/canvas/input,zero fatal console errors.
- Own live touch-pointer review PASS: loadedplayer_128;Lab button opens;Anim arrows selectjump anddodge;zero page/consoleerrors. Inspected live dodge screenshot: realcharacter/stand,corrected6-animation set and no rendered shadow. Evidence:.tools/live-browser-checks/live-smoke and live-touch.
- Review controls:Lab button,Anim arrows,Dir arrows,Speed buttons,Pause/Step. Jump/dodge are lab-animation review; gameplay inputs remain reserved rather than pretending new mechanics exist.
- Verified at:2026-10-19T08:37:19.984394+00:00

Remaining Order01 work: combat/hit/equipment/VFX and gameplay integration/tuning beyond this review delivery. No blocker remains for viewing the published animation set.
