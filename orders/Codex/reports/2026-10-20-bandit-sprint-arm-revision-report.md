# Job Report — Bandit sprint arm correction
- Agent: Codex
- Order: orders/Codex/2026-10-20-bandit-locomotion-art.md
- Date: 2026-10-20
- Final status: REVIEW — corrected eight-direction sprint ready for owner inspection
- Commit / PR: Revision31848d5ba6d7efff44497635cb173cd2c7f4d67b pushed to https://github.com/kiotdstudios/shinobi-rush/pull/38; PR returned to ready-for-review. Owner visual acceptance pending.

## Work completed
Replaced all64 sprint frames in S/SE/E/NE/N/NW/W/SW. V1 hands bent/clasped at lower back; rejected text-only v2 reached forward or sideways. Final bandit_sprint_v3 uses explicitly posed custom start frames, retaining independently trailing arms, rearward shoulder/elbow/wrist lines, forward lean and continuous running legs. South uses low foreshortened trailing hands rather than raised hands. Rear diagonals use separate extended arms instead of a hand against the waist. No logos, floor shadow or redesign.

PixelLab generated the animation PNGs. Keyframes E/N/W/SW use palette-matched PixelLab character state bc949fa1-7738-4bd8-b4aa-6de553c13e48. Built-in image_gen produced SE and S/NE/NW pose guides from bandit appearance and corresponding approved-player sprint anatomy references. Those guides were nearest-sampled into a common128px key grid with binary alpha before PixelLab animation. No final animation body is resized; final exports use fixed translations and preserve all opaque source pixels. Exact guide prompts, originals, extraction script and provenance are included.

Delivered new sprint-v3-* normal/half GIFs for every direction, all-eight synchronized GIFs and before/after comparisons against rejected v1. Updated review page defaults to sprint and half speed; new URLs/cache version distinguish corrected art. Existing native frames/metadata structure and root[64,116] remain compatible. All idle and regular-run PNGs are byte-identical to initial art commit e211dae.

## Files changed
assets/characters/bandit/sprites/sprint/, matching source/raw/sprint/, source archive/status/QC/provenance/guides/export scripts, art JSON revision tag and previews. Codex order/reports and Aki handoff note. No player sprites, gameplay/combat controller, enemy AI or camera code changed.

## Tests performed BEFORE revision commit
Windows checkout .tools/bandit-production. Bundled Python/Pillow/numpy and Node24.19; Playwright Chromium; Godot4.7.2.

| Command / manual inspection | Actual result |
| --- | --- |
| python assets/characters/bandit/source/export.py | PASS:24clips,pending[];160 nativeRGBA motion frames including64 replaced sprint frames; fixed translations, no clipping/border contact, no duplicate source frames. |
| python assets/characters/bandit/source/previews.py | PASS: refreshed normal/half loops, per-direction contact sheets, all-direction sheet, scale comparison. |
| python assets/characters/bandit/source/revision_previews.py | PASS:20 additional versioned GIFs, including eight-direction and v1-before/after. |
| python assets/characters/bandit/source/validate.py | PASS:160RGBA frames/24clips/eightdirections and48per-direction GIF timing/frame-count checks. |
| python assets/characters/bandit/source/validate_revision.py | PASS: every sprint PNG replaced; all idle/run PNGs byte-identical; versioned GIF counts/timings correct. |
| python scripts/ci/godot_ci.py import --project . --godot ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe | PASS:64 revised textures reimported; zero engine errors. |
| ../godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script assets/characters/bandit/source/validate_bandit.gd | PASS:BANDIT_IMPORT_PASS160textures/24clips; explicit opt-in binding excluded from player discovery. |
| node assets/characters/bandit/source/browser_check.mjs; repository served at127.0.0.1:8788 | PASS:1440×1000 and390×844, all states/directions, shared clock/scrub, half/normal speed,4sizes; no page/HTTP errors or horizontal overflow. Screenshots refreshed in previews/. |
| Manual full-frame strips for all8 final sprint directions, compared with approved player pose references | Reviewed every final pose: hands separated rather than clasped, arms remain rearward on side/diagonal views, front view hands low, visible ongoing leg motion/scarf follow-through. Owner acceptance remains pending; anatomy is a visual judgment, not proven by file checks. |
| python scripts/ci/validate_orders.py; git diff --cached --check | PASS: order structure validated; staged whitespace check clean. |

## Issues encountered
Original replacement jobs took over14minutes without output; oldestSE cancelled/retried. Outputs eventually arrived but failed visual posing and were rejected. Explicit custom keyframes resolved the ambiguity. First v3 south key raised hands; rear diagonals still bent one elbow; those3 were replaced again using approved-player pose guides before final acceptance. An intermediate export correctly rejected a border-touching south pose and later an incomplete2-direction set; neither was committed. Final export has no pending issues. GitHub draft conversion initially hit HTTP503; retry succeeded. PR remains unmerged, to return to review after revision push.

## Questions for project owner
None required to deliver. Review the versioned half-speed and before/after GIFs for visual acceptance.

## Outstanding work
Aki owns enemy-only runtime binding, movement-speed/footprint/Y-sort and hit/death fallback tests, reviewed integration and live deployment. No live game update claimed. Live deployment: not applicable to this opt-in art-only revision. Follow-up records revision SHA and PR links after push.
