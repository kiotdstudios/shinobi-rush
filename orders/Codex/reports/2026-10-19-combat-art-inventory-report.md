# Job Report — Combat inventory and pre-generation handoff
- Agent: Codex
- Order: orders/Codex/2026-10-19-combat-art-pack-v1.md
- Date: 2026-10-19
- Final status: IN_PROGRESS (inventory complete; pack not generated)
- Commit / PR: Pending

## Work completed
Audited main ce81f6d, all asset paths and the only asset animation manifest, player_128.manifest.json. Inspected the approved turnaround. Existing frames are unarmed and do not substitute for katana combat.

| Existing ID | Directions | Timeline frames per direction | Unique PNG files | FPS |
| --- | --- | --- | --- | --- |
| idle | all eight | 16 | 120 | 12 |
| walk | all eight | 16 | 128 | 12 |
| run | all eight | 20 | 160 | 12 |
| sprint | all eight | 20, NW 11 | 151 | 12 |
| jump | all eight | 24 | 192 | 12 |
| dodge | all eight | 12 | 96 | 12 |

847 PNGs; 855 timeline references. Idle SW intentionally holds each of eight poses for two ticks. Directions are S, SE, E, NE, N, NW, W, SW. Native 128×128 RGBA; foot anchor [64,116]; standing body target 104px. Authored FPS24, owner-approved locomotion playback12. No existing combat clips or combat VFX found. Existing dirt-puff art is movement VFX, not a sword impact substitute.

## Aki handoff — proposed names and contract
First delivery: `light_attack_1` (diagonal opening), `light_attack_2` (continuous reverse slash), `light_attack_3` (committed finisher), `dash_attack` (low forward slash). Missing follow-up: `block_idle`, `perfect_parry`, `hit_reaction`, `guard_break`, `finisher`, `death`.

Paths follow `sprites/production/<animation>/<DIR>_NNN.png`, zero-based indices. All eight directions required. Independent effects proposed: `sword_trail_light`, `sword_trail_heavy`, `hit_spark`, `perfect_parry_spark`, `guard_break_burst`, `impact_flash_small`, `enemy_hit`.

No combat state machine, attack configuration, event timing, or active combat PR was found on this snapshot. Aki: please provide branch/config path, accepted IDs, total durations, startup/active/recovery times, combo/cancel windows, hit-stop, dash root-motion ownership, and whether the sword is supplied by a separate equipment layer. Confirm whether event indices should be zero-based as proposed. Animation FPS must map to those timings; do not apply locomotion's half-speed preference automatically to combat.

Final metadata will record direction, count, FPS, anchor, contact frames, recommended active frames, transition-ready frames and optional cancel windows after pose review and coordination. No speculative event indices are presented as gameplay-approved. Combo1 end pose must seed combo2, then combo3, avoiding neutral resets. Gameplay owns root movement and hitboxes; effects trigger separately.

## Files changed
New Codex order and this report only. Proposed schema additions are not yet applied to the runtime manifest.

## Tests performed BEFORE commit
- Python/Pillow audit loaded every referenced unique PNG: all847 exist, RGBA128×128, alpha only0/255; passed.
- Enumerated all assets and manifest paths; searched scripts and Aki orders for combo/attack/parry/hitbox definitions: no combat implementation found.
- Read latest main and open PR list; no combat PR located.
- Order validator passed; git diff --check passed before commit.

## Issues encountered
Current main's source-only validate_delivery.py still hardcodes559 rather than847; correction is already in separate PR24. Do not mix that unrelated pending change into this pack. No accessible Aki app thread was found; publish the handoff through this PR and Aki's existing GitHub conversation.

## Questions for project owner
None. Katana authorization is explicit in the new order.

## Outstanding work / next steps
Deliver inventory to Aki before generation; coordinate timings; build and inspect offensive clips, independent VFX, previews, Godot imports, then submit assets for review. Remaining six clips in a follow-up PR. Live deployment: not applicable to this documentation-only checkpoint; no runtime assets changed.

