# Job Report — Recoverable physical kunai
- Agent: Codex
- Order: orders/Codex/2026-10-25-kunai-recovery.md
- Date: 2026-10-25 (America/New_York)
- Final status: REVIEW — locally tested, PR / canonical publication pending
- Commit / PR: pending implementation commit

## Work completed
Implemented the owner's kunai pickup/recovery rules for player and Bandit projectiles, using the existing approved black kunai PNG. No new bitmap generation or PixelLab credit spend. White floor light, halo and sharp glints are independent of the black sprite. Code-driven fall/tumble/rotation/two bounces settle smoothly into a smaller ground-aligned collectible. Two original synthesized metallic clinks accompany contact. Timing and source metadata: docs/visuals/kunai-recovery/animation.json.

Character hits keep existing damage/hit feedback and consume the blade without a pickup. Nearest surface interception is checked before a character behind it. Wall/tree impacts embed for 0.4 s, then fall/bounce; recovery searches only the impact side within 32–96 px, checks the player's footprint against solid collision, bounds, navigation and reachability, and rechecks at settling. Inaccessible locations create no pickup. Range travel clamps without overshoot. Evaded Bandit blades keep the existing dodge/jump/substitution outcome and continue past that target once toward eventual recovery.

Kunai is now a normal Builder → Pickups entry, sharing gourd/paper-tag inventory transfer and absorption feedback with white effects. Authored pickups float/respawn normally. Spent blades stay grounded, refund exactly one ammo once and never respawn; full bags leave them available. Fixed the legacy 10-start / 9-cap mismatch by making kunai capacity 10 while preserving other item limits. At most 64 spent-blade pickups persist; oldest is removed when another is created. This bounds repeated Bandit misses; authored pickups are exempt.

An isolated `?kunai=recovery` review exercises actual projectile and pickup classes, character hit, ground miss, surface embed and Bandit miss, plus collection/normal/half/pause. Normal and half-speed GIFs captured from the actual Web export. The target's presentation timers advance without enabling its AI; the proxy surface is review-only. No attack, AI state machine, camera or map redesign.

## Files changed
- scripts/pickups/kunai_recovery.gd: shared physical recovery, surface/ground safety, clinks and one-use pickup.
- scripts/combat/player_kunai.gd / scripts/enemy/bandit_kunai.gd: ordered sweep outcome and recovery; damage preserved.
- scripts/pickups/health_gourd.gd / gourd_pickup_fx.gd: kunai kind, white light/absorption, grounded/non-respawning variants, duplicate/full-bag guards.
- scripts/player/inventory.gd: kunai-only capacity 10; existing starter counts/slot assignments preserved.
- scripts/editor/placed_objects.gd: kunai Pickups entry.
- scripts/art/kunai_recovery_review.gd, review scene and kunai_proof_gate.gd: opt-in real-item review.
- tests/test_kunai_recovery.gd, runner and inventory-test description: outcome, accessibility, collection and regression checks.
- docs/visuals/kunai-recovery: metadata, integration notes, actual browser screenshots/GIFs, reproducible proof/capture scripts.

## Tests run before commit
Windows; Godot 4.7.2 stable; bundled Python/Node; Chromium debug Web export.

| Test / command | Result | Evidence |
| --- | --- | --- |
| `python scripts/ci/godot_ci.py import --project . --godot <4.7.2> --log-dir build/kunai-final-import` | passed | build/kunai-final-import.txt |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <4.7.2> --log-dir build/kunai-recovery-final-validate` | 350 scripts /24 scenes, zero failures | build/kunai-recovery-final-validate.txt |
| `python scripts/ci/godot_ci.py tests --project . --godot <4.7.2> --log-dir build/kunai-final-tests` | **2854 passed /0 failed** | build/kunai-final-tests.txt |
| `<godot> --headless --path . --script res://build/kunai_recovery_focus.gd` after two final Bandit-wall/inaccessible-settle assertions | **218 passed /0 failed**; existing inventory/substitution/gourd/bomb regressions included | build/kunai-final-focus.log |
| `python scripts/ci/godot_ci.py export --project . --out ../kunai-recovery-reviewed-web-20261025 --godot <4.7.2> --log-dir build/kunai-reviewed-web` | debug Web passed | build/kunai-reviewed-web.txt |
| `node docs/visuals/kunai-recovery/browser-proof.mjs ../kunai-recovery-reviewed-web-20261025 docs/visuals/kunai-recovery/local-browser` | **15/15 passed**, no page/console errors; actual hit/no-drop, fall/settle, surface embed/settle, player/Bandit collection, normal/half/pause | local-browser/validation.json and inspected screenshots |
| `capture-preview.mjs` / `make_previews.py` | normal and half-speed actual Web GIFs, 85 frames each, measured capture intervals | normal.gif /half-speed.gif |
| `python scripts/ci/validate_orders.py`; `git diff --check` | passed | command output |

Clink generation (4410-byte nonempty clip) and both bounce contact events verified in native tests; audio playback is wired to the Web/native AudioStreamPlayer2D. Headless checks do not claim subjective listening.

## Issues encountered
Initial review background obscured its lower white light pool; moved review-only floor drawing behind pickups and rechecked the actual Web preview. Review target initially held its hit tint because AI/physics were disabled; ticked presentation timers only and reverified. Corrected the existing starter/cap mismatch to allow first-throw recovery. Focused standalone test harness retains ObjectDB cleanup warnings; full test wrapper passed with only its expected bad-sheet fixture warning. Accessibility uses the existing navigation clearance, conservatively rejecting some narrow/obstructed edges rather than creating inaccessible loot.

## Questions for project owner
None.

## Outstanding work / next steps
Reviewed PR CI and merge, main deployment/postdeploy, exact-SHA public visual/functional proof and final report. Until then **NOT LIVE**. Optional future work: broader loot persistence across map unloads; no persistence/save redesign is included here.

## Main/editor integration — 2026-10-25
PR https://github.com/kiotdstudios/shinobi-rush/pull/198; original implementation `f76670f97603aa01f9255661e018528bf96d6dd5`. Main advanced to Aki's map-editor merge `bd4a211448b7dfa37583a2c74cc2e131647d0a64`. Integrated via `git merge --no-commit --no-ff origin/main`, no conflicts. Added the pickup visibility guard so hidden/frozen editor players cannot auto-collect placed loot; no edits to Aki's editor implementation beyond merging it.

Before integration commit: Godot import passed; map-editor + all kunai/inventory/substitution/gourd/bomb focused regressions **252 passed /0 failed**, including hidden-player rejection; debug Web export to `../kunai-recovery-editor-web-20261025` passed; integrated actual browser proof **15/15**, no console/page errors (integrated-browser/validation.json). All 85-frame GIFs decode; samples inspected. Kunai placement is in the dedicated Map Editor's Pickups palette; the public game's editor visibility remains Aki-owned. Required updated PR CI/main deployment and public proof still pending.

## Simultaneous-drop guard — 2026-10-25
Initial integrated PR CI 40200405594 passed its native build: **2865/0** tests and 351 scripts/24 scenes validated. Before publication, tightened the spent-pickup cap to ignore nodes already queued for deletion and remove excess old entries in a loop. This prevents several settle events in the same frame from repeatedly choosing the same pending deletion. Added two outcome tests at a full 64-blade population, before and after deferred deletion. Before this commit: focused map-editor/item regressions **254/0** (both cap assertions passed), debug Web export to `../kunai-recovery-batch-web-20261025` passed, actual Web proof **15/15** with no console/page errors (batch-browser/validation.json), orders validator and diff check passed. No visual/timing changes; existing GIFs remain representative.
