# Job Report — Stylized running jutsu, corrected trailing-arm charge
- Agent: Codex
- Order: orders/Codex/2026-10-19-stylized-running-jutsu.md
- Date: 2026-10-19
- Final status: REVIEW — tested art preview ready; owner visual acceptance pending
- Commit / PR: Art1c3818524e5eb0a8cd7f9c72afafe1a84979e772; https://github.com/kiotdstudios/shinobi-rush/pull/35. Committed and pushed; final visual review pending.

## Work completed
Created a short SE running-hand-sign to lightning-thrust loop, intended-speed and half-speed GIFs, labeled contact sheet and phone-friendly synchronized browser review. Two contrasted sign silhouettes, two single-frame faint hand multiples, separation into a brief charged sprint, explosive thrust, sharp impact and electrical follow-through. The character keeps sprinting throughout; there are no idle/standing frames. Preserved approved player appearance, native128×128 body, pixel scale and foot origin[64,116].

Owner rejected the initial raised-hand charge and supplied both a still and a URL. The reader failed to load the URL; direct download confirmed image/gif,500×280,12frames at40ms (480ms loop), not a still. Inspected all12 frames in an extracted contact sheet outside the repository. The animation shows the charged arm extended backward behind the hip with lightning trailing while sprinting. Replaced both charge/thrust drawings so the SAME near arm trails back and then snaps forward across the torso. The raised-hand version is retained only as explicitly rejected source, never in final previews.

PixelLab Pro produced four upper-body key drawings and two corrected replacement drawings. PixelLab exact workbench authored two hand-multiple overlays and twelve sharp blue-white lightning frames. Python only registered/cut/composited original assets and exported/QC'd them. No named hand-sign tracing or generated in-between filler. No reference anime artwork/background was copied into the game or committed.

## Files changed / implementation decisions
- assets/characters/player/study/running-jutsu/:50 timeline-sampled128px body PNGs,2 separate128px motion overlays,12 separate64px lightning frames, opt-in JSON and source recipes/provenance/QC. JSON is not named *.manifest.json and is not installed into runtime.
- assets/characters/player/previews/running-jutsu/:1.667s intended-speed loop, half-speed/body-only GIFs,12-panel labeled contact sheet, HTML/JS review with clock/scrub/speed/zoom/effect toggles.
- This Codex order and report. Existing modular sword PR33 is separate.

The 30Hz timeline reuses four upper keys and the existing20-phase12FPS SE sprint. Intentional body holds are encoded, not extra generated poses. Every opaque leg pixel below y80 remains byte-for-byte equal to the current approved sprint phase. Background in that region also remains exact except the explicit empty x94..127/y80..95 margin for the thrusting spear-hand; that hand cannot overwrite any opaque leg pixel. The legs never reset phase for signs, charge, thrust or recovery. Head/upper placement follows measured sprint bob, with no body rescaling or bounding-box recentering.

Lightning stays separate and its pivot follows an opaque hand point on every effect frame. The native body remains128;192px preview canvas provides effect overflow. Body/lightning alpha is binary; hand-multiple overlays intentionally use crisp90/120-alpha copies. No blur/interpolation, baked lightning, background or floor shadow. GIFs combine identical held samples into33 stored frames with preserved1670ms duration; JSON/browser retain exact1666.667ms.

## Tests performed BEFORE commit
Windows; Python/Pillow/numpy, Node/Playwright Chromium, Godot4.7.2. Commands from this dedicated checkout:

| Command / manual verification | Result |
| --- | --- |
| python assets/characters/player/study/running-jutsu/source/build_preview.py | PASS:50 ordered samples,20 approved sprint phases, all protected leg pixels exact; head/feet agree on all4 key registration offsets; hand anchors opaque; binary body/lightning alpha;12 unique nonblank effect frames; no clipping. |
| node --check assets/characters/player/previews/running-jutsu/review.js | PASS. |
| Python localhost HTTP server8777, then node assets/characters/player/study/running-jutsu/source/browser_check.mjs with PLAYWRIGHT_MODULE set to installed pinned Playwright | PASS on corrected final art:50 frame checks, exact running-leg pixels, binary body alpha, independent lightning/multiples toggles, body-only equality, foot-origin marker, scrub/step/wrap/speed/restart and2 complete loops.62 PNGs loaded;0 HTTP/console/page errors. |
| Desktop1280×900 / mobile390×844 / game close zoom1.211538 | PASS: square canvases, no mobile horizontal overflow, game-close canvas232.615px. Manually inspected corrected charge/thrust contact sheet and mobile screenshot. Evidence:source/qa/browser.json,desktop.png,mobile.png. |
| python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS final imports;65 new texture import sidecars included. Source/QC ignored by Godot. |
| python scripts/ci/godot_ci.py validate-resources --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS:34 scripts,6 scenes,0 failures. |
| python scripts/ci/validate_orders.py | PASS. |
| git diff --exit-code 21324af -- scripts scenes assets/characters/player/player_128.manifest.json assets/characters/player/sprites/production | PASS:controllers/scenes/manifest/production847 frames unchanged. |

## Issues encountered
Initial raised-hand charge did not match the owner's intended Chidori arm motion and was replaced after inspecting the actual animated GIF. The motion URL could not be read by the web reader; direct download and all-frame extraction resolved it. Source edits shifted padding1–2px; matching head and foot landmarks restored original origin. Spear-hand extends below the horizontal torso seam; copied it only into empty side margin while protecting every original leg pixel. GIF timing is quantized to10ms; exact timing is supplied in JSON/browser.

## Questions for project owner
None. Final pose/motion quality awaits visual review of the corrected loop.

## Outstanding work / next steps
Review the loop/contact sheet. Additional directions and runtime jutsu integration are outside this preview request. No movement/combat/camera controller changes were made. Live deployment: not applicable — isolated art/preview, no runtime manifest or live-game integration. Commit/push and reviewed PR provide phone-accessible GIF delivery.
