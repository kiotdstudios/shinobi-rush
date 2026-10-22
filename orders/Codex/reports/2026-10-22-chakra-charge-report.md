# Job Report — Detailed blue chakra charge
- Agent: Codex
- Order: [Detailed blue chakra charge](../2026-10-22-chakra-charge.md), direct owner request
- Date:2026-10-22
- Final status: REVIEW — local and integrated acceptance passed; PR and live deployment pending
- Commit / PR: Not committed yet; this report precedes implementation commit.

## Work completed

Studied the owner's six-frame Naruto chakra GIF after finding its relocated Dropbox copy. Preserved the approved original player identity and overhead camera: olive vest, dark skin/clothing, white wraps, unmasked face and short locs. Created a braced charge body with eight unique128×128 frames per supported heading, fixed sole anchor(64,116). Five original direction sets; W/NW/SW mirror E/NE/SE around x64. Crouched body height96–102 pixels versus104-pixel standing baseline; no per-frame scale fitting.

Created separate blue flame(48 frames), rising spirals(32), and ground energy(16), all transparent256×256 layers. These are96 unique authored VFX drawings across the layers, not96 body or flame frames. Their least-common-multiple combined loop contains96 distinct rendered phases. Normal:24 FX fps/12 body fps/four-second combined loop. Default half speed:12 FX fps/6 body fps/eight-second combined loop. No synthetic interpolation or duplicate padding. Source sheets and generation receipt/hash provenance are preserved and excluded from runtime import.

Added per-instance palette shader/API preserving white energy cores and leaving body textures untouched. Five preview palettes demonstrate future transformation/upgrade capability; no unlock progression is invented. A separate art component preserves the actor's Y-sort plane and orders ground/rear flame/body/front spirals. Added a normal-game hold-R visual preview while idle and healthy, cancelled by movement and suppressed by builder/lab. Movement, combat and camera controllers remain unchanged.

Delivered a touch-friendly `?chakra=review` page with normal/half speed, pause, exact phase stepping, all headings, palette and layer controls, charge fade, gameplay zoom and2x inspection. Added actual engine-rendered normal/half-speed GIFs, loop contact sheet, direction comparison and in-game screenshots.

## Files changed

- `assets/characters/player/chakra_charge/`: source sheets,64 exported body frames, direction atlases, metadata.
- `assets/vfx/chakra_charge/`: source sheets, three transparent atlases and import sidecars.
- `assets/characters/player/player_128.manifest.json`: added chakra body entry, preserving current kunai entries.
- `scripts/vfx/chakra_charge_visual.gd`, `chakra_palette.gdshader`: layered playback/tint.
- `scripts/art/chakra_charge_gate.gd`, `chakra_charge_review.gd`, review scene and additive main-scene gate.
- `tests/test_chakra_charge.gd` and runner registration: asset, timing, palette isolation, layer ordering/cache and manifest coverage checks.
- `docs/visuals/chakra-charge/`: reproducible source processor, provenance/QC, browser probe, rendered previews and integration notes.

## Tests run before commit

Windows PowerShell; repository worktree `.tools/kunai-combat`; bundled Python3/Node; pinned Godot4.7.2 stable console; Playwright Chromium/WebGL2 SwiftShader. Commands below use the bundled interpreter binaries and `$env:GODOT_BIN` pointing to `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe` in the primary checkout.

| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python docs/visuals/chakra-charge/export_chakra.py` | PASS:64 unique-within-heading body exports; fixed sole116;96 unique-within-layer FX; binary alpha; zero FX edge contacts | `docs/visuals/chakra-charge/asset-qc.json`, provenance hashes |
| `python scripts/ci/godot_ci.py import --project . --log-dir build/chakra-import-3` | PASS | import.log; `.uid` and `.import` sidecars retained |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/chakra-validation-2` | PASS:81 scripts, nine scenes, zero failures | validate log |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/chakra-tests-2` | PASS:1,480 checks, zero failed; zero engine errors | tests-builtin.log; expected deliberately invalid test-fixture sheet warning only |
| `python scripts/ci/godot_ci.py export --project . --out ../chakra-review-web --log-dir build/chakra-review-export`; `finalize-export --project . --out ../chakra-review-web --kind game` | PASS:43MiB debug single-threaded Web export | build-info identifies local base de3a141, not a published revision |
| `python scripts/ci/godot_ci.py check-export --dir ../chakra-review-web --kind game --project .` | PASS: main project plus manifest and1,106 sprite PNG import records inside PCK | command output |
| `node docs/visuals/chakra-charge/browser-proof.mjs ../chakra-review-web build/chakra-browser --capture` | PASS:96 unique actual rendered phases; all8 directions,5 palettes, layers, pause/step/wrap, speeds, fades, zooms; actual hold R/release/move; no runtime errors | proof.json,96 phase screenshots, generated GIF/contact |
| `node docs/visuals/chakra-charge/browser-proof.mjs ../chakra-review-web build/chakra-browser-final` | PASS including actual BUILD-tab click suppressing R visual | proof.json |
| `node scripts/ci/smoke/smoke.mjs --serve-dir ../chakra-review-web --out-dir build/chakra-smoke --label chakra-local` | PASS:11 smoke checks; nine served file hashes; actual movement/attack/jump input; zero fatal console errors | smoke-result.json, console-log.json, screenshots |
| `python scripts/ci/validate_sprite_manifests.py`; `python scripts/ci/validate_orders.py`; `git diff --check` | PASS | command output |
| Integrated base17d516d: `godot_ci.py tests --project . --log-dir build/chakra-integrated-tests`; `export --project . --out ../chakra-integrated-web --log-dir build/chakra-integrated-export`; `finalize-export --project . --out ../chakra-integrated-web --kind game` | PASS:1,486 checks; zero failed/engine errors;43MiB Web export | build/chakra-integrated-* |
| `node docs/visuals/chakra-charge/browser-proof.mjs ../chakra-integrated-web build/chakra-integrated-browser`; `node scripts/ci/smoke/smoke.mjs --serve-dir ../chakra-integrated-web --out-dir build/chakra-integrated-smoke --label chakra-integrated` | PASS:31 chakra checks plus11 smoke checks; zero runtime errors | integrated proof.json and smoke-result.json |

Visual inspection: actual rendered S and N views, all-direction/native-idle comparison,24-sample loop contact and in-world screenshot. Energy has clear source margins; body remains readable through front spirals; ground energy is a projected ellipse. No source GIF or Naruto character copied into the game.

## Issues encountered

- Reference path moved; found the original GIF beneath Dropbox/ALL FOLDERS/SHINOBI RUSH.
- Interrupted generation calls completed; recovered their actual files rather than generating replacements.
- Generic sprite processor initially rejected unsupported `--target fx`; corrected invocation with `asset` then found that fixed-grid cuts split uneven generated gutters. Implemented deterministic empty-gutter registration with preserved raw sources. Do not count the generic processor as a passing check.
- Initial FX scale clipped tall flames. Replaced it with one shared0.70 scale and one consistent ground Y projection scale0.35; all margins now pass, without per-frame bbox resizing.
- Initial negative-Z effects disappeared beneath the floor; corrected to actor Y-sort plane with explicit sibling order.
- Initial native tests exposed a preview hook dereferencing null `current_scene` in test trees. Added null/parent guards and reran the full suite successfully.
- Native2x review framing obscured the ground behind controls. Default review framing is1.5x;2x is optional inspection only.
- Aki's concurrent builder-pan/grass-grid PR merged during checks; fast-forwarded this branch to17d516d and rerunning integrated tests before commit.
- Browser coverage so far: Chromium desktop. No physical controller or Safari device available; new visual preview uses R and touch-friendly review controls, no gamepad mapping change.

## Questions for project owner
None.

## Outstanding work / next steps
Implementation commit, reviewed PR/required CI, main merge, configured Pages deployment, exact-public-SHA verification and live preview checks. Record those references here in a report-only follow-up. Gameplay owner can later connect charge resource mechanics and upgrade/transformation colors to the exposed API.
