# ORDER — Premium Combat Animation Pack V1 (Reference-Driven)

- **Agent:** Codex
- **Status:** REVIEW — Phase1 SE layered art proof delivered; owner look/feel review before8-direction expansion. Later phases remain outstanding.
- **Priority:** P0
- **Owner:** Codex — production art and animation
- **Branch/PR:** `codex/premium-combat-poc` / https://github.com/kiotdstudios/shinobi-rush/pull/42
- **Dependencies:** Approved baseline player art and existing player_128 animation manifest; coordinate frame events with Aki's Combat Fluidity Overhaul V1. **Do not interrupt or duplicate Codex's already ongoing Chidori work**; start this after its current committed deliverable or report a resource conflict.

## Objective
Deliver production-quality, responsive, faux-isometric combat art that makes Shinobi Rush feel like the owner's supplied pixel-art combat reference: fast movement into slashes, striking extreme poses, bright readable hit silhouettes, layered arcs/sparks, sharp enemy reactions, and seamless attack-to-attack visual continuity. The reference recording is 53.4 seconds at 720×480/30fps; early frames 0–6 seconds show rapid enemy approach, white impact silhouettes, circular sword arcs and yellow sparks. **Do not treat recorded video frames as known source animation keys or claim exact original gameplay timings.**

## Authoritative references
1. Read `orders/README.md`, `orders/Codex/README.md`, `skills/three-quarter-game-art/SKILL.md`, `docs/visuals/CAMERA_AND_ART_DIRECTION.md`, `docs/vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md`.
2. Open `assets/characters/player/references/baseline_turnaround.png` and `assets/characters/player/player_128.manifest.json`; inspect real existing sprites before planning new frames.
3. Coordinate with Aki's order `orders/Aki/2026-10-20-combat-fluidity-overhaul-v1.md` when merged, and use the gameplay event/timing interface Aki confirms.
4. User reference: https://www.reddit.com/r/PixelArt/comments/hl5i86/combat_pixel_animation_for_indie_game/ ; the user-provided MP4 is the ground truth for the visual study if accessible locally. If not, state limitation and work from documented observations only.

## Locked art constraints
- Standard character frame **128×128 transparent RGBA**, approved body scale, fixed feet anchor from actual manifest, original ninja identity and eight-direction target; use a larger *separate* transparent VFX canvas only when necessary.
- Approved player has visible face, tied-back dreadlocks, no mask/cape/baked sword or strap. Weapon appearance should be a separate attachment layer when viable. Existing baseline and owner revisions override stale earlier instructions.
- Preserve pixel clusters, nearest-neighbor edges, palette consistency, shadow/ground anchor and the elevated three-quarter faux-isometric perspective. No generative blur, image interpolation, inconsistent character redesign or baked-in floor shadows.
- Do not regenerate the existing ~847 locomotion frames. Audit/reuse existing approved frames and socket conventions.
- PixelLab is optional: review existing API pipeline and costs/credentials before using it; **no paid generation without owner authorization**.

## Phase 1 — Art audit and single-direction proof of concept (first deliverable)
1. Audit existing combat frames and source files. Identify missing player attack states, usable directional frames, weapon sockets and VFX layers. Document what already exists; avoid duplicates.
2. Create a pose/timing storyboard for **one approved gameplay direction**: run→light attack 1→light attack 2→light attack 3→dodge/reposition→dash attack. Distinguish startup, impact extreme, smear, overshoot and recovery. Prioritize **strong readable poses over unnecessary smooth in-betweens**.
3. Produce **one-direction playable-ready prototype** with separate body/weapon/VFX layers where practical. Use existing weaponless body poses with a separately attached practice sword/katana as needed; do not change locked player identity. For each action supply startup/active/recovery frames and visual contact markers. Author purposeful 24fps baseline with variable frame holds; do not equate physics ticks with animation frames.
4. Deliver nearest-neighbor contact sheet, animated preview at 1× and actual approved close-camera zoom, original transparent frame PNGs, manifest/socket/anchor data and visual QA report. Request owner approval of the look/feel before eight-direction expansion.

## Phase 2 — Offensive combat art
- Three distinctive light slashes with different silhouettes, directions of force and follow-through; dash attack with aggressive lean/forward displacement.
- Separate bright weapon arcs, impact flash silhouettes, contact sparks, directional slash trails, dust and optional afterimage; no oversized VFX that obscures player/enemy readability.
- Distinguish combo transition poses from forced idle loops. Support Aki's attack events `attack_start`, `hit_active`, `hit_contact`, `cancel_open`, `recovery`, and weapon-hand socket transforms or coordinate exact names.
- Heavy/finisher attack visual pass only after core light combo is approved.

## Phase 3 — Defense, aerial and hit reaction art
- Dodge anticipation/extreme/exit, parry deflect contact spark, block recoil, posture/guard-break stagger, directional hurt/hitstun, airborne slash and landing recovery.
- Preserve locomotion-to-action and action-to-action continuity; no abrupt scale jumps, inconsistent facing, or accidental frozen legs during mobile attacks.
- Keep Lightning Clone substitution art assigned to Orcha, Chidori art assigned to Codex's existing Chidori task; do not conflate those effects with this pack.

## Phase 4 — Rogue Ninja Bandit art (after player combat proof is approved)
- Create an **original** masked rogue-ninja enemy influenced by anime ninja design, not a traced/copyright-copied franchise character. Owner requested front/side/back turnaround; use that approved concept if available in project, otherwise obtain reference/approval before final production.
- First pass: three-view turnaround, one-direction 128×128 idle, approach/run, telegraphed melee strike, hit reaction, stagger, block and defeat. Distinct silhouette/palette from player; enemy hit telegraph must be readable.
- After approval, plan other directions. Aki owns enemy AI, collision, damage, and state integration.

## Acceptance criteria / visual tests
1. Run→combo 1→2→3→dodge→dash attack previews without involuntary idle or mismatched body/weapon anchors (where gameplay transitions permit).
2. Each attack has an immediately readable silhouette at gameplay zoom and a clear moment of contact; the third hit feels stronger without artificially adding sluggishness.
3. Separate VFX line up with attack collision/contact and do not hide the hit target.
4. Sprite files are genuine transparent 128×128 RGBA character frames, stable proportions/palette/feet and valid imports; any larger VFX canvas is separately documented.
5. At least one visual preview and contact sheet for each milestone; verify in Godot where possible and hand Aki animation names, event markers, durations, directional mapping, anchor/socket data and cancel transition recommendations.
6. Run actual asset validation and applicable Godot/Web smoke tests before commits. Report exact commands, observed results, regressions and unresolved issues. Do not claim live build verified unless actually opened and tested.

## Deliverables and workflow
- **A:** existing-art audit + one-direction combo proof with source PNGs, contact sheet, preview, timing/event manifest, owner review.
- **B:** approved offensive animation/VFX pack + Aki integration handoff.
- **C:** defense/aerial/hit reaction pack.
- **D:** approved Rogue Ninja Bandit turnaround and first-direction animation test.
- For each job follow repository branch/PR, pre-commit testing, required report `orders/Codex/reports/YYYY-MM-DD-task-report.md`, integration/deployment and verified live browser smoke-test requirements. Do not mark DONE without evidence.

## Coordination / exclusions
**Codex:** combat sprite art, weapon attachments, slash/VFX art, Rogue Ninja Bandit art; existing Chidori work remains independent.
**Aki:** combat timing, state machine, input buffering, hitboxes, enemy AI and runtime integration.
**Orcha:** Lightning Clone Substitution prototype.
**Kiro:** no work assigned.
No unapproved gameplay refactor, camera changes, mass map production, paid API usage, or unauthorized modification of other agents' work.

## Phase1 delivery — 2026-10-20

- SE run→light1→light2→light3→dodge→dash proof,58 timed poses, two separately attached swords, independent trails/sparks. Existing weaponless art reused; dash explicitly a hybrid pose study, not dedicated new production art.
- Source/metadata: `assets/characters/player/premium_combat_poc/premium_combat.art.json`; Aki handoff beside it in `INTEGRATION_NOTES.md`.
- Preview: `assets/characters/player/previews/premium-combat-poc/index.html`; normal/half/close-half GIFs and contact sheet beside it.
- Tests: Python file/hash/alpha/socket/timing validation,116 sword composites; Godot4.7.2 import and texture fixture; Chromium desktop1280×900/mobile390×844 controls, contact markers, layers, native/close, reload; no missing assets or JS errors. See `orders/Codex/reports/2026-10-20-premium-combat-se-proof-report.md`.
- Runtime event/tuning agreement remains Aki's integration task. Live deployment not applicable to opt-in art proof. No controller/camera edits, new generation, or847-frame conversion.
