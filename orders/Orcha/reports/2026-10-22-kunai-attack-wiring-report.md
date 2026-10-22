# Job report -- Wire Codex's kunai strike art to attack_light (controller Square / keyboard J)
- Agent: Orcha
- Order: orders/Orcha/2026-10-22-kunai-attack-wiring.md
- Date: 2026-10-22
- Final status: DONE (pending PR merge + live deploy verification)

## Work completed
Checked whether Codex's kunai attack was committed and controller-synced. Found: `attack_light` was
already correctly bound (keyboard J, gamepad button 2 = Square/X) and already drove a real damaging
combo mechanically. Codex's kunai BODY ART existed on disk (`kunai_poc/`, `kunai_primary_se/`,
proof-stage, SE-only, explicitly flagged `"runtime_integrated": false` / `"owner_review_required..."`
in its own art.json) but was never wired into the production manifest the real player loads -- Square
triggered a real attack with zero visible kunai art, and no weapon-rendering layer existed at all
anywhere in the production pipeline.

Wired it in for real: added light1/light2/light3/dash_attack to the production SpriteSet (SE-only,
matching the approved proof scope), built a weapon overlay (new `WeaponRig` + a real `Sprite2D` in
`PlayerVisual`) using the exact placement math Codex's own verified proof scene already uses, and
gated playback strictly to a literal SE facing so the other 7 (not-yet-approved) directions are
completely unaffected.

Found and fixed a real blocker along the way: naively adding SE-only animations to the manifest would
have invalidated the ENTIRE player SpriteSet (a hard cardinal-direction validity gate), making the
whole character disappear -- not just the new art. Added a scoped, opt-in `allow_partial_directions`
flag (both in the GDScript parser and its separate Python CI validator) so only the 4 new proof
animations are exempt; every already-shipped animation keeps its strict full-coverage requirement.

## Files changed
- `scripts/sprites/sprite_set.gd`, `scripts/ci/validate_sprite_manifests.py`: `allow_partial_directions` opt-in.
- `assets/characters/player/player_128.manifest.json`: light1/light2/light3/dash_attack entries (SE only), pointing at Codex's existing frame files.
- `scripts/combat/weapon_rig.gd` (new): per-frame kunai hand/angle/layer data, copied from Codex's art.json.
- `scripts/sprites/sprite_actor.gd`: `current_frame()` getter.
- `scripts/player/player_visual.gd`: weapon grip/blade nodes, SE-only gating in `play_action()`, `_update_weapon()`, `weapon_visible()`.
- `scripts/web/web_bridge.gd`: `player_attack_anim` / `player_weapon_visible` telemetry.
- `tests/test_kunai_attack_wiring.gd` (new, 27 assertions), registered in `tests/run_tests.gd`.
- `orders/Orcha/2026-10-22-kunai-attack-wiring.md` (this order)

## Tests run before commit
| Test / command | Result | Evidence |
| --- | --- | --- |
| `godot_ci.py import` | PASS | clean |
| `python scripts/ci/validate_sprite_manifests.py` | PASS | 0 errors (16 errors before the Python-side opt-out fix) |
| `python scripts/ci/validate_orders.py` | PASS | clean |
| `godot_ci.py tests` (full suite) | PASS | `SUMMARY: 1379 passed, 0 failed` (was 1337 at session start; +27 new assertions in `test_kunai_attack_wiring.gd`, zero regressions; pre-existing `test_combat.gd` combo test, which attacks facing East, still passes unchanged) |
| Real Web export + `controls-probe.mjs` (full existing suite) | PASS | `VERDICT PASS`, 34/34, 0 console errors |
| Ad hoc live keyboard verification (Playwright, not committed) | PASS | Held D+S (face SE), tapped J (`attack_light`'s bound key): `window.__SHINOBI_STATE__.player_weapon_visible` went true. Held D only (face E), tapped J again: weapon never appeared. 0 console errors either run. |

## Issues encountered
The cardinal-direction validity gate (`_check_cardinals()` in `sprite_set.gd`) is duplicated in a
SEPARATE Python CI validator (`scripts/ci/validate_sprite_manifests.py`) that re-implements the same
check independently -- both needed the identical opt-out flag, or CI would have failed even though the
GDScript side was already fixed. Also found (and fixed before committing, via `git diff` re-review)
two self-inflicted duplicate-line mistakes while editing `player_visual.gd`'s `_apply()`/`play_action()`
blocks -- same recurring multi-line-edit hazard noted in prior reports.

No remaining known issues. No regressions in the 1337 pre-existing automated tests.

## Questions for project owner
None for this specific wiring. Open item carried from Codex's original order (unchanged by this
work): final selectable double-backward-flicker binding decision, and owner approval to expand the
kunai art to the other 7 directions, both still pending.

## Outstanding work / next steps
- Push, open/merge the PR through required CI checks, verify live deployment, record deployed commit SHA.
- Once the owner approves the SE proof for full production, Codex's 8-direction pass can reuse this
  exact wiring (WeaponRig/manifest entries/gating) by simply adding the other 7 directions' frames and
  removing `allow_partial_directions` for these 4 ids.
