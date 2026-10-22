# Job report — SE player kunai and Body Flicker proof

- Agent: Codex
- Order: `orders/Codex/2026-10-21-player-kunai-flicker-combat-rework.md` (PR #65)
- Date: 2026-10-22 America/New_York; work began October 21
- Final status: IN_PROGRESS — tested SE visual proof prepared for integration/live review; full order remains pending owner/Aki
- Commit / PR: Not committed yet; this report precedes implementation commit.

## Work completed

Created four original compact 128×128 RGBA flicker body poses, preserving the player appearance, fixed `[64,116]` anchor and separate black kunai. Added per-frame hand sockets, orientations and nonuniform event timing in the existing player hierarchy. Reused approved two-hit kunai poses with a reverse-grip first contact, and moved existing contact VFX into `assets/vfx/kunai_contact/`.

Added an interactive, SE-only Godot art proof at `?kunai=proof`: two buffered hits, optional double backward flicker, single flicker, re-engage, half/normal speed, inspection, zoom and reset buttons. The proof actor sweeps against the unchanged courtyard collision while visually hidden. Body vanishes/reappears twice over 280 ms; one reusable sharp afterimage fades without residual nodes. Historical automatic proof retained at `?kunai=legacy`.

Imported only the exact `assets/vfx/body_flicker/` baseline from Orcha PR #61 head `43c316a9c2309f1cafa2918c6ecd8d0ff08a5a97`; verified no diff against that source after staging. No Orcha demo code imported or overwritten. Main dependency audit: `562ede18a414df54660fed1cae2d6d3cee863cd5`. No Aki implementation branch was available. Aki's order PR #64 was open. No gameplay controller, AI, walls, hitboxes or Kiro camera files changed.

## Files changed

- Body frames/source and `animations/body_flicker_SE.art.json` under `assets/characters/player/`.
- `assets/vfx/body_flicker/` (Orcha baseline) and moved `assets/vfx/kunai_contact/`.
- `scripts/art/{flicker_combat_proof,player_flicker_visual,kunai_pose_actor}.gd`, proof scene and query gate.
- Existing kunai art metadata/exporter references; legacy browser probe route.
- `tests/test_player_flicker_proof.gd`, test runner, `scripts/ci/smoke/flicker-proof-probe.mjs`.
- `docs/visuals/player-flicker/`: source exporter, contact sheet, timing/API handoff and browser evidence.

## Tests run before commit

Environment: Windows PowerShell, pinned Godot 4.7.2, bundled Python/Pillow and Node/Playwright Chromium (SwiftShader). Commands from the dedicated `.tools/kunai-combat` checkout. Set `GODOT_BIN` to the repository `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`; `python`/`node` below denote bundled executables.

| Exact command / procedure | Result | Evidence |
| --- | --- | --- |
| `python docs/visuals/player-flicker/export_body.py` | PASS four unique 128 RGBA frames, binary alpha, nearest/palette, opaque sockets and fixed sole registration | `body-contact.png`, art manifest hashes |
| `python scripts/ci/validate_orders.py` | PASS | console |
| `python scripts/ci/validate_sprite_manifests.py` | PASS 1 manifest, zero errors | console |
| `python scripts/ci/godot_ci.py import --project . --log-dir build/flicker-final-import` | PASS imports | `build/flicker-final-import/import.log` |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/flicker-validate-final` | PASS 47 scripts, 8 scenes, zero failures | validation log |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/flicker-tests-final` | PASS 869 assertions, zero failed | `build/flicker-tests-final/tests-builtin.log` |
| `python scripts/ci/godot_ci.py export --project . --out ../player-flicker-web-4 --log-dir build/flicker-export-4` | PASS Web export | export log |
| `python scripts/ci/godot_ci.py finalize-export --project . --out ../player-flicker-web-4 --kind game --commit-sha 562ede18a414df54660fed1cae2d6d3cee863cd5` | PASS local package integrity, 38 MiB; SHA identifies base, not a deployed change | local build-info |
| `node scripts/ci/smoke/flicker-proof-probe.mjs --serve-dir ../player-flicker-web-4 --out-dir build/flicker-browser-release` | PASS all 13 checks, zero browser errors | preserved `browser-evidence.json` |
| `node scripts/ci/smoke/kunai-proof-probe.mjs --serve-dir ../player-flicker-web-2 --out-dir build/flicker-legacy` | PASS all 12 historical animation/weapon/step/scrub checks after contact texture move | probe JSON |
| `node scripts/ci/smoke/controls-probe.mjs --serve-dir ../player-flicker-web-2 --out-dir build/flicker-controls` | PASS normal game WASD, sprint, wall stop, real Animation Lab open/close/animations, camera baseline/impact regressions, zero errors | controls probe JSON |
| `node scripts/ci/smoke/smoke.mjs --serve-dir ../player-flicker-web-4 --out-dir build/flicker-smoke --label flicker-local` | PASS all smoke checks, zero fatal browser errors | smoke artifacts |
| `git diff --check` | PASS | console |

Browser proof uses actual keyboard and mouse events, read-only state telemetry: hit twice, verify no forced escape, click double, verify two traversals/vanishes/reappearances and retreat displacement; repeat single eight times; half/normal; Tab inspection interrupt; movement direction interrupt; buffered re-engagement. Unit tests additionally exercise collider always enabled, wall stops, large time steps and no ghost resurrection on later ticks. Screenshots were visually inspected at close gameplay zoom. The custom proof inspection toggle is not the actual Animation Lab; normal-game Lab regression was tested separately.

## Issues encountered

Fixed floating-point clip end comparison, a native `hidden` member naming collision, review buttons swallowing Space/Tab through focus, and completed ghost state resurfacing after a large delta. All retested. The deliberately malformed sprite-sheet fixture emits its expected warning in the passing suite.

This is a playable **art harness**, not integrated player combat or damaging bandit behavior. Existing bandit remains an idle reference here. No supported gamepad or mobile hardware was available; buttons and desktop Chromium were tested. Orcha streaks remain authored for SE; other movement vectors test safe cleanup, not completed directional artwork.

## Questions for project owner

Pending: final selectable double-retreat binding (double-tap dodge, hold after hit two, or separate button); Aki owns implementation. The explicit Double back preview button keeps this decision open. Owner must review the new SE proof before eight-direction production.

## Outstanding work / next steps

Integrate through PR and required green CI, verify exact deployed SHA and live keyboard/mouse proof, then add links/results below. Aki should wire the visual contract into real combo/movement/damage and retest actual Animation Lab interruption there. Eight directions gated on owner approval. Bandit Level 1 order remains separate and unfinished. See `docs/visuals/player-flicker/HANDOFF.md` for event timings and ownership.

Live deployment: pending; no claim of an updated public build yet.
