# Job Report — Modular sword art proof
- Agent: Codex
- Order: orders/Codex/2026-10-19-modular-weapon-art-poc.md
- Date: 2026-10-19
- Final status: REVIEW — art delivered; owner visual acceptance and Aki integration pending
- Commit / PR: Art45cbf25; https://github.com/kiotdstudios/shinobi-rush/pull/33. Superseded draft31 closed with source branch preserved.

## Work completed
Finished the current eight-frame SE katana finisher and retained the complete 24-frame fully drawn three-hit combo for comparison. Stopped broader combat generation as requested. Produced one 24-frame weaponless SE body combo and two separate swords, with per-frame primary-hand anchors, clockwise orientation, front/behind draw order and hand occluders. Both swords reuse exactly the same body files. Exported independent light/heavy trails and hit spark. Supplied source receipts, half-speed GIFs, contact sheet, synchronized browser comparison and Aki integration notes/order.

Audited the production manifest: 847 unique movement PNGs are unarmed, so none requires weapon removal. Production manifest, controller, camera and existing movement assets remain unchanged. No other directions or weapon families were converted.

## Files changed
- assets/characters/player/modular_poc/: body, separate swords, baked reference, opt-in art JSON, source/QC and integration notes.
- assets/characters/player/previews/modular-weapon-poc/: GIFs and interactive art comparison. This harness is separate from the live game.
- assets/vfx/combat/: 20 independent transparent effect frames and metadata/source.
- Codex order/audit/report and queued Aki engineering order.

## Tests performed BEFORE commit
Windows, Python with Pillow/numpy, Node/Playwright Chromium, Godot 4.7.2. Commands run from this checkout unless specified:

| Command / manual check | Result |
| --- | --- |
| python assets/characters/player/modular_poc/source/build_baked_reference.py | PASS: 24 unique native128 RGBA reference frames, binary alpha, no clipping. |
| python assets/characters/player/modular_poc/source/check_registration.py | PASS: original head and foot landmarks independently agree on all24 padding corrections. |
| python assets/characters/player/modular_poc/source/export_body.py | PASS: 24 native128 RGBA weaponless bodies, restored origin, no clipping. |
| python assets/characters/player/modular_poc/source/build_metadata.py | PASS: all24 primary grips opaque; shared body references; two canonical sword pivots. |
| python assets/characters/player/modular_poc/source/render_previews.py | PASS: 48 weapon composites, binary alpha, no clipping, grip connection, half-speed exports. |
| node --check assets/characters/player/previews/modular-weapon-poc/review.js | PASS. |
| Python HTTP server8775 plus node ../modular-poc-check.mjs (local Playwright harness) | PASS: all24 frames, both swords, zero partial-alpha pixels, zero hand-occlusion errors, zero behind-layer errors; trails/anchors/scrub/wrap/speed tested. All70 PNG assets loaded; no HTTP, console or page errors. |
| Chromium desktop1280x900 and phone390x844 screenshots | PASS: manually inspected four comparison panels; mobile canvas326x326, no horizontal overflow. Evidence in source/qa/. |
| python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS: native texture imports; generated import sidecars included. |
| python scripts/ci/godot_ci.py validate-resources --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS:30 scripts,5 scenes, zero failures. |
| python scripts/ci/validate_orders.py | PASS. |
| git diff --exit-code ce81f6d -- assets/characters/player/player_128.manifest.json assets/characters/player/sprites/production scripts/player scripts/sprites scripts/camera | PASS: existing runtime/production paths unchanged. |

Visual checks covered the completed finisher, all body candidates, registered hand grids, katana contact sheet and both sword browser composites. GIF/comparison clocks default to half speed, as requested in previous reviews.

## Issues encountered
PixelLab body edits shifted transparent padding. Restored original placement using independently matching head and feet translations; no scaling, warping or bounding-box recentering. Aki has not confirmed timing/schema yet, so24FPS/contact/active/cancel values remain explicit proposals. Current body retains off-hand support gestures; new hilt shapes require clearance review. The art browser verifies attachment rendering only, not gameplay hitbox/movement synchronization.

## Questions for project owner
None. Visual acceptance will determine whether the proof expands.

## Outstanding work / next steps
Main21324af (Aki combat milestone) landed during handoff and was merged without conflict. Integration notes now map descriptive art names to gameplay light1/light2/light3 and record authoritative timing. The broad newly queued art request is held at REVIEW under the owner's narrower proof restriction. No Aki runtime implementation was authored or changed by Codex.

Post-integration checks before the handoff follow-up commit: Godot import PASS; the same validate-resources command PASS (34scripts,6scenes,0failures); `../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd` PASS (534passed,0failed); order validator and git diff --check PASS. Expected negative-fixture diagnostics occur in the native suite; final exit code0. Art/production assets unchanged by the merge.

Aki owns engine attachment/layer implementation, frame-event/hitbox/movement synchronization, attack-family profiles, fallback preservation and live gameplay validation. Engineering order is queued; no work in Aki's controller/state machine or Kiro's camera was performed. Keep current katana reference functional during migration. Do not convert847 frames or expand directions/types before proof acceptance.

Live deployment: not applicable — opt-in art/preview only, no runtime integration or live-game changes. Commit/push and reviewed PR handoff are the art delivery. The full modular game system is not marked DONE.
