# Job Report — Ashen Ruins fire pack
- Agent: Codex
- Order: orders/Codex/2026-10-24-ashen-fire-pack.md
- Date:2026-10-24
- Final status: DONE (delivered live for owner art review)
- Commit / PR: 59a0e13891f6427bdd1fbeedb7df02487ee87689; PR #153, merged as 4c3e1ed7d813b336ee6765dd72cb5e375dd87967.

## Work completed
Five original PixelLab fixtures, using the existing floor's15-color stone palette. Separate12-frame12FPS flame atlas, coals and billowing smoke. Fixed24spark/18smoke pools per fixture, randomized upward/sideways embers, smoke curl/rise/fade, independently fluctuating orange tile light. One pop event synchronizes flash, coal brightness,6spark burst and positional crackle clip. Original synthesized4second ambient bed plus3crackle clips. No paid audio generation or copied Naruto audio.

Builder Ashen fire category with five native thumbnails, root-footprint collision/navigation, selection/movement/deletion, visibility filter and normal layout serialization. No preset map repaint or combat damage added. Review scene has normal/half speed, pause/step and independent effect/sound toggles. PixelLab sources/job IDs retained; rejected gray-flame bodies and hollow smoke icons are not production assets.

## Files changed
assets/environment/ashen_fire, assets/vfx/ashen_fire, assets/audio/ashen_fire; scripts/environment/ashen_fire_prop.gd; review scene/script; three minimal shared builder/test runner files; tests/test_builder_fire.gd; browser probe and docs/visuals/ashen-fire. Tree completion report updated separately with live evidence. Unrelated tools/shot_fences UID and ancient shrine report excluded.

## Tests run before commit
Godot4.7.2 import PASS. Targeted native proof PASS30checks. Full suite: python scripts/ci/godot_ci.py tests --project . --log-dir build/ashen-fire-tests:2263PASS0FAIL (expected malformed-sheet fixture warning only). Web exports for full game and isolated review PASS. Technical export asserts binary transparency, exact palette and12unique registered flame images; preview contact sheet visually inspected. Browser checks and final smoke revision results recorded below when complete.

## Issues encountered
Initial browser persistence check failed; investigation underway. First smoke render was too faint, increased plume position/scale/opacity before final capture. No implementation commit while failures remain. Existing HUD placeholders are unrelated work.

## Questions for project owner
None.

## Outstanding work / next steps
Finish browser persistence/render verification and previews; required reviewed PR/CI, live deployment and exactSHA browser checks. Audio event wiring is verified; no claim of human listening from automated waveform checks.

## Browser persistence investigation and correction
Repeated real browser reloads exposed stale IDBFS layouts, despite correct in-memory objects and occasional passing reloads. Instrumented exports showed final save calls with386objects but the stored file reverting to381; temporary trace prints were removed. Explicit close alone did not resolve it. Added a synchronous localStorage mirror scoped to Shinobi Rush's layout key on Web only; native/custom test paths retain FileAccess. Existing users without a mirror continue loading the original file. Denied/full storage is caught, invalid JSON falls back to the normal file, and an empty layout removes the mirror. No save schema or gameplay/controller change.

New native disk-read assertion confirms all five fixtures are actually serialized; full suite after explicit close passed2264/0. Final full suite and browser export include the Web backup and are being verified before commit. Browser probe now waits for the real backup and then reloads to assert all five objects survived, rather than relying on a fixed delay.

Actual isolated Godot Web review: all10boolean checks PASS,192frames captured with0console/runtime errors. Sound event deltas match pop deltas, mute/pause/step/half speed and independent Smoke/Sparks/Lighting toggles pass. GIFs verified192frames each,8000ms normal and16000ms half speed. Four original44.1kHz16-bit PCM clips are nonempty and have no clipped samples. Final smoke frame visually reviewed above flame tips; fixtures, coals, clear anchors, tile light and pixel clusters inspected. Source PNGs have binary transparency; all12flame hashes differ.

## Final pre-commit validation
Final full native suite:2264PASS0FAIL via python scripts/ci/godot_ci.py tests --project . --log-dir build/ashen-fire-final-ready-tests. Final Web export PASS via export --project . --out ../ashen-fire-final-ready-web-20261024 --log-dir build/fire-final-ready-export. Browser command: node scripts/ci/smoke/builder-fire-probe.mjs --serve-dir ../ashen-fire-final-ready-web-20261024 --out-dir build/ashen-fire-complete-browser. All15checks PASS,0errors: five cards/filter, scrolling without zoom, place/select/move/delete, filter cancellation, all5variants, active pop events, synchronous backup, save/reload, invalid backup fallback and restoring a valid backup. Screenshot and full JSON copied to docs/visuals/ashen-fire. All debug prints removed before final export. Order validator and working diff whitespace check PASS.

The Web mirror resolves the observed stale-writeback symptom without replacing existing native saves. Old users load their file normally until their next edit, when both copies are written. No remaining known local test failures. Owner art review follows delivery; no claim of owner approval for the new fire assets.

## Verified live completion
PR https://github.com/kiotdstudios/shinobi-rush/pull/153 passed required CI40074069277 and merged normally as4c3e1ed7d813b336ee6765dd72cb5e375dd87967. Main deployment CI40074663840 completed successfully, including post-deploy smoke and controls. Public build-info.json reported the exact merge SHA on2026-10-24.

Live command: node scripts/ci/smoke/builder-fire-probe.mjs --base-url https://kiotdstudios.github.io/shinobi-rush/ --out-dir build/ashen-fire-live-browser. All15checks PASS,0console/runtime errors, including five cards, scroll without zoom, selection/move/delete/filter, all5fixtures, pop events, saved backup, reload, corrupt backup fallback and restoration. Live PNG visually inspected: all fixture bodies/flames, independent smoke, sparks, warm tile illumination and builder controls render correctly. Evidence copied to live-builder-validation.json and live-builder.png beside the previews. Existing HUD placeholders are outside this art task and were preserved.

Published half-speed GIF downloaded from exact implementation SHA; SHA256 matches local. Normal preview8seconds, half-speed16seconds,192frames each. Audio event synchronization, mute and PCM integrity tested; subjective sound quality remains for owner listening. No claim of owner visual approval for this new pack. No required implementation, integration or deployment work remains; owner can review in the live Ashen fire builder filter.
