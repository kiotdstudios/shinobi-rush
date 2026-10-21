# Job Report — Red-scarf bandit locomotion
- Agent: Codex
- Order: orders/Codex/2026-10-20-bandit-locomotion-art.md
- Date: 2026-10-20
- Final status: REVIEW — art ready for owner review; runtime integration assigned to Aki
- Commit / PR: Art commit e211daeb02bf461c1754daf8e91fe4c299660aa7; https://github.com/kiotdstudios/shinobi-rush/pull/38 (open for review, pushed).

## Work completed
Created the owner's masked, topknot, tattered red-scarf bandit with a plain red cloth headband and no logos. Eight design views and 24 animation clips: four-frame idle and eight-frame regular run/ninja sprint per direction. 160 native128×128 transparent motion PNGs plus eight rotations, fixed root[64,116], body scale comparable to approved player. Separate authored/proposed half-speed FPS metadata.

Delivered 48 per-direction normal/half GIFs, normal/half southeast three-state comparison GIFs, 24 full-frame contact sheets, all-direction sheet, turnaround and player scale comparison. Responsive review page has shared clock, pause, restart, frame scrubber, all-eight view and native/game-close/2x/3x sizes. PixelLab generated the actual art; Python performs lossless extraction/translation/QC and nearest-only previews.

## Files changed
New assets/characters/bandit/ only, plus this Codex order/report and an Aki integration order. Opt-in bandit_128.art.json intentionally avoids SpriteLibrary's recursive *.manifest.json player auto-selection. Source/previews have .gdignore. No player sprite, enemy AI, movement/combat controller or camera code changed.

## Tests run BEFORE implementation commit
Checkout: .tools/bandit-production, branch codex/bandit-locomotion, base21324afb02b639d13a5fe575bde776ab3faa0b6f. Windows, bundled Python/Pillow/numpy, bundled Node24.19, Playwright Chromium, Godot4.7.2.

| Exact command / manual check | Result / evidence |
| --- | --- |
| python assets/characters/bandit/source/export.py | PASS:24 clips, pending[]; fixed translations preserve every opaque source pixel, binary alpha, clear borders, unique frames. |
| python assets/characters/bandit/source/previews.py | PASS: GIFs, all contact sheets, turnaround, player comparison. |
| python assets/characters/bandit/source/validate.py | PASS:160RGBA frames,24clips/eightdirections, unique frames, roots/dimensions and48GIF timing/frame counts. |
| python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS after final exports, zero engine errors.168 PNG import sidecars retained. |
| ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script assets/characters/bandit/source/validate_bandit.gd | PASS:BANDIT_IMPORT_PASS160 textures/24clips; opt-in art excluded from player discovery. |
| python scripts/ci/godot_ci.py validate-resources --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS:34scripts,6scenes,0failures. |
| node assets/characters/bandit/source/browser_check.mjs; repository served with python -m http.server 8788 --bind 127.0.0.1 | PASS at1440×1000 and390×844:3states,8directions, all-eight view, clock, scrub, half/normal playback,4sizes; no page/HTTP errors or horizontal overflow. |
| Manual inspection:8-view turnaround, all24frame contact strips, approved-player scale comparison, phone review screenshot | Logo-free headband, masked red-scarf identity retained. Regular run pumping arms vs sprint trailing hands/forward lean. No terrain/shadow/clipped sprites. Full-cycle replacements preserve outfit details lost in rejected two-batch clips. |
| python scripts/ci/validate_orders.py; git diff --cached --check | PASS: order structure validated; trailing whitespace from API style line trimmed, then staged whitespace check passed. |

## Issues encountered
Template run batches changed size, facing and costume details. Replaced all except the consistent south run with custom full-cycle generation. First v3 sprints failed to hold arms back; replaced with PixMiniMax, with a further northwest pose correction. All rejected versions excluded from final source index and shipped loops. Southeast run required a fixed two-pixel vertical translation for headroom; no body scaling. urllib HTTP403 avoided with curl; transient TLS download retried. Phone scrubber initially overflowed and was fixed/retested. Initial CLI gh was unavailable; use GitHub connector for PR creation.

## Questions for project owner
None required to deliver. Owner can inspect all directions and speeds before accepting the new bandit art.

## Outstanding work / next steps
Aki owns explicit enemy-only runtime binding, approach/sprint mapping, hit/death fallback, movement-speed matching, Y-sort/footprint checks, runtime/browser playtest and reviewed deployment. See orders/Aki/2026-10-20-bandit-locomotion-integration.md and INTEGRATION_NOTES.md. The current game still uses its existing procedural BanditVisual until that integration.

Live deployment: not applicable to this art-only PR; no runtime binding changed. No live game replacement or gameplay playtest claimed. Order remains REVIEW pending visual acceptance and downstream integration.
