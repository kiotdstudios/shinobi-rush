# Job Report — Summoning jutsu art
- Agent: Codex
- Order: orders/Codex/2026-10-20-summoning-jutsu-art.md
- Date: 2026-10-20
- Final status: REVIEW — art preview ready for owner visual acceptance
- Commit / PR: Report prepared before implementation commit; links added in follow-up.

## Work completed
Created one SE summoning sequence: quick hand signs, a raised-arm windup, forceful ONE-palm ground contact with the other hand held off the ground, large black ink contract spreading on the ground, and delayed white smoke. Nothing summoned yet. Three independent transparent animation clips and timing/pivot metadata allow separate playback/replacement.

Character stays native128×128 at approved pixel scale; crouch is a pose change, not image resizing. Four PixelLab Pro key poses plus approved original idle. Applied one consistent16px horizontal padding correction to all generated poses, preserving their relative motion and common root. Fixed actor foot/root[64,116]; visible palm contact[60,109], ground point relative to root[-4,-7].

Six256×256 black-only contract frames, final ink bounds[11,66,249,192]:238px wide, flattened into the ground plane and more than twice the104px standing-body-height reference. Twelve256×256 smoke frames expand over the summon location, break into puffs and end fully clear. Both share the palm/ground point with distinct pivots. Contract draws below actor; smoke above. No terrain, shadows, character, effects or summon content baked across layers.

Contact/seal start450ms; full seal700ms; smoke1100ms (650ms after slam); suggested future hidden spawn1450ms and conservative reveal after clip end1940ms.2.6s review loop holds the seal; reset is a preview behavior, not gameplay cleanup. Includes normal/half-speed full GIFs, component GIFs, labeled12-panel contact sheet and phone browser layer toggles/clock/scrub/speed.

## Files changed
- assets/characters/player/study/summoning/:5 body PNGs,6 contract PNGs,12 smoke PNGs, opt-in summoning.json, README, source recipes/QC and23 native texture sidecars.
- assets/characters/player/previews/summoning/:full/half/component GIFs, contact sheet with import sidecar, HTML/JS review.
- This order/report. Production sprite library, manifest, controllers, scenes and camera untouched.

PixelLab Pro job96f8994c-9f0e-496a-9526-14cd01b8c5c9 generated body keys from approved idleSE0. Exact PixelLab workbench contract a540dd0b-ee67-43ff-a0b3-8e861a1b4c7c and smoke5aec74a2-a0ee-4e2f-a4a9-18d16b3c4b4d are original authored geometry, not traced anime frames. Python only extracts, translates, composites, exports and checks assets. Source/QC is excluded from Godot by .gdignore.

## Tests performed BEFORE commit
Windows, Python/Pillow/numpy, Node/Playwright Chromium, Godot4.7.2. Commands from this dedicated checkout:

| Test / command / manual steps | Result |
| --- | --- |
| python assets/characters/player/study/summoning/source/build.py | PASS:dimensions/RGBA/binary alpha, clear borders, unique contract/smoke frames, intentional clear smoke terminator, opaque palm anchor,238px ink width, no composite clipping. |
| GIF decode/duration check with Pillow | PASS:full25 stored frames2600ms; half25frames5200ms; body8frames2600ms; contract6frames900ms (includes inspection hold); smoke12frames840ms. Shared holds merge in GIF; explicit timing remains in JSON. |
| node --check assets/characters/player/previews/summoning/review.js | PASS. |
| Python HTTP server8778 plus node assets/characters/player/study/summoning/source/browser_check.mjs (PLAYWRIGHT_MODULE set to installed Playwright) | PASS:all52 timeline samples binary alpha/nonempty; independent body/contract/smoke toggles; delayed smoke absent before1100ms and clear after; shared contact marker; pause/scrub/step/wrap/speed; full loop playback.23 PNGs loaded; zero console/page/HTTP errors. |
| Desktop1200×900 and mobile390×844 | PASS:canvas aspect1.25 preserved, no horizontal overflow; manually inspected mobile contact pose/large black contract and full contact sheet. Evidence in source/qa/. |
| python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS;24 new PNG import sidecars included. |
| Same helper validate-resources | PASS:34 scripts,6 scenes,0 failures. |
| python scripts/ci/validate_orders.py | PASS. |
| git diff --exit-code 21324af -- scripts scenes assets/characters/player/player_128.manifest.json assets/characters/player/sprites/production | PASS:runtime and847 production character frames unchanged. |

## Issues encountered
Initial smoke peak had two identical samples; uniqueness check caught it. Redrew the second peak silhouette and reran export successfully. Changed smoke shading from individual glossy discs to merged pale puffs for a clearer smoke silhouette. No unresolved test failures. Body padding correction is fixed across poses; no per-frame recentering or resampling.

## Questions for project owner
None. Future summoned content is deliberately empty.

## Outstanding work / next steps
Follow-up before delivery: added independently triggerable hand_signs and ground_slam subclips sharing original body PNGs, plus ground-slam-only.gif. Re-ran build.py PASS and decoded standalone slam4frames/1200ms; independent contact150ms. Main timeline/art unchanged.

Owner visual review. Other directions, summoned creature/object, collisions and gameplay event integration remain outside this art-preview request. All three clips can be retimed independently via supplied data. Live deployment: not applicable — isolated art/preview only, no runtime manifest or controller integration. Commit/push via reviewed art PR; no live-game change is claimed.
