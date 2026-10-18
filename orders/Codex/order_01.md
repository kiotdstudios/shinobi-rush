# ORDER 01 — Build the Baseline Playable Shinobi (Art)

- **Agent:** Codex
- **Status:** QUEUED — start immediately when read; no further prompt required
- **Priority:** P0
- **Owner:** Codex (art)
- **Dependencies:** Approved visual reference exists in GitHub. Coordinate with gameplay agents on animation import and live integration; do not overwrite their code.
- **Branch/PR:** Create a dedicated art branch/PR and link it in the report.

## Objective
Produce the first **game-ready, animated player character** for Shinobi Rush based on the approved three-view reference, ready to integrate and test in the Godot 4 2D faux-isometric browser-playable prototype. This is the **first executable Codex art order**, not merely a design suggestion.

## Authoritative references
1. **Approved player turnaround PNG:** `assets/characters/player/references/baseline_turnaround.png` — OPEN AND INSPECT THE ACTUAL IMAGE before generating any art.
2. [Locked baseline character spec](../../docs/prototype/BASELINE_PLAYER_CHARACTER.md).
3. [Player implementation / controller handoff](../../docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md).
4. [Master agent rules](../README.md) and [Codex art rules](./README.md).

If older concept art or docs disagree, the approved PNG and latest locked decisions win.

## Required visual identity
- Original young Black male shinobi, athletic build, tied-back dreadlocks, visible face.
- Match the turnaround's armor, sleeveless clothing, wraps, gloves, trousers, sandals, silhouette, and palette.
- **No mask, cape, sword, scabbard, or sword strap.** No generic substitute passed off as approved art.
- Maintain consistent proportions, hair silhouette, outfit details, palette, and feet anchor across every frame/direction.

## Required first-pass animation deliverables
Create original, clean, production-organized directional 2D assets suited to the game's faux-isometric perspective:
1. Idle loop.
2. Normal locomotion (walk/run).
3. **Ninja sprint** (R1): Naruto-inspired recognizable forward-leaning torso, both arms swept back, fast leg cycle. **This is distinct from normal running.** Original frames only; do not trace or rip Naruto animation.
4. Jump takeoff / air / landing.
5. Directional dodge with readable evasive pose and optional afterimage-ready silhouette.
6. Light and heavy melee attack poses/combos; **no sword**.
7. Hit reaction and recovery.

Provide N/S/E/W directions at minimum, or coordinate any directional mirroring/8-way requirements with the gameplay owner before committing. Keep transparent backgrounds where appropriate, consistent sprite canvas dimensions and origins, clean animation names, usable import settings, and a frame/animation manifest. The older 6–8 sprint-frame suggestion is superseded by the locked high-detail animation specification below. Prioritize visual readability at gameplay zoom.

## Scope and coordination
- **Codex owns art assets**, animation authoring, sprite sheets, source files (if available), and animation manifests.
- Gameplay/controller integration belongs to the assigned gameplay agent unless explicitly coordinated. Do not overwrite another agent's scene/controller changes.
- Place outputs under `assets/characters/player/` in clear `sprites/`, `animations/`, and/or `source/` subfolders; preserve `references/baseline_turnaround.png`.
- Supply an integration note detailing frame sizes, animation IDs, FPS, origin/foot anchor, collision recommendations, directional mapping, and transitions.
- If the approved reference is too detailed for the prototype's sprite scale, preserve identifying silhouettes and propose a faithful simplified treatment; flag any major visual departure for owner review.

## Mandatory tests — BEFORE commit
- Open generated sheets/images to inspect character fidelity and frame-to-frame consistency.
- Verify transparent backgrounds, export sizes, alignment, frame order, no clipping, and clean loop playback.
- Preview every direction and state in Godot (or an equivalent local sprite animation preview if the integration scene is not yet available).
- Test the distinct normal run vs. arms-back R1 sprint; verify transitions do not jump, flicker, or shift foot/collision anchors.
- If integrated into the gameplay prototype, launch and test the Godot Web export in a browser and check runtime errors.
- Record **actual** test steps, results, and limitations. Fix failures and retest before implementation commit. Never claim unperformed tests passed.

## Commit, live testing, and completion
1. Start immediately upon reading this queued order and update status to `IN_PROGRESS`.
2. Implement and **test first**.
3. Write the job report with pre-commit test evidence at `orders/Codex/reports/YYYY-MM-DD-order_01-character-creation-report.md`.
4. Commit and push tested assets on the dedicated branch, then integrate through the repository's approved review/PR process.
5. **Do not wait for a separate instruction to update the live browser test game.** Coordinate asset integration with the gameplay owner; publish the updated build using the actual configured deployment pipeline and open the live game to smoke-test the result. If deployment access or integration is missing, mark `BLOCKED` and report exactly what is needed.
6. Update the report with commit SHA, PR link, live URL/build ID and smoke-test evidence. Mark `DONE` only when tests, integration, applicable deployment, and report are complete.

## Acceptance criteria
- [ ] Character faithfully matches the **approved PNG**; no mask, cape, or sword.
- [ ] All first-pass animation states exist and are usable in Godot.
- [ ] R1 sprint clearly has forward lean + both arms back; normal running is separate.
- [ ] Directional animations and transitions are visually coherent.
- [ ] Sprite sheets, frame manifest, and integration notes are committed.
- [ ] Relevant tests and visual previews passed **before committing**.
- [ ] Live browser build is updated and verified, or a specific blocker is documented.
- [ ] Detailed job report includes work done, test evidence, issues, questions, and next steps.

## Questions and blockers
Write questions in the report; if something is not specified, use a reversible prototype default and label it as provisional rather than silently locking new design decisions.


## Mandatory camera interpretation (read before drawing)
**The gameplay camera is fixed-angle 2D three-quarter overhead / faux-isometric**, looking diagonally downward. Read [authoritative camera and art direction](../../docs/visuals/CAMERA_AND_ART_DIRECTION.md) and [three-quarter art skill](../../skills/three-quarter-game-art/SKILL.md). The approved front/side/back turnaround is an **appearance reference, not the gameplay viewing angle**. Translate the design into elevated three-quarter directional gameplay sprites with visible top planes, consistent feet anchors, correct prop overlap, and N/S/E/W plus planned diagonals. **Do not create side-view platformer sprites or pure orthographic turnaround frames as final gameplay assets.** Exact numeric camera elevation, tile diamond ratio, and pixel resolution are still prototype-tunable; coordinate and test a representative in-engine frame before producing full batches.


## LOCKED — High-detail character production and fluid animation
- **Standard player animation canvas:** **128×128 px RGBA**, transparent, with approximately **100–112 px standing character height** and a fixed ground/feet anchor. Larger 192×192 or 256×256 overflow canvases are allowed for wide attacks and motion, without scaling the character. Keep proportions and visual density consistent across NPCs, equippables and effects.
- **Camera:** elevated three-quarter overhead faux-isometric. The flat turnaround is an *appearance* reference, not the gameplay angle.
- **Direction coverage:** eight unique directions (N, NE, E, SE, S, SW, W, NW) as the production goal; check asymmetrical hair/armor and avoid incorrect mirroring. Review one south-facing and one diagonal gameplay-scale sample before batching all directions.
- **Animation baseline:** author at **24 animation frames per second** with purposeful spacing, anticipation, follow-through, impact timing and secondary motion (hair, wraps, clothing). The game can render at 60+ fps independently. **More frames alone do not ensure smooth motion**; do not pad with duplicate/warped frames or introduce input lag.
- **Per-direction frame targets (quality targets, not compulsory filler):** idle 12–16; walk 12–16; normal run 16–20; R1 arms-back ninja sprint 20–24; dodge 12–18; jump 16–24 across takeoff/air/landing; light melee 12–20 per strike; heavy melee 18–28 per strike; hit/recovery 10–16. Preserve responsive hit and dodge timing.
- **Equippables:** layered armor/clothing/weapon accessories with consistent named attachment sockets (head, torso, back, hands, waist, feet), directional occlusion and no sliding; include an attachment overlay demonstration. **No sword on the approved baseline player.**
- **VFX:** detailed separate directional flipbooks/particles for sprint dust, dodge afterimages, impact flashes, attack arcs, substitution, speed trails, hit sparks and grounded shadows. Respect camera projection, keep gameplay silhouettes readable and profile Godot Web texture/memory/performance.
- **Acceptance:** inspect alpha, edge artifacts, frame-to-frame continuity, foot anchors, equipment drift, direction changes, clipping and actual in-game zoom. Deliver frame/FPS/direction manifest and visual previews. The frame standard is locked for this order; numeric camera angle and zoom remain subject to in-engine approval.
