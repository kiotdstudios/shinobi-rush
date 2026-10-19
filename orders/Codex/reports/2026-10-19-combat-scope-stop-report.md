# Job Report — Current sword completed; modular proof takes priority
- Agent: Codex
- Order: orders/Codex/2026-10-19-combat-art-pack-v1.md
- Date: 2026-10-19
- Final status: REVIEW (owner stopped expansion; original full pack incomplete)
- Commit / PR: https://github.com/kiotdstudios/shinobi-rush/pull/31

## Work completed
Finished the current southeast sword finisher:8 unique native128×128 RGBA frames, no baked trail, body scale preserved. Completed the southeast three-hit fully drawn comparison reference:24 frames. A four-pixel guarded blade-tip edit fits the high guard without touching body pixels. Reused independent trails. Owner redirected further work to the one-direction modular weapon proof; no new full-pack generations were queued after that instruction. Previously queued results remain source experiments, not production-approved clips.

## Files changed
Order scope/status and this report. Completed reference and its reproducible source/exporter live in the isolated codex/modular-weapon-art-poc checkout under assets/characters/player/modular_poc/. Existing experiments remain preserved locally under source/combat-review-v1, with job receipts. No847-frame conversion or gameplay/camera change.

## Tests performed BEFORE commit
- `python assets/characters/player/modular_poc/source/build_baked_reference.py` in modular checkout: PASS24 unique RGBA128 frames, binary alpha, no opaque-pixel clipping and constant per-clip translation.
- Visually inspected finished normalized8-frame finisher contact sheet: no white arcs, floor shadow or clipped sword; original character retained.
- `python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe` in modular checkout: PASS;24 reference PNGs and20 VFX PNGs import.
- Order validation and git diff --check before documentation commit: PASS.

## Issues encountered
Some wider-direction source studies fail facing/trail QA and are not delivered as production. Aki gameplay timing/attachment implementation remains pending. The original full eight-direction pack is not complete and is no longer the active delivery scope.

## Questions for project owner
None; modular proof scope is explicit.

## Outstanding work / next steps
Produce one SE weaponless three-hit body set, two compatible separate one-handed swords, per-frame anchors/orientation/draw-order and independent trails; compare against completed baked reference; hand art to Aki. Further directions/weapons only after proof passes review. Live deployment: not applicable to this scope-stop documentation checkpoint; no combat gameplay deployment is claimed.

