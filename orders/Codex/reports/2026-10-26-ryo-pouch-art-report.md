# Job Report — Ryo pouch art and animations
- Agent: Codex
- Order: orders/Codex/2026-10-26-ryo-pouch-art.md
- Date: 2026-10-26
- Final status: REVIEW — tested art handoff, commit / push pending
- Commit / PR: implementation SHA recorded in the following report update
- Live deployment: **not applicable** — owner explicitly requested only art/animations; Aki owns backend integration.

## Work completed
Recreated the mockup's classic brown leather pouch with red gathered cord and gold square-hole coin. Delivered 16 unique subtle idle poses, an eight-frame squash / rebound / shrink / clear collection clip, twelve gold aura frames, twelve sparkle frames and twelve separate projected floor-light frames. Body uses 128×128 RGBA canvases; light/particle layers use 96×96. Idle silhouette is 78–80px tall with a fixed y104 baseline, matching the existing 75px gourd scale. The final collect frame is intentionally empty: body clears at 350ms, followed by a 50ms terminal hold.

Provided a five-track SpriteFrames resource (70 playback frames using 60 source textures, including ping-pong sparkles), additive material, icon, four atlases, individual PNGs/import settings, manifest with hashes and phase timing, source/reference provenance, contact sheets, 1×/2× preview stills, normal and half-speed GIFs, and a tested 742KB downloadable art bundle. The ZIP contains runtime art/data and Aki instructions; source images remain in the repository under .gdignore.

The generic `gourd_XX` body filename prefix deliberately matches the existing pickup loader. Independent layers preserve the approved float/bob, aura pulse and collection timing. Aki handoff explains avoiding duplicate squash/scaling when using the authored collect poses and tracking the player's current chest without baking a path into the sprite.

No pickup registration, currency amount/reward, inventory, spawns, input, controller or live-scene binding was created. The earlier tested mist change was merged from current main only to keep this art branch up to date; this PR's diff against main contains only pouch art, tooling, previews and documentation.

## Files changed
- assets/pickups/ryo_pouch/: 60 source textures, icon, atlases, import sidecars, SpriteFrames, additive material, manifest and ignored generated source/reference.
- scripts/art/build_ryo_pouch.py: deterministic matte cleanup, fixed shared scales/anchors, frame extraction and data-only resources.
- scripts/art/preview_ryo_pouch.py: art-only preview compositor; no gameplay hooks.
- scripts/art/verify_ryo_pouch.gd: actual Godot asset loading / timing / material verification.
- docs/visuals/ryo-pouch/: previews, QA/import evidence, ZIP and AKI-HANDOFF.md.
- Own order and this report.

## Tests run before commit
Environment: Windows PowerShell, bundled Python/Pillow/NumPy; pinned Godot 4.7.2 Windows console. Project: `.tools/ground-mist`, branch `codex/ryo-pouch`. `$Godot` below denotes `C:/Users/dielp/Documents/Codex/2026-10-17/shinobi-rush-is-the-new-game/.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.

| Command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python scripts/art/build_ryo_pouch.py` | 16 / 12 / 12 / 8 / 12 unique frames by layer; only collect[7] intentionally empty; no output-edge contact or clamping | docs/visuals/ryo-pouch/asset-qa.json |
| Open owner reference, all four generated raw sheets, exported contact sheets and idle/rebound/warp/absorb previews | Brown/red/gold design preserved; sharp pixels; stable idle scale/anchor; gold-only separate VFX | source/GENERATION.md, preview PNGs |
| Chroma-fringe audit of all glow / ember frames | Zero remaining magenta-fringe pixels under the documented RGB test | terminal; processor gold-only matte cleanup |
| `python scripts/art/preview_ryo_pouch.py` | Normal 4s / half-speed 8s; 640×360, art-only 1× and 2× composite; 79 / 156 stored GIF frames after identical-frame duration merging | docs/visuals/ryo-pouch/previews.json |
| `python scripts/ci/godot_ci.py import --project . --godot $Godot --log-dir build/ryo-final-import` | Pass, no engine errors; new texture/script sidecars generated and retained | build/ryo-final-import/import.log |
| `$Godot --headless --path . --quit-after 120 --script res://scripts/art/verify_ryo_pouch.gd` | PASS: five animation tracks; 70 playback frames; 60 valid source textures at expected dimensions; non-looping 400ms collect track with transparent terminal frame; additive material | docs/visuals/ryo-pouch/import-validation.json |
| Python manifest/hash/dimension checks; ZIP `testzip()` | All RGBA and sized correctly; 65 PNG hashes match; visible collection 350ms; total 400ms; production_bound=false; ZIP 134 files / CRC clean | import-validation.json; ryo-pouch-art.zip |
| `python scripts/ci/validate_orders.py`; `git diff --check` | Pass | terminal |

No gameplay/browser backend test was claimed: the pack is unregistered art/data, as explicitly requested. Godot imported and loaded the actual animation resource. The GIFs simulate the accepted pickup motion for art review and do not claim a working ryo pickup or currency reward.

## Issues encountered
Initial golden VFX retained some magenta-matte contamination at the edges. Deterministic gold-only matte decontamination removed it; regenerated frames/previews were inspected and reverified. The generated collect sequence ends with an empty cell; it is retained intentionally as the clear frame, with its exact timing documented rather than treated as a missing pose. No unresolved art/import issues.

## Questions for project owner
None.

## Outstanding work / recommended next steps
Commit/push tested art handoff. Aki handles registration, currency amount, eligibility, inventory/HUD, movement tracking, sounds and gameplay integration. No backend work is included in this order.
