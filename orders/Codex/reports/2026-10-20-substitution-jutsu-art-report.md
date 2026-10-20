# Job Report — Substitution smoke/log art pack
- Agent: Codex
- Order: orders/Codex/2026-10-20-substitution-jutsu-art.md
- Date:2026-10-20
- Final status: REVIEW — art ready; visual acceptance and Aki integration pending
- Commit / PR: Report prepared before implementation commit; links recorded in follow-up.

## Work completed
Created original128px log reveal/tumble/contact/bounce/settle animation with bark ridges, branch stub and cut growth rings. Separate departure rolling smoke, curling ribbon wisps and arrival wisps preserve the current summoning smoke pixel scale/palette. Departure/arrival reuse23 exact summoning frames with faster substitution timing; this reuse is intentional, not a claim of newly generated billows. No character/log/smoke/terrain/shadow pixels baked across layers.

Four independent non-looping clips:log9frames/1050ms/hold last; departure15frames/580ms/clear end; arrival8frames/320ms/clear end; ribbons12frames/480ms/clear end. Native roots:log[64,116] on128canvas; smoke[128,160] on256canvas. Clips have explicit durations and pivots in opt-in substitution.json, not a runtime player manifest. PixelLab exact workbench log862692ef-c651-4084-93d7-249ba3db220a and ribbons572bc6d9-04bc-4503-806e-e24980a30278; summoning source exportbeff6c99-c909-42d2-a46e-7c709c432c88 fromd216459. Python only extracts, reorders, composites, exports and checks existing art; no resampling or blurred interpolation.

Provided normal/half-speed choreography GIFs, component GIFs,10-panel contact sheet and browser layer review. Diagram uses existing approved E/W idle fixtures and an explicitly labeled red attacker marker facing left. Old body conceals, log appears at its captured origin and fixture reappears behind the marker; no simultaneous old/new player. This diagram is not a playable combat implementation. No new player/enemy library was authored.

Gameplay handoff proposes hide0ms/log40ms/reappear+arrival80ms/log contact230ms relative to CONFIRMED timed L2 evade success. Aki owns success-window tuning, attacker validity, i-frames, one proc per attack, physics-safe rear placement/fallback, pauses/cancels and live gameplay tests. Queued orders/Aki/2026-10-20-substitution-jutsu-integration.md and INTEGRATION_NOTES.md describe requirements. No controller/state machine/camera edits.

## Files changed
- assets/vfx/substitution/:44 transparent PNGs, metadata, source recipes/QC and integration notes;44 texture sidecars.
- assets/characters/player/previews/substitution/:full/half/component GIFs, contact sheet/import sidecar, HTML/JS art diagram with controls.
- Codex order/report and queued Aki integration order.

## Tests performed BEFORE commit
Windows, Python/Pillow/numpy, Node/Playwright Chromium, Godot4.7.2. Commands from this dedicated checkout:

| Test / command / manual steps | Result |
| --- | --- |
| python assets/vfx/substitution/source/build.py | PASS:native size/RGBA/binary alpha/clear borders, unique drawn frames per clip, smoke clear terminators, metadata/timing exports. |
| Pillow byte comparison against summoning-review smoke PNGs | PASS23/23 departure/arrival images pixel-identical to their stated source indices. Records:source/consistency.json. |
| Pillow GIF decode/duration | PASS:normal31stored frames1400ms; half31frames2800ms; log9/1050ms, departure15/580ms, arrival8/320ms, ribbons12/480ms. Held timeline references combine in GIF without changing duration. |
| node --check assets/characters/player/previews/substitution/review.js | PASS. |
| Python HTTP server8779 plus node assets/vfx/substitution/source/browser_check.mjs, PLAYWRIGHT_MODULE pointing to installed Playwright | PASS:140timeline frames,46PNG assets, all five layer/fixture toggles, no duplicate visible player, old-body conceal and rear reappearance, root behind left-facing marker, scrub/step/wrap/restart/speed/two loops.0console/page/HTTP errors. |
| Desktop1200×900 / mobile390×844 | PASS:aspect1.75/no horizontal overflow. Manually inspected contact sheet/mobile: log reveals through smoke, arrival fixture behind marker, recognizable settled log. Evidence:source/qa/. |
| python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS:new45PNG sidecars included; source ignored by Godot. |
| Same helper validate-resources | PASS:34scripts/6scenes/0failures. |
| python scripts/ci/validate_orders.py | PASS. |
| git diff --exit-code 21324af -- scripts scenes assets/characters/player/player_128.manifest.json assets/characters/player/sprites/production | PASS:runtime/production847frames unchanged. |

## Issues encountered
Exact drawing API caps line width at8px; revised ribbon recipe to supported crisp strokes before rendering. No unresolved failures. Smoke frames are reused deliberately for requested summoning consistency; new work is log/ribbons, retiming and integration metadata.

## Questions for owner
None. Gameplay tuning is assigned to Aki and art quality remains under visual review.

## Outstanding work / next steps
Review art, then Aki integration/tests per queued order. L2 timed success, actual attack handling, relocation and invulnerability are NOT implemented by this art pack. Live deployment:not applicable — isolated asset/preview delivery; no runtime manifest/controller changes or live-game update claimed. Preview marker/positions/reset do not define gameplay behavior.
