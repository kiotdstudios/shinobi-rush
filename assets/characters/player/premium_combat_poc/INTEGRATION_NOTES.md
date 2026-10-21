# SE premium combat art proof — Aki handoff

This opt-in proof extends the PR33 modular art study. It does not install a combat controller, hitbox implementation, or event adapter. `premium_combat.art.json` intentionally does not use the SpriteLibrary `.manifest.json` suffix, so it cannot replace the default player set through recursive discovery.

## What is delivered

| Action ID | Poses | Duration ms | Startup / active / recovery ms | Contact pose (zero based) |
| --- | ---: | ---: | --- | ---: |
| run |18|750|Approach, existing run poses2–19|—|
| light1 |6|300|83.333 /66.667 /150|2|
| light2 |8|350|100 /66.667 /183.333|1|
| light3 |8|483.333|150 /83.333 /250|2|
| dodge |11|300|Reposition study, existing dodge poses0–10|—|
| dash_attack |7|400|100 /83.333 /216.667|2|

All timings are proposals derived from `AttackDef.build_table()` at main `21324afb02b639d13a5fe575bde776ab3faa0b6f`, not confirmed Aki fluidity tuning or reference-video measurements. Run is the authored24FPS inspection study; approved runtime locomotion remains12FPS and is untouched. Dodge's300ms is an inspection proposal, not a controller change. The full sequence lasts2583.333ms; GIF clock quantizes to2580ms (5160ms at half speed). Body holds vary; effects keep their independent24FPS clock through body holds and action transitions.

## Layer contract

- Standard body is native128×128 RGBA, root `[64,116]`, standing scale104px. Existing run/dodge paths are referenced without copying or editing those PNGs.22 selected weaponless combo PNGs are included with original hashes.
- Every pose includes native `right_hand_px`, clockwise y-down `weapon_angle_deg`, `weapon_layer` (`behind`/`front`) and `hand_occlusion_rect`. Both64×64 sword textures use native scale1, pivot `[14,32]`, local blade axis+X. Never scale the blade separately when switching compatible swords.
- Draw behind sword → body → front sword → same-frame hand crop → separate effects. Move and mirror the entire assembly together; do not independently flip socket coordinates. Draw order changes inherited from PR33 are deliberate shoulder/torso crossings.
- The256×224 composite canvas with body offset `[64,48]` is preview clearance only. It does not change the body canvas, anchor, or scale. Preview composites under `previews/.../transparent` are not modular production body PNGs.
- VFX retain original transparent128×128 sources, pivot `[64,64]`; light/heavy trails8frames, hit spark4frames. Source hashes and provenance are preserved. The preview uses a32px blade-axis contact offset as an illustrative target. Actual collision contact position must come from gameplay; do not bind hit sparks to an inferred preview target.
- No root translation is baked into body files. Aki owns approach, lunge, dodge motion and hitstop. The review stage intentionally isolates pose timing in place.

## Timing/events

Use `duration_ms` and `start_ms`, not `frame_index / fps`, for body playback. Millisecond phase boundaries are authoritative within this proposal. `fps:24` describes authoring baseline and separate effect cadence; it does not override variable holds.

`contact_frames`, `hitbox_active_frames`, `transition_ready_frames`, `hitbox_active_ms`, `combo_window_ms` and `dodge_cancel_ms` accompany every attack. A cancel can open inside a held image. Dispatch events when elapsed time crosses the timestamp, including skipped-time frames, rather than only when the rendered pose changes. Once per action instance; discard stale contact events on cancellation. Freeze body, weapon and effects together for local hitstop if gameplay requires it.

Proposed event vocabulary is `attack_start`, `hit_active`, `hit_contact`, `recovery`, `cancel_open`. These names are not an implemented/confirmed interface in the audited main. `cancel_open` specifically means dodge cancel in this file; combo eligibility uses its own interval. `transition_ready_ms` denotes recovery entry, not unrestricted cancellation. Aki must reconcile the metadata with the new fluidity profile before runtime binding.

The browser plays full recoveries for inspection. It inserts no idle bridge. Current combo buffering can cut recovery short; integration should select the legal transition pose/time and preserve momentum rather than adding neutral reset frames. Preview half speed is an inspection control, not an instruction to halve combat timing.

## Visual review and boundaries

Dash is explicitly a hybrid proof: existing SE dodge lean plus light1 cut/recovery, with a separate sword and trail. It establishes a reusable layered interface without new paid generation. It is not a newly drawn or approved dedicated dash body. Existing light3 rotates toward south through the finishing extreme; review that rotational read in the contact sheet before expanding SE into8directions. Automated opaque-socket tests establish file/coordinate integrity, not owner animation approval.

Native1× and current close-preset previews are provided. The loaded104px manifest produces CameraPreset close zoom `126/104=1.211538` at1280×720, so a standing figure would occupy17.5% of viewport height. SpriteActor uses native pixels, no additional body-height scaling. The numerical camera remains provisional per camera direction; no camera code changed. GIF close size310px uses rounded nearest-neighbor export; browser uses the exact scale.

Sources: PR33 modular art commit `2e5717d6e844de0a94c954a520aad131f3162873`; unchanged production locomotion from the branch base. Existing PixelLab-authored VFX metadata remains attributed. This milestone used Python/Pillow exports/compositing and browser animation; no image generation or paid API call. The old baked-weapon dash pilot stays reference-only and is not included. No847-frame conversion.

## Review gate / next work

Chief's order `orders/Codex/2026-10-20-premium-combat-animation-pack-v1.md`, Phase1 deliverable4: “Request owner approval of the look/feel before eight-direction expansion.” Review the concrete GIFs/contact sheet or interactive preview in PR42. After approval, coordinate exact Aki event/timing API and proceed to offensive direction expansion/dedicated dash art. Defensive/aerial/bandit combat remain later phases. Live deployment: not applicable to this opt-in art proof; it is not selected by gameplay and no game update is claimed.
