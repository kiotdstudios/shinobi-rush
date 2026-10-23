# Job Report — Charge-body revision and rejected VFX archive
- Agent: Codex
- Order: ../2026-10-23-charge-body-revision.md
- Date: 2026-10-23
- Final status: REVIEW — body-only art candidate, owner visual review pending
- Commit / PR: Implementation e6d210529852ca814f2e9b447a045b84d0cce15b; https://github.com/kiotdstudios/shinobi-rush/pull/126 (draft, unmerged). Original report preceded implementation commit.

## Work completed

Owner clarified that both player and bandit need the pose. Created charge-body holds for both approved skins, eight headings each,16 unique native128×128 keys per heading:256 exported frames and16 transparent512×512 atlases. Hands join upright at chest, knees bend into a planted wide stance, elbows out; rear views keep the seal in front of the body. Refined the initial SE concepts to reduce the excessive vertical inhale. No baked weapon, aura or floor shadow. Western views are exact native mirrors. Manifest gives root(64,116),12FPS loop and6FPS half-speed review. Source hashes and cell registration are recorded in qc.json. Individual original concept/anchor files are preserved for provenance under Godot-ignored source folders.

Added normal/half GIFs for all headings, contact sheet, and an isolated responsive review page with both skins, direction selection, pause, frame step, scrub and normal/half clock. This art is not bound into gameplay or the production player manifest; controllers, AI and camera are unchanged.

Archived rejected V1/V2 to Desktop `Shinobi Rush - Chakra VFX Giveaway - 2026-10-23`. VFX-only ZIPs each have96 transparent frames, effects-only previews and sanitized metadata; public packs exclude character/reference images. Private originals are separate. Verified273 SHA256 records, including the226 files moved from V2 after absolute-path checks. PR107 and PR118 were closed unmerged as rejected. V2 archive cleanup was separately tested, reported and pushed in cb36634. Git history remains recoverable.

## Files changed

- assets/characters/{player,bandit}/charge_body/: source receipts/anchors, frames, atlases and Godot import sidecars.
- docs/visuals/charge-body/: manifest, extraction/validation/native/browser checks, QC, previews, review page, archive utility and integration notes.
- Own order/report only. No other agent-owned runtime files.

## Tests run before commit

Environment: Windows PowerShell; bundled Python/Pillow/NumPy and Node/Playwright Chromium; Godot4.7.2stable. Commands below run from this branch's worktree. Python/Node refer to bundled absolute runtimes, GODOT_BIN to the installed4.7.2console binary.

| Command / manual step | Result | Evidence |
| --- | --- | --- |
| Python docs/visuals/charge-body/archive_chakra.py plus independent ZIP/hash checks | PASS;273 hashes;96 frames per public ZIP; no character/reference/body files | Desktop verified-sha256.json and archives |
| Python docs/visuals/charge-body/export.py | PASS; fixed-cell nearest extraction and root registration; no per-frame resizing | qc.json, source SHA256 and frame translations |
| Python docs/visuals/charge-body/validate.py | PASS;256 RGBA128px hard-alpha frames;16 distinct keys per heading; bottom116; root within0.5px; exact mirrors;16 GIFs correctly timed | validation.json |
| Node docs/visuals/charge-body/browser-proof.mjs | PASS;256 PNGs load;8 headings×16steps; pause stable; normal500ms advances0.5s, half0.25s; no console/page errors | build/charge-body-browser/result.json;1000.png and390.png |
| Python scripts/ci/godot_ci.py import --project . --log-dir build/charge-body-native (GODOT_BIN set) | PASS; exit0; generated272 texture sidecars retained | build/charge-body-native/import.log |
| Godot --headless --path . --script docs/visuals/charge-body/native-proof.gd | PASS;256 imported Texture2Ds and16 atlases at expected dimensions; no engine/script errors | CHARGE_BODY_PASS stdout |
| Python scripts/ci/validate_orders.py | PASS | Agent READMEs and order structure validated |
| Visual inspection of eight-heading contact sheet and phone browser screenshot | Correct planted seal silhouette and readable separated character designs; phone controls fit | directions-contact.png and build/charge-body-browser/390.png |

## Issues encountered

First concept SE inhale rose too far and was replaced before final export. Cell height ranges differ by heading/skin (hair, ponytail and crouch projection); inspect switching in the review before accepting production binding. Within-clip ranges are recorded, with bandit S spanning101–105px. Automated anchors/uniqueness do not establish owner visual approval or eliminate all possible cloth/pose issues. Browser phone testing is viewport emulation, not a physical handset. Full gameplay regression/Web export not run: no runtime binding/code changed.

## Questions for project owner

None. Owner can inspect the concrete normal/half-speed candidates; no blocking permission request.

## Outstanding work / next steps

Owner visual review, then gameplay owner can bind approved charge holds and coordinate entry/release timing. Keep rejected VFX disabled. Live deployment: not applicable; new package is unbound review art and cannot change the shared live game. Dedicated draft art PR for reviewed integration; no main merge claimed.

Published preview verification: fetched SE-half-speed.gif from raw.githubusercontent.com at the exact implementation SHA on2026-10-23; downloaded SHA256 BB27F45E68A0B4CCB24A15F50ED31ED25DCAD59BA527F9EE2AFA9915999DF0CC matches local. This confirms published preview bytes, not a game deployment. Worktree clean after implementation push.
