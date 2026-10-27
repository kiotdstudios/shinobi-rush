# Job Report — Fluid summoning smoke revision
- Agent: Codex
- Order:2026-10-20-summoning-jutsu-art.md; owner asked for more fluid, dynamic, smoky motion
- Date:2026-10-20
- Status: REVIEW
- PR:https://github.com/kiotdstudios/shinobi-rush/pull/36; report prepared before revision commit

## Work completed / files changed
Replaced12 flat circular-puff frames with29 unique native25FPS frames: shaded rolling billows, evolving internal curls, openings and wispy fragments. Smoke now lasts1160ms rather than840ms; still starts1100ms after sequence start, after the seal has formed. Future hidden-spawn recommendation1740ms and conservative clear/reveal2260ms. Full review loop stays2600ms. Updated independent smoke PNGs, import sidecars, opt-in metadata, compositor/review clock, GIFs/contact sheet, source/QC and notes. Slam/body/contract/world anchor remain unchanged.

Authored/tuned PixelLab VFX workbench smoke_poof with custom five-color ramp, size3.8, amount1.3, rise1.1; rendered30 native frames at25FPS. Export beff6c99-c909-42d2-a46e-7c709c432c88 / saved effect ef3e6d7f-fc13-4787-bf6c-c9fb0526773f. Removed only a second redundant fully blank terminator. Padded190×201 source by[34,23] to256×256; pivot[128,160] retains the same world-space palm/emitter anchor. No body or effect rescaling, blurred interpolation or baked summon. Game pack/source export retained for reproducibility. Preview sampling10ms displays every actual40ms smoke pose.

## Tests BEFORE commit
- `python assets/characters/player/study/summoning/source/build.py`: PASS29unique smoke frames, native size/binary alpha/clear borders/one clear terminator, opaque palm anchor, no composite clipping; normal/half-speed/component exports.
- Python HTTP server8778 + `node assets/characters/player/study/summoning/source/browser_check.mjs` with installed Playwright: PASS all260 timeline samples, body/contract/smoke independence, smoke delay/clear, anchor, controls/loop and phone layout;0HTTP/console/page errors.40 native PNGs loaded. Evidence source/qa/.
- `node --check assets/characters/player/previews/summoning/review.js`: PASS.
- Godot4.7.2 `python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`: PASS. New17 texture import sidecars included.
- Same CI helper validate-resources: PASS34scripts/6scenes/0failures.
- `git diff --exit-code f8252b0 -- assets/characters/player/study/summoning/body assets/characters/player/study/summoning/contract scripts scenes assets/characters/player/player_128.manifest.json`: PASS unchanged.
- Pillow GIF decode/duration check: full2600ms, half5200ms, independent smoke1160ms. Visually inspected rendered source evolution and updated complete contact sheet.

## Issues encountered
Renderer exported two blank end frames; removed the redundant final blank so only one intentional clear terminator remains. Prior20FPS preview would skip some25FPS poses; changed only the isolated review timeline to10ms sampling. No unresolved failures.

## Questions for owner
None; revised visual quality awaits review.

## Outstanding work
Visual acceptance. Runtime integration remains outside scope. Live deployment:not applicable — isolated art preview; no controller/production manifest edits or live-game update claimed.
