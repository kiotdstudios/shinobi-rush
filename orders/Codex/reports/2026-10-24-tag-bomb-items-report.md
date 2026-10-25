# Job Report — Animated tag bomb items
- Agent: Codex
- Order: orders/Codex/2026-10-24-tag-bomb-items.md
- Date: 2026-10-24 (America/New_York)
- Final status: REVIEW — local acceptance passed; PR integration and canonical live verification pending
- Commit / PR: pending implementation commit

## Work completed
Created two PixelLab sphere item packs matching the owner concept. Explosive: ivory paper, black decorative ink, red seams. Smoke: charcoal black paper, neutral white/gray ink, red seams. 48 native 128px frames per bomb (16 idle / flight / armed) plus 16 separate 256px smoke burst/billow frames. All 112 are unique RGBA, hard alpha, uncut transparent margins. Black-shell palette correction neutralizes cool gray at native pixel positions; source originals and API receipts retained. Reused approved separate pickup aura/embers and explosive blast rather than repainting them.

Both items are obtainable from builder-placed pickups, share gourd collection/absorption/respawn/stack cap, appear in Inventory, can be assigned to D-pad slots, and are actually consumed/thrown through the player's existing release event. Existing defaults/old paper tags are preserved. New counts start at zero. Explosive reuses existing flight/fuse/45-damage blast. Smoke has five independently staggered/direction-varied billows, rising drift and fade; no damage, hitstop or scorch. Smoke is a visual screen; enemy stealth/line-of-sight response remains Aki-owned and is not implemented.

Added `?bombs=review` isolated real-pickup/inventory/projectile preview with clock, normal/half speed and pause. Removed normal HUD only in review to keep its controls clear.

## Files changed
- assets/pickups/{tag_bomb,smoke_tag_bomb}: frames, source, manifests/imports.
- scripts/art/{tag_bomb_art,tag_bombs_review,kunai_proof_gate}.gd and review scene.
- scripts/pickups/{health_gourd,gourd_pickup_fx}.gd: new pickup kinds sharing existing effects.
- scripts/player/{inventory,player_controller}.gd: small explicit item registration and throw dispatch; no movement/combat redesign.
- scripts/combat/paper_tag_bomb.gd: optional body-art selection, original behavior unchanged; smoke_tag_bomb.gd: inherited ballistics, harmless cloud detonation.
- scripts/editor/placed_objects.gd: two Pickups entries; scripts/ui/player_menu.gd: entries/compact spacing for seven rows.
- tests: new real-item integration tests, runner registration and dynamic empty-row lookup in inventory test.
- docs/visuals/tag-bombs: source receipts, QC, contact sheets, integration notes, reproducible export/browser proof and screenshots.

## Tests run before commit
Godot 4.7.2 stable; bundled Python/Node; Windows; Chromium Web debug export.

| Test / command | Result | Evidence |
| --- | --- | --- |
| `python docs/visuals/tag-bombs/export_pack.py`; native pixel QC | 112 unique frames, exact 128/256px RGBA, alpha 0/255, no edge clipping; black-shell blue pixels zero | pixel-qc.json, contact sheets |
| `python scripts/ci/validate_orders.py` | passed | build/tag-orders.txt |
| `python scripts/ci/godot_ci.py import --project . --godot <4.7.2> --log-dir build/tag-import-final` | passed | build/tag-import-final.txt |
| `python scripts/ci/godot_ci.py tests --project . --godot <4.7.2> --log-dir build/tag-tests-final` | 2794 passed / 0 failed | build/tag-tests-final.txt |
| `<godot> --headless --path . --script res://build/tag_focus.gd` after adding six builder move/remove assertions | 163 passed / 0 failed | build/tag-focus-final.log |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <4.7.2> --log-dir build/tag-validate-final` | all scripts/scenes load, zero failures | build/tag-validate-final.txt |
| `python scripts/ci/godot_ci.py export --project . --out ../tag-bombs-web-review-20261024 --godot <4.7.2> --log-dir build/tag-web-review` | debug Web export passed | build/tag-web-review.txt |
| `node docs/visuals/tag-bombs/browser-proof.mjs ../tag-bombs-web-review-20261024 docs/visuals/tag-bombs/local-browser` | 12 passed; pickup, both controller-dispatched throws, landing/fuse, detonation, harmless smoke cleanup, normal/half/pause, zero console errors | local-browser/validation.json and inspected screenshots |
| `git diff --check` | passed after EOF cleanup | command output |

## Issues encountered
Initial review normal HUD covered title/buttons; fixed and reran final Web proof. PixelLab smoke-shell cool-gray tint corrected; originals retained. Focused standalone harness logs ObjectDB cleanup warnings; full CI wrapper tests passed with no unexpected engine errors. Expected bad-sheet fixture warning remains in full tests. Decorative calligraphy is not a verified translation. New smoke does not change AI detection.

## Questions for project owner
None.

## Outstanding work / next steps
Normal reviewed PR checks, merge, main deploy/postdeploy and exact-SHA canonical smoke test. Until those complete this is NOT LIVE. Aki can add actual smoke stealth/line-of-sight behavior separately using the existing smoke projectile duration/position.
