# SHINOBI RUSH — Playable Character & Browser Prototype Handoff
Status: Implementation brief V1 — gameplay architecture approved; art details requiring reference are explicitly provisional.
Target: Codex implementing Godot 4.x prototype, browser-playable Web export, Windows-ready project.
Priority: Deliver a **playable character test**, not a polished world, RPG, or final animation pack.

## 1. Source of truth and conflict resolution
Read `world/maps/MVP_WORLD_MAP.md` and `docs/visuals/combat-skill-tree/README.md` for latest locked rules. `docs/GAME_DESIGN_DOCUMENT.md` includes historical superseded roguelite and controller proposals: DO NOT implement its obsolete seven-room mission, L2 guard, R2 standalone attack, or older face-button layout.
The user has confirmed **Godot 4**, **DualSense-first**, **browser-based playtesting**, **faux-isometric 2D**, **no traditional blocking**, **three independently recharging L2 Substitution charges**, and **loadout-dependent finishers**.

## 2. Character identity and visual direction
- Player: one original **Black male shinobi** from the Shinobi Rush setting, athletic and agile, readable silhouette; not a copyrighted anime character.
- Reference look: follow the user's **previously approved male ninja reference**, if it exists as an accessible repository asset. **Do not invent exact mask, hairstyle, insignia, color arrangement, or weapon** from memory. If no source art is accessible, build a clearly labeled temporary silhouette with a distinct head, torso, arms, legs, facing, and floor shadow; request the approved reference before final character sprite production.
- The user previously requested front, side, and back A-pose reference views without a sword/strap for a character concept. This is a **reference preference**, not permission to assume the playable character has no weapon in every gameplay pose.
- Visual style: high-definition crisp pixel art, original character design, 128×128 RGBA frame canvas (locked; see [FINAL OWNER DECISION](../../orders/README.md)); standing height about 100–112 px on that canvas. World tile scale is provisional, set against the 128×128 / 100–112 px character in the in-engine test arena, subject to owner approval. Transparent background, consistent foot pivot and proportions across frames.
- Orientation: four-direction animation sets (N, S, E, W); mirror E/W temporarily if needed, with eventual hand/gear asymmetry handled intentionally. Faux-isometric world art, but collision and navigation use conventional 2D planar coordinates.
- Always draw a small elliptical ground shadow under feet. Aerial jump changes **visual sprite elevation**, not collision-plane position; show height by separating sprite from shadow. Keep gameplay readability above decorative detail.
- Temporary VFX: short white/blue chakra trail for dodge, translucent character-shaped afterimage on Perfect Dodge, original substitution smoke burst. Do not copy third-party game sprites or effects.

## 3. Controller-first mapping (LOCKED)
| Input | Action |
|---|---|
| Left stick | Move (analog 360-degree) |
| Right stick | Aim/facing (when applicable) |
| Square | Light attack |
| Triangle | Heavy attack |
| Circle | Dodge / Perfect Dodge |
| Cross | Jump; assisted aerial pursuit after an eligible launcher |
| R1 | Sprint |
| L1 | Heal (stub in initial arena; do not repurpose) |
| L2 | Substitution, 3 independently recharging charges |
| R2 + Square/Triangle/Circle/Cross | Four equipped jutsu slots (initially stubs) |
| R3 | Optional target lock-on (stub if no enemy) |
| Options | Pause |

Use Godot InputMap actions, not hard-coded gamepad IDs. Provide keyboard fallback with an in-game legend (suggested: WASD move, arrows aim, J light, K heavy, Space dodge, Shift sprint, F jump, Q substitution, E heal, 1–4 jutsu modifier shortcuts; allow remapping). Verify that R2+face inputs **never accidentally fire** a normal melee attack.

## 4. Character gameplay states
Build a small finite-state machine or clearly organized equivalent:
`IDLE`, `MOVE`, `SPRINT`, `LIGHT_ATTACK`, `HEAVY_ATTACK`, `DODGE`, `JUMP`, `AIR_ATTACK`, `JUTSU`, `HITSTUN`, `DEFEATED`, `SUBSTITUTION`.
Expose attack phase (startup / active / recovery) and buffered inputs. Prevent incompatible state overlap. Dodge, jutsu cancels, and aerial pursuit must obey explicit allowed transition windows.

## 5. Movement prototype
- `CharacterBody2D`, `CollisionShape2D`, sprite/animation child, `Camera2D`. Use normalized analog input to avoid diagonal speed boost.
- Tunable starting **prototype-only** values (not locked balance): walk 175 px/s, sprint 270 px/s, acceleration 1400 px/s², friction 1800 px/s²; dodge travel 105 px over ~0.26 s, with brief invulnerability. All constants exported for easy iteration.
- Immediate responsive turning; facing follows attack aim or last movement vector. Avoid drift, sliding, and movement snapping.
- Jump uses a simulated height variable and shadow offset; prototype jump time ~0.55 s. Aerial pursuit is eligible **only when the target has actually been launched** and the player presses Cross within a short follow-up window. No auto-air-launch from ordinary light combos.
- Dodge on Circle uses movement direction, otherwise last facing direction; avoid infinite dodge spam via recovery. Standard dodge costs no Substitution charge.

## 6. Exact combo routes (LOCKED)
Two **equipped melee finisher slots**, independent of four jutsu slots:
- `Square → Square → Square`: 3-hit light chain ending in **equipped Light Finisher**.
- `Triangle → Triangle → Triangle`: 3-hit heavy chain ending in **equipped Heavy Finisher**.
- `Square → Square → Triangle`: light-to-heavy chain ending in **the identical equipped Heavy Finisher** used by T-T-T, not a third finisher.
- Finisher properties (grounded knockback, stagger, launch, etc.) depend on loadout; **not every light chain launches**.
- For first prototype: use a grounded light finisher and a launcher heavy finisher, plus an optional debug menu to swap the heavy finisher to a grounded slam. This demonstrates loadout-dependence without a full equipment UI.
- Distinct startup, active, recovery windows; attack queue/input buffering. Example initial tuning: 0.18 s combo input buffer, adjustable. Animation data drives hit timing.
- Allow **eligible** light/heavy moves to cancel into R2+equipped jutsu during authored cancel windows. Do not allow universal canceling, infinite hitstun, or zero-cost jutsu.
- Prototype jutsu may be simple clearly labeled placeholder effects with Chakra cost/cooldown; do not spend milestone time building the entire jutsu system.

## 7. Dodge and Perfect Dodge
- No traditional block, guard, or parry.
- Perfect Dodge triggers when Circle is pressed in a narrowly defined window around a **real incoming enemy hit**. It is not triggered by dodging into empty space.
- Wukong-inspired feel as an **original implementation**: near-miss, very brief cinematic slowdown, a translucent chakra-tinted shinobi afterimage left at the origin that dissipates quickly, distinctive sound/flash, rapid return to control.
- Initial **tunable placeholders**, not claims about Wukong's actual frame data: Perfect Dodge timing ±0.10 s relative to incoming impact; global time scale ~0.45 for ~0.10 s of real time; afterimage lifetime ~0.30 s; follow-up input accepted as soon as dodge recovery permits. Keep audio/UI usable during slowdown.
- Use an enemy training dummy that visibly telegraphs and swings to validate the mechanic. Perfect Dodge must not trigger on every ordinary dodge, or on distant/unthreatening swings.
- Future Evasion Mastery may unlock Counter Strike, Phantom Step, Shadow Counter; **do not implement or treat their costs as locked** in milestone one.

## 8. Substitution and defensive rules
- L2 is an emergency defensive escape, **not** a guard. Three starting charges, each with its **own recharge timer**.
- Successful activation consumes exactly one charge, negates the incoming hit and moves the player to a safe nearby location (behind or beside attacker if collision-safe), with smoke/afterimage feedback.
- Prototype only: recharge 8 seconds per charge, adjustable. Follow latest design rules for timing, charge failure behavior, and death resets; mark any unapproved behavior as provisional.
- Never teleport inside a wall or out of bounds. If safe destination unavailable, handle gracefully. Three diamond charge indicators can be temporary debug UI.

## 9. Test arena
Create one simple flat faux-isometric-looking training courtyard, with walls/obstacles, a stationary dummy, and one slow telegraphed attacking enemy. No full forest map or village required yet.
Show HP, Chakra, Substitution charges, current Light/Heavy finisher, input/state diagnostics, and a small button legend. Provide a toggle for hitboxes and a Perfect Dodge success counter.
Add debug buttons/keys for respawn, refill HP/Chakra, switch heavy finisher (launcher vs ground slam), and toggle dummy attacks.
Camera follows smoothly and respects arena bounds. No permanent progress system required yet.

## 10. Browser-based test workflow — crucial
Use **one Godot source project**, not a separately reimplemented JavaScript game.
- Godot 4 Web export (HTML5/WebAssembly) served over local HTTP, not `file://`. Produce `web/index.html` and supporting export files with a documented one-command launch script for local testing. Avoid dependencies on native extensions unsupported by Web export.
- Provide reproducible local commands to install/use matching Godot export templates, export Web, and serve with a local static HTTP server; document actual engine version used. Ensure any hosting requirements (e.g. cross-origin isolation for threaded Web exports) are satisfied or use a compatible single-thread Web export configuration.
- Browser keyboard fallback must work without controller. Gamepad support must be tested on Chrome/Edge; **DualSense support in browsers can vary** and must be validated on real hardware. The eventual Windows build is a separate export from the same project.
- Do not claim a publicly hosted playable URL until a deploy target is configured and actually tested. Localhost testing is sufficient for milestone one.
- Add a short `TESTING.md` checklist with screenshots/GIFs optional, and a browser console error checklist.

## 11. Suggested Godot architecture
```
project.godot
scenes/main.tscn
scenes/arena/training_arena.tscn
scenes/player/player.tscn
scenes/enemies/training_dummy.tscn
scripts/player/player_controller.gd
scripts/player/player_state_machine.gd
scripts/combat/combo_controller.gd
scripts/combat/hitbox.gd
scripts/combat/hurtbox.gd
scripts/combat/perfect_dodge.gd
scripts/combat/substitution.gd
scripts/enemies/training_dummy.gd
scripts/ui/debug_hud.gd
assets/characters/player/placeholder/
exports/web/ (generated, ignore large binaries unless repo policy says otherwise)
docs/prototype/TESTING.md
```
Use typed GDScript where practical, resource-driven move definitions, signal-based hit detection, and exported tuning parameters. Keep art and mechanics separable.

## 12. Implementation order and definition of done
1. **Foundation:** Godot project opens, main scene runs, camera/arena/character render, browser export launches.
2. **Movement:** analog/WASD move, sprint, facing, collisions, jump shadow/elevation, dodge. Smooth 60 FPS target on ordinary desktop browsers.
3. **Melee:** correct three input routes, distinct heavy/light finisher slots, debug loadout switch, visible hit feedback and dummy reactions.
4. **Defense:** telegraphed dummy attack, regular vs Perfect Dodge recognition, afterimage/slowdown, L2 substitution with three independent timers.
5. **Polish/testing:** input buffering, state-transition tests, hitbox visualization, browser/controller smoke tests, no console errors.

### Acceptance tests
- Player can move in 8 directions, sprint, jump, dodge without getting stuck or drifting.
- S-S-S uses Light Finisher; T-T-T and S-S-T call **the same equipped Heavy Finisher**.
- Changing Heavy Finisher to grounded slam changes both heavy routes, but not S-S-S.
- Ordinary light finisher does not automatically launch an enemy; launcher heavy finisher enables optional Cross pursuit.
- R2+face activates jutsu stub and does not register the corresponding unmodified attack.
- Perfect Dodge occurs only on correctly timed near-hit; visibly shows afterimage/brief slowdown and rapid control recovery.
- L2 uses three independent recharge windows and never teleports into obstacles.
- Browser build starts through local server with keyboard controls; controller test results are documented honestly.
- Project has a readable README, test checklist, and no untracked generated assets or unexplained errors.

## 13. Explicitly out of scope
Final portrait/sprite sheet without approved visual reference; village, procedural forest streaming, save/load, trainer, inventory, complete jutsu mastery, full skill tree UI, boss, Steam integration, polished animation set. Implement placeholders with clean replacement points.

## 14. Codex execution request
**Build this prototype in `kiotdstudios/shinobi-rush`.** First inspect repository structure and latest locked rules, then commit implementation in small logical commits. If the repository is docs-only, initialize the Godot project without overwriting design files. Deliver actual playable Web export instructions and a test report. Do not report completion until the project runs and acceptance tests are performed. Surface any unavailable dependencies or controller/browser limitations explicitly.


## 15. Naruto-style shinobi sprint animation — USER-APPROVED REQUIREMENT
- **Sprint (R1 + movement) must use a recognizable ninja-run silhouette:** torso leaning sharply forward, both arms extended/swept backward behind the hips, head looking toward the travel direction, quick compact leg cycles and dynamic foot contact.
- This is a **movement/animation reference only**. Create **original** character poses, sprite frames, proportions, and timing for the approved baseline Shinobi Rush character; do not trace, rip, or reuse Naruto animation assets.
- Keep **walk/run** and **ninja sprint** as distinct animation states: normal directional locomotion when moving without sprint; Naruto-inspired forward-leaning arms-back sprint only while sprint is active.
- Create directional variants consistent with the project's 2D faux-isometric presentation (N/S/E/W at minimum), with coherent shoulder/arm silhouette and no cape, mask, sword, or sword strap.
- Suggested starting sprite set: 6–8 looping frames per direction for sprint, plus anticipation and stop/transition poses if time permits. These are prototype production targets, not final timing locks.
- During ninja sprint, movement collision/hurtbox should stay stable and centered on the character's feet; visual lean must not cause clipping, jitter, or sudden collision shifts. Handle sprint-to-dodge, sprint-to-attack, and sprint-to-idle transitions cleanly.
- Add explicit acceptance test: hold R1 and move; character visibly switches from ordinary running to the forward-leaning, arms-back ninja sprint in every supported direction, then returns to normal movement when R1 is released.


## Approved baseline character image — VERIFIED IN REPOSITORY (2026-10-17)

**Authoritative visual reference:** [Approved three-view turnaround](../../assets/characters/player/references/baseline_turnaround.png)

Exact repository path: `assets/characters/player/references/baseline_turnaround.png`.

Codex: **open and inspect this image before producing final sprites**. The user explicitly confirmed it is the baseline playable shinobi. Match its visible face, hair, skin tone, outfit, proportions, palette, and front/side/back silhouette. Do not restore any mask, cape, sword, scabbard, or weapon straps from superseded drafts. The separate [baseline character specification](./BASELINE_PLAYER_CHARACTER.md) supplements the PNG; the PNG takes precedence for visual details. Create original animations, including the required forward-leaning arms-back ninja sprint (R1), using this same character consistently across all frames and directions. Keep normal movement separate from ninja sprint. If sprite generation cannot faithfully reproduce the image, use placeholders clearly labeled as such and flag the asset gap rather than substituting a different character.
