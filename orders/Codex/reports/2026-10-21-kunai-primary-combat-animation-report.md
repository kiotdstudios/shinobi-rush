# Job Report — P0 kunai-first southeast art proof
- Agent: Codex
- Order: orders/Codex/2026-10-21-kunai-primary-combat-animation.md
- Date:2026-10-21
- Final status: REVIEW — southeast proof locally tested; integration/live verification pending; owner look/feel gate remains before direction expansion.
- Commit / PR: implementation6fb6d19e13814f3cd093ee277b907c871d08ec7f; original report written BEFORE implementation commit. Reuses PR48 study branch/history; audited PR33/42 notes and changed-asset inventory.

## Work completed
First P0 deliverable: original one-handed kunai SE guard -> three-hit combo -> dodge -> dedicated dash strike -> normal run, in an isolated in-engine art-review scene. Existing PR48 opening thrust/black kunai reused,17 new weaponless128px body PNGs (light2 six,light3 six,dash five), six separate compact swipe VFX. Approved dodge/run body art stays unchanged, with new per-frame sockets/angles. Body[64,116] root,104px standing scale, palette, identity and nearest filtering preserved. Back/front weapon-layer change on the finisher and same-body hand occlusion; one kunai texture throughout.

Half-speed default, normal speed, source ms clock, pause/step/restart, scrub, individual action selection and game/2x zoom. Opt-in via `?kunai=proof`; no gameplay controller, combat hit logic, gameplay camera or production player manifest edits. This does NOT equip the player/bandit in ordinary gameplay. Gameplay integration belongs to Aki after visual approval. The default-melee **art direction** is kunai, with no sword assets in this proof.

## Files / decisions
- assets/characters/player/kunai_primary_se/: explicit custom art manifest,17 bodies/import settings,6 VFX/import settings. `.art.json` avoids accidental SpriteLibrary selection.
- assets/characters/player/source/kunai-primary-se/: accepted original generated raw sheets, .gdignore. Rejected scale-drifting light3 candidate not exported; clipped dash source frame3 omitted; disconnected adjacent-cell fragment in frame4 removed deterministically.
- scripts/art/{kunai_primary_proof,kunai_proof_gate}.gd (+uid), scenes/art/kunai_primary_proof.tscn, scenes/main.tscn: opt-in review scene only. Gate inert in ordinary play.
- docs/visuals/kunai-reference/build_primary_proof.py: fixed-grid nearest/alpha/palette/sole registration and previews; no procedural creative art or interpolation.
- docs/visuals/kunai-primary/: contact sheet, mobility sockets, normal/half GIFs, QC, INTEGRATION_NOTES.md and browser evidence.
- tests/test_kunai_primary_proof.gd and runner entry: current AttackDef timing/contact compatibility, persistent weapon, rear/front layers, action reset/step, default player set.
- scripts/ci/smoke/kunai-proof-probe.mjs: real pointer-based review controls and all action/weapon/error checks.
- Order progress/report.

## Tests BEFORE commit
Windows, Godot4.7.2, bundled Python/Node, headless Chromium software renderer. GODOT_BIN points to .tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe (absolute).

| Command / steps | Result | Evidence |
|---|---|---|
| python docs/visuals/kunai-reference/build_primary_proof.py | PASS17 native128RGBA new bodies; all56 frame sockets opaque; unique files per action;6 independent VFX; normal/half sequence | asset-qc.json/contact sheets |
| python scripts/ci/godot_ci.py import --project . --log-dir build/kunai-primary | PASS textures/scripts/imports | import.log |
| python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/kunai-primary |42 scripts,7 scenes,0 failures | validate-resources.log |
| python scripts/ci/godot_ci.py tests --project . --log-dir build/kunai-proof-final-tests |808 passed,0 failed after timing/control fixes | tests-builtin.log |
| python scripts/ci/godot_ci.py export --project . --out ../kunai-proof-final-web --log-dir build/kunai-proof-final-export | PASS | export.log |
| python scripts/ci/godot_ci.py finalize-export --project . --out ../kunai-proof-final-web --kind game --commit-sha ee4f4b93da5ec6aeb3fb43fe6ce815e639d5b8a4 | PASS; base identifier for UNCOMMITTED local source, not a live SHA | export metadata |
| node scripts/ci/smoke/kunai-proof-probe.mjs --serve-dir ../kunai-proof-final-web --out-dir build/kunai-proof-final-browser |12 checks PASS: default half/all actions/weapon persistent/pause/step/normal/half/action select/behind/front contact/scrub/no errors | local-proof-probe.json |
| node scripts/ci/smoke/smoke.mjs --serve-dir ../kunai-primary-web --out-dir build/kunai-game-smoke --label kunai-default-game | PASS ordinary gameplay rendered, keys and hashes,0 fatal errors | local-game-smoke.json |
| node scripts/ci/smoke/controls-probe.mjs --serve-dir ../kunai-primary-fixed-web --out-dir build/kunai-game-controls | PASS ordinary movement,sprint,collision,jump/dodge lab, camera/impact modes;0 console errors | local-game-controls.json |
| Inspect normal/half previews, attack/mobility contacts and Godot browser screenshot | Correct SE original player/short black kunai, separate swipe, readable deep dash and turning finisher | local-proof.png |
| git diff --check | PASS | local command |

## Issues / limitations
Preview shorter-action selection initially clamped the old scrub value to a new clip's end, wrongly pausing at its last pose; fixed by blocking scrub signals and resetting value during clip selection, added regression. Initial browser harness used overly-fast popup keyboard traversal and chose light2; replaced by actual inspected popup pointer target. Both fixed and probe rerun green. Expected malformed-sheet test emits its fixture warning; no failed assertions. Physical gamepad unavailable; preview uses touch/pointer buttons. Browser performance here is software rendering, not hardware performance evidence. No paid PixelLab calls used.

Standalone light1/2/3/dash durations300/350/483.333/400ms match current AttackDef. Contact indices2 at83.333/100/150/100ms. Nominal sequence trims light1 at150ms,light2 at200ms,dodge at920ms within existing combo/late-dodge intervals; locomotion remains approved12FPS. Normal sequence4220ms, half8440ms. No damage/hitstop/root-motion simulation is claimed. Hurt,block/parry/deflect,airborne and eight-direction coverage remain outside this first gated proof; no full P0 completion claim.

## Questions / review gate
Review the concrete SE look/feel before eight-direction production, as explicitly required by the order. No direction expansion performed.

## Outstanding work
Integrate latest main (Aki jump and Kiro lab zoom changed while art was in progress), rerun tests/build/browser checks, reviewed PR/green CI/merge/verified public build. New P1 jump-recut/air_attack order is queued behind this P0 proof and depends on approved kunai style; Chidori work remains separate, not discarded. Handoff timings/sockets/cancel references are in INTEGRATION_NOTES.md. Final live evidence/report-only commit follows deployment.

## Latest-main integration retest BEFORE merge-update commit
Merged origin/main91cd0b1 (Aki responsive0.85s jump/progress-resume and Kiro lab half-step zoom) without committing, preserved both sets of changes. `python scripts/ci/godot_ci.py tests --project . --log-dir build/kunai-merged-tests`:830 passed,0 failed. `validate-resources --project . --log-dir build/kunai-merged-validation`:43 scripts,7 scenes,0 failures. Fresh export `../kunai-primary-merged-web` plus finalize with premerge base6fb6d19; `kunai-proof-probe.mjs --serve-dir ../kunai-primary-merged-web --out-dir build/kunai-merged-proof`:all12 checks PASS. `controls-probe.mjs --serve-dir ../kunai-primary-merged-web --out-dir build/kunai-merged-controls`:PASS, including1.5x lab step, jump/dodge selection, all camera-impact modes and0 console errors. These are uncommitted local build identifiers, not live claims. No new art/controller changes during this integration.
