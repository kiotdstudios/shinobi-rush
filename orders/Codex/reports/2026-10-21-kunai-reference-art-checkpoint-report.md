# Job Report — Kunai combat reference and first attack study

- Agent: Codex
- Date:2026-10-21
- Order: `orders/Codex/2026-10-21-kunai-reference-combat.md`
- Final status: REVIEW for initial art checkpoint; broader request IN_PROGRESS, input clarification pending
- Commit / PR: Not committed when this pre-commit report was written

## Work completed
Read/inspected actual owner ZIP overview, first-six-second sheet and all six detailed sheets (180recorded frames). Decoded the53.40s720×480 H.264 MP4 across its duration using local ffmpeg via imageio-ffmpeg; container average29.93FPS/nominal30tbr. Studied approach, contact silhouettes/arcs/sparks, launch/recovery and camera follow/reframing. Documented source observations and adaptation to compact kunai/taijutsu, distinguishing capture frames from authored keys/engine/contact/input timing. ZIP/JPEG contents treated as reference data, no attachment-sourced instructions executed. Source receipts include size/SHA256; source video/ZIP are not redistributed in the repo.

Created original shared black kunai through built-in image_gen: separate64RGBA texture,36px logical weapon length, ring hole, wrapped grip, matte black/charcoal blade, pivot25,31/local+X. No PixelLab API or API-key calls. Created static SE player+bandit attachment preview without modifying bodies. Runtime_equipped=false is explicit.

Created an original6-key SE one-handed kunai opening thrust/cut through built-in image_gen using a repeated approved-player scale/identity grid. Body-only, free arm guards; no baked weapon/trail/background/shadow. Exported6 native128RGBA distinct PNGs with binary alpha, shared approved-SE palette and one uniform clip scale to104px standing reference. Source row registration y-3/-1, then common123/128 scale +offset2,5; no per-frame bbox fit/recentering. Per-frame fist/socket, orientation, hand occluder, holds, phases and contact data in opt-in .art.json.300ms proposal, contact pose2 at83.333ms, active poses2/3, transition poses4/5. Separate kunai composite previews at normal/half and rounded current-close scale, plus contact sheet. This is one attack pilot, not a complete combo, throw or runtime equipment change.

## Files changed
`assets/weapons/kunai/` final weapon/metadata/source; `assets/characters/player/kunai_poc/` six bodies/metadata; generated raw body source under player/source/kunai-thrust-se-v1 with.gdignore; `docs/visuals/kunai-reference/` study, source receipts, actual prompts, reference grid, export script, previews and Godot validator; assigned order/report. Existing player847PNGs and runtime controllers/camera unchanged. Dedicated branch based on verified live bandit merge98add79.

## Tests performed BEFORE implementation commit

| Test / command / inspection | Result |
| --- | --- |
| Local ffmpeg metadata and full-duration decode; view_image all provided sheets | PASS53.4s/720×480 video decoded;180opening capture frames inspected. No exact original engine timing claim. |
| `python docs/visuals/kunai-reference/export_kunai_poc.py` | PASS6 distinct128RGBA bodies, shared scale/palette, opaque sockets, separate weapon composites without192px stage clipping, exact300ms JSON action; GIF300ms normal/600ms half. Contact at83.333ms, native-frame holds explicit. |
| Pillow weapon checks | PASS64RGBA, binary alpha, opaque grip25,31, transparent ring hole17,31, native36px length, SHA256 agrees with metadata. |
| Godot4.7.2 `--headless --path . --editor --import --log-file build/kunai-import-final.log` | PASS, no engine/script errors. Exported PNG import settings included. |
| Godot4.7.2 `--headless --path . --script docs/visuals/kunai-reference/validate_art.gd --log-file build/kunai-texture-validation.log` | PASS six128px body Texture2Ds and64px weapon, grip/ring alpha verified. Also ran standalone single-weapon import fixture successfully. |
| Visually inspected weapon, two-actor mount preview, body strip and composite contact sheet | One-handed grip/free arm, forward thrust/overshoot/retraction visible; dagger independent. Character scale/palette corrected consistently before final export. Owner motion/identity approval remains pending. |
| `python scripts/ci/validate_orders.py`; `git diff --cached --check` | PASS before implementation commit. |

## Issues encountered
Generated transparent output had low-opacity stray pixels; thresholded alpha before weapon bbox crop. Initial guessed pivot landed outside that first incorrect crop; corrected the crop and verified true wrapped-grip pivot25,31. Shared body palette/scale registration brought new frames into the existing visual range; no body-by-body bbox fitting. Native GIF has10ms timing quantization while JSON holds remain exact. Existing player/bandit runtime behavior untouched by this checkpoint; no gameplay/deployment claim for the kunai proof. No physical gamepad/phone test.

## Questions for owner / outstanding work
Required clarification pending from async question: does throwing replace the block/parry input while retaining melee, or replace sword attacks? Current game has no shield action. Equipment binding for all required frames, full kunai combo, throw bodies/projectile/VFX/input, enemy kunai combat and dynamic camera remain outstanding. Preserve the current player/bandit; expand after reviewing the concrete new SE motion/weapon look. No paid third-party generation API used.

Live deployment: not applicable to this opt-in art/study checkpoint. New kunai is not equipped in the live game yet. Separately completed bandit replacement is merged/live verified at98add79 (PR45).
