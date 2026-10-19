# Job report - Actual128px character animation delivery
- Agent: Codex
- Order: Order01 / owner request to push actual animations
- Date: 2026-10-19
- Status: REVIEW - actual runtime assets published
- Branch: codex/player-128-runtime-assets
- Commit / PR: 55dc1825e2f4ec9962418cccf3455088447848fb / https://github.com/kiotdstudios/shinobi-rush/pull/23

## Work completed
Delivered actual transparent PNG runtime art rather than GIF previews.559unique PNG files: approved idle v5 (120unique; SW8poses held2ticks), walk v1 (128), approved run v3 (160), sprint v5 for gameplay testing (151; NW11poses). Runtime manifest player_128.manifest.json uses schema1 and matches the existing sprite drop-in contract.128x128RGBA, foot anchor[64,116], body104px. Eight original directions; no mirroring. Source pixels retained exactly.12poses/sec default matches owner half-speed review; authored24fps metadata retained. IdleSW double holds use repeated path references to existing8PNG files, preserving approved timing without creating filler files. Runv4 south candidate excluded because owner explicitly requested approved run.

Production PNGs under assets/characters/player/sprites/production/. Hash provenance and integration notes under animations/. Shadow is not baked into any sprite. Removed review-generated ellipse shadow from source harness and jump/dodge review builders. Gameplay-rendered shadows are owned by gameplay code and not changed in this asset-only handoff.

## Tests before commit
- Existing sprite_manifest validator: PASS schema1, all referenced files, frame sizes, directions and anchors.
- Pillow/hash audit: PASS559PNG modeRGBA,128x128,binaryalpha; exact source SHA256 matches; each unique pose list has distinct PNG content. Purposeful idleSW repeated path holds are explicit.
- Godot4.5.1 OpenGL compatibility isolated harness loaded this actual package: idleS/SW/E, walkS/NE, runS/E/N, sprintS/N/NW capture PASS. Engine logs only environmental certificate-store warning; no script/texture/runtime errors. NW sprint11frames; idleSW16ticks. Prior approved art engine checks also remain valid because the PNG bytes are unchanged.
- New Godot import initially could not save editor settings outside workspace and runtime log rotation crashed; rerun with self-contained editor data and explicit workspace --log-file succeeded. This is an environment workaround, not a gameplay change.
- Order validator and staged whitespace checks run before publishing commit.

## Files / scope
player_128.manifest.json; sprites/production/559PNG; animations/production-provenance.json; animations/PRODUCTION_HANDOFF.md; this report. Only these package files go into the asset PR. Existing unrelated local edits and large rejected source files excluded.

## Issues and limitations
Terminal network access is blocked. GitHub connector is used to publish immutable blobs, then a commit on a fresh branch from current main; no force push. Previous preview PR3 was already merged, so a new PR is required. Full gameplay engine is newer than the isolated art harness; no current full-game or Web smoke test is claimed. After reviewed merge the configured Pages pipeline can integrate this runtime manifest. No automatic merge or branch-protection bypass performed.

## Questions
None.

## Remaining work
Review/merge/in-game transition and performance checks, then verify deployed build. JumpNE no-kick correction and dodge remain separate visual review candidates and are not shipped as accepted runtime animations. Full Order01 remains incomplete. Live deployment: not yet updated by this unmerged asset PR; no live verification claimed.

Publication verification: GitHub branch refs updated without force; PR23 contains564changed files. Runtime manifest fetched back successfully. Published idle/S_000.png blob SHA913bff84086f20ef4799748ba401aab68713d9a1 matches uploaded exact PNG. No combined commit statuses were reported at first check; CI/deployment are not claimed passed.

## CI / integration handoff after publication
GitHub Actions run39220440077: asset/order validation and Godot4.7.2 import/validate/test/Web export PASS. Browser smoke itself PASS: correct build SHA, engine start, visible/nonblank canvas, input effect, zero fatal console messages. Subsequent controls probe FAIL on lab-close-restores-baseline (zoom1 instead0.4444) and camera-close-via-query (zoom1.211538 for104px art versus hardcoded1.1667 expectation corresponding108px). Movement and sprint speed checks PASS, no browser error/pageerror. Overall godot-ci-gate remains FAIL because of those camera checks. No merge/deploy performed; gameplay/camera owner must resolve or review these checks. These are not PNG/manifest validation failures. Log: https://github.com/kiotdstudios/shinobi-rush/actions/runs/39220440077/job/117954448864

Final publication: asset commit55dc1825e2f4ec9962418cccf3455088447848fb; preview/report follow-up3bb4013c413ff347ef0cdd6261a51051197cc87b; https://github.com/kiotdstudios/shinobi-rush/pull/23. Both published preview blobs fetched via GitHub connector and their Git blob hashes match local decoded/verified GIF bytes. No new live build claimed.
