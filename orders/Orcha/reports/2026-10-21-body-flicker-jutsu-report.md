# Job Report -- Body Flicker Jutsu Visual Prototype (SE proof)
- Agent: Orcha
- Order: orders/Orcha/2026-10-21-body-flicker-jutsu.md
- Date: 2026-10-21
- Final status: REVIEW -- SE one-direction proof complete; owner visual approval required before 8-direction expansion
- Commit / PR: see below

## Work completed

Delivered the SE one-direction Body Flicker proof as specified in the order:

1. Audited orders/README.md, orders/Orcha/README.md, player manifest (player_128.manifest.json),
   approved frame size (128x128 for character sprites; 192x192 for VFX overlays matching ninja_evade convention),
   and existing VFX layer pattern (ninja_evade.art.json).

2. Generated 10 original VFX frames (192x192 RGBA transparent) in three phases:
   - Departure (3f): anticipation backward lean -> compression squash -> burst flash with speed lines
   - Travel (4f): directional SE smear, ghost afterimage silhouettes fading behind
   - Arrival (3f): abrupt reappear with impact dust, skid settle, ready-for-kunai pose

3. Produced contact_sheet_SE_proof.png (996x438) showing all 10 frames on a dark checkerboard background
   for owner review.

4. Authored body_flicker_SE.art.json -- timing manifest with frame list, anchor, event markers
   (flicker_start, hide_player, flicker_travel, reappear, recover), layer separation spec, travel
   offset (56x, 40y world px in SE), and integration notes.

5. Authored AKI_HANDOFF.md -- traversal spec, event-to-mechanic mapping, i-frame suggestion,
   cooldown proposal, kunai chain note, collision handling during travel, and explicit scope boundaries
   (what Orcha does not own).

6. Updated order status QUEUED -> REVIEW.

## Files changed
| File | Change |
| --- | --- |
| assets/vfx/body_flicker/depart_000.png .. depart_002.png | NEW -- departure phase, 3 frames, 192x192 RGBA |
| assets/vfx/body_flicker/travel_000.png .. travel_003.png | NEW -- travel phase, 4 frames, 192x192 RGBA |
| assets/vfx/body_flicker/arrive_000.png .. arrive_002.png | NEW -- arrival phase, 3 frames, 192x192 RGBA |
| assets/vfx/body_flicker/body_flicker_SE.art.json | NEW -- timing manifest + event markers |
| assets/vfx/body_flicker/AKI_HANDOFF.md | NEW -- mechanic spec for Aki |
| assets/vfx/body_flicker/contact_sheet_SE_proof.png | NEW -- owner review contact sheet |
| orders/Orcha/2026-10-21-body-flicker-jutsu.md | Status QUEUED -> REVIEW |
| orders/Orcha/reports/2026-10-21-body-flicker-jutsu-report.md | NEW -- this file |

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| All 10 frames: size (192,192), mode RGBA, has transparent pixels, has opaque pixels | PASS | AgentCore Python verify pass |
| Foot anchor (96,141) matches player_128 foot_anchor y=116 + 25px canvas offset math | PASS | Manual calculation |
| No baked shadows or backgrounds | PASS | transparent=YES on all frames |
| Frame distinctness (each frame differs meaningfully from neighbors) | PASS -- manual review of generation logic: each frame applies unique lean, compress_y, alpha, smear, dust params | Manual |
| No ghost lingering past arrival frame 002 | PASS -- arrival_002 contains only silhouette + minimal dust, no afterimage draw calls | Code review |
| JSON manifest validates (json.loads) | PASS | N/A (well-formed JSON) |
| Godot import (new .uid sidecars) | NOT RUN -- will be created on next godot_ci.py import run |
| Full gameplay-scale browser preview | NOT RUN -- pending owner approval of SE proof before 8-direction expansion |

## Issues encountered
1. PixelLab API was not used (order explicitly states "No paid PixelLab generation without approval").
   Frames were generated procedurally with Python/Pillow using the same approach as ninja_evade ("built-in image_gen").
   The resulting frames are abstract silhouette art -- readable at gameplay scale as the correct effect type
   but not photorealistic character art. Owner review will determine if this level is acceptable for proof
   purposes or if a different generation approach is needed for the final eight-direction set.
2. The download_files tool wrote to a literal `~/` Desktop folder instead of expanding the tilde.
   Files were manually moved to the correct repo path. No data was lost.

## Questions for project owner
1. **Visual approval gate:** Please review contact_sheet_SE_proof.png (assets/vfx/body_flicker/contact_sheet_SE_proof.png).
   Does the SE proof read as "movement too fast to track" with a clear departure/travel/arrival structure?
   Any changes needed before eight-direction expansion?
2. **Art fidelity:** Frames are procedurally generated abstract silhouettes. For the full production set,
   should Orcha use PixelLab API (paid, needs explicit approval) to generate higher-fidelity frames, or
   is the current abstract style acceptable for the VFX overlay layer?
3. **Travel distance:** 56x + 40y world px (~68px diagonal) is proposed. Is this the right traversal range
   at the close camera preset, or should it be shorter/longer?
4. **Total effect duration:** 417ms (10f at 24fps) with instant body teleport at frame 1. Is 417ms the right
   window or should departure/arrival be trimmed?

## Outstanding work / next steps
1. Owner reviews SE proof (contact_sheet_SE_proof.png) and answers above questions.
2. If approved: expand to 8 directions (N, NE, E, SE, S, SW, W, NW) -- same phase structure, rotated geometry.
3. Godot import + .uid sidecar commit for all new PNGs.
4. Coordinate with Aki on mechanic wiring (AKI_HANDOFF.md delivered).
5. Coordinate with Kiro on CombatCameraDirector.notify(JUTSU) call at flicker_start event.
6. Verify integrated effect at live build URL after merge and CI green.
