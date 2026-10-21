# Job Report — Premium combat SE layered proof

- Agent: Codex
- Order: `orders/Codex/2026-10-20-premium-combat-animation-pack-v1.md`
- Date:2026-10-20
- Final status: REVIEW — concrete Phase1 art proof complete for owner visual review; complete combat pack is not DONE.
- Commit / PR: Implementation not committed when this report was written; https://github.com/kiotdstudios/shinobi-rush/pull/42. SHA to follow after tested commit.

## Work completed

Built the SE run→light1→light2→light3→dodge→dash_attack sequence with58 timed poses and no idle separator. Reused existing approved locomotion without edits; included22 selected existing weaponless combo PNGs, two original separate sword textures and20 independent existing VFX PNGs. Added per-pose native hand sockets, orientation, front/behind order, same-frame hand occlusion, source hashes, exact millisecond holds, phases, contact/active/transition frames, combo/dodge cancel windows and proposed event markers. Retimed first slash contact from the old uniform-FPS source to the audited gameplay startup boundary.

The dash is explicitly a hybrid study using existing low dodge and cut/recovery poses; it is not newly drawn dedicated dash production art. No paid generation/API calls. Existing PR33 PixelLab VFX provenance retained. No controller, hitbox, movement, camera, bandit or original847-frame library changes.

Added transparent composite PNG previews, nearest-neighbor contact sheet, normal/half native GIFs, close-scale half GIF, and mobile-friendly interactive browser preview with clocks, scrubbing, pause/play/step, all six action selections, native/close/2×/3× scale, two swords, body/weapon/VFX toggles and optional anchors. Effects retain independent24FPS timing during held body images and across action transitions. Both swords share the exact body paths. Source PNGs remain separate for integration.

## Files changed

- `assets/characters/player/premium_combat_poc/`: opt-in `.art.json`,22 body PNGs, two swords,20 VFX, Godot import sidecars and Aki integration notes.
- `assets/characters/player/previews/premium-combat-poc/`: browser harness, GIFs, contact sheet and58 optional transparent composite previews. `.gdignore` excludes preview-only imagery from Godot resources.
- `docs/visuals/premium-combat-v1/`: reproducible build/export script, validators, browser smoke script/results/screenshots and Godot logs.
- Assigned order status/delivery record and this report. Primary dirty checkout untouched; dedicated checkout/branch retained.

## Tests performed BEFORE implementation commit

Environment: Windows PowerShell, dedicated `.tools/premium-combat-poc` checkout; bundled Python/Pillow, bundled Node/Playwright Chromium; Godot4.7.2 stable.

| Exact command / manual inspection | Result / evidence |
| --- | --- |
| `python docs/visuals/premium-combat-v1/build_proof.py --source ../modular-weapon-poc` | PASS.58 poses,258 ten-millisecond GIF samples,2583.333ms exact JSON sequence. Exported transparent PNGs, contact sheet, normal/half/close-half GIFs. |
| `python docs/visuals/premium-combat-v1/validate_proof.py` | PASS.128RGBA binary alpha; source hashes; every socket on opaque body; valid occluders;116 body/sword composites, no256×224 stage clipping; exact holds/phase totals; four contacts at active start; no duplicate body images within any action. GIF quantized totals2580ms/5160ms. `proof-validation.json`. |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import --log-file docs/visuals/premium-combat-v1/godot-import.log` | PASS exit0, no ERROR/WARNING entries; project/assets imported. |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script docs/visuals/premium-combat-v1/validate_imports.gd --log-file docs/visuals/premium-combat-v1/godot-art-validation.log` | PASS exit0.58 body references, two swords,20 VFX loaded as Texture2D with expected dimensions; actual CameraPreset close formula confirmed1.211538 for104px manifest. Godot import test only; no gameplay playtest claimed. |
| `node docs/visuals/premium-combat-v1/browser_smoke.mjs` | PASS Chromium desktop1280×900 and touch/mobile390×844.73 unique source images loaded, all six actions/step, four active/contact timestamps, both swords share body, pause/play, normal/half, layer toggles produce empty canvas when off, native/close and reload; no horizontal overflow, page errors or HTTP missing assets. `browser-smoke.json` and four screenshots. Not physical-phone/Safari testing. |
| Viewed approved baseline, native body strips/socket grids, full contact sheet and mobile close screenshot | Preserved original identity and pixel scale; hand mounts/occlusion visually reviewed. Light3 finishing torso rotates toward south, explicitly retained for owner read review. Dash reuse disclosed rather than presented as approved bespoke art. |
| `python scripts/ci/validate_orders.py` | PASS. Agent/order structure valid. |
| `git diff --cached --check` | PASS before commit after removing Godot log trailing spaces/blank EOF. Initial check caught only generated-log whitespace; no implementation errors. |

Bundled executables used at `C:/Users/dielp/.cache/codex-runtimes/codex-primary-runtime/dependencies/{python/python.exe,node/bin/node.exe}`; Godot at primary `.tools/godot-4.7.2/`. Browser server: `python -m http.server 8778 --bind 127.0.0.1` rooted at this checkout. Local preview `http://127.0.0.1:8778/assets/characters/player/previews/premium-combat-poc/index.html`.

Browser smoke uses the existing repository Playwright package by default. This isolated checkout reused the installed package through `$env:PLAYWRIGHT_MODULE='file:///C:/Users/dielp/Documents/Codex/2026-10-17/shinobi-rush-is-the-new-game/.tools/live-animation-integration/scripts/ci/smoke/node_modules/playwright/index.mjs'` before the Node command; no package/dependency changes.

## Issues encountered / limits

Two initially proposed run sockets (source9/17) landed outside opaque pixels. Corrected to the inspected right hand `[44,67]`; rebuilt and validator passed. Existing combo uniform24FPS contact timing mismatched current AttackDef; retimed together with weapon tracks. Close-camera audit confirmed SpriteActor does not normalize body height: use CameraPreset.close_zoom(104), no extra104→108 scale. GIF ten-millisecond quantization is disclosed; JSON/browser use exact time.

No runtime regression observed in affected preview controls/imports. Gameplay integration/feel is untested because this proof deliberately has no runtime binding. Event names/tuning remain proposals pending Aki confirmation. No local reference video was available; no claim of watching or extracting source-game animation timing. Original fully drawn dash pilot remains baked-weapon reference only.

## Questions for owner / outstanding work

Review the concrete SE look/feel, including hybrid dash and finishing rotation. Chief's Phase1 deliverable4 requires owner approval before8-direction expansion; this is a milestone review, not a request to commit broken work. After approval, coordinate Aki's exact event API/tuning, author dedicated dash refinements and expand offensive directions. Defense/aerial/bandit combat remain later phases. No main merge or eight-direction approval claimed.

Live deployment: not applicable. Opt-in art/metadata and a separate review harness do not alter the selected player library or live combat. The actual game has not been updated by this milestone. Review files are published through PR42 and raw GitHub GIF links for phone access, independent of localhost.
