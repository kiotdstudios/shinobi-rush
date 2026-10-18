# SHINOBI RUSH — Game Design Document (Working Draft v0.1)

> Working title. Consolidated from the Shadow Trials concept developed October 16, 2026; not a verbatim copy of a separately saved document.

## Vision
An original, fast-paced, single-player 2D action roguelite with a three-quarter top-down/faux-isometric camera, stylish shinobi combat, rival villages, and collectible techniques. Distinct original factions include the Kōsen (Hidden Ascent) Village and the white/blue/gold Cloud Clan. All playable and featured character concepts should be Black/African-American in appearance, with diverse hair, faces, and silhouettes.

## Core loop
1. Start in the village hub and choose a mission and ability loadout.
2. Infiltrate an enemy compound and clear approximately five combat rooms.
3. Select temporary technique upgrades and recover resources in one reward room.
4. Fight a boss and claim scrolls/resources.
5. Return to the hub to unlock permanent upgrades; repeat with different encounters and builds.

Target run: 8–12 minutes. Start with hand-authored modular rooms; vary their order, enemy spawns, and rewards rather than procedural terrain.

## Combat
- 8-direction WASD movement and mouse aiming.
- Left click: three-hit melee combo; right click: offensive technique.
- Space: evasive dash (Cloud Step), brief invulnerability.
- Q: Shadow Clone, copies an attack or distracts.
- E: Wind Palm, knockback and interruption.
- F: interact.
- Lightning Strike: line attack, with chain-lightning upgrades.
- Health: 100 HP; Chakra: 100. Chakra slowly regenerates and builds faster on successful melee attacks.
- Jutsu Fusion: temporary upgrades combine skills, e.g. Shadow Clone + Lightning = electrified exploding clone. MVP: two fusions.

## Enemy roster
- Rogue Scout: rushes, double-strikes, retreats.
- Kunai Specialist: ranged attacker that repositions.
- Iron Guard: slow armored foe with telegraphed slam and recovery window.
- Boss: Fallen Cloud, former clan captain; charge slash, lightning wave, clone attack, accelerated second phase at 50% HP.

## First biome: Storm Shrine
Abandoned mountain shrine with cool stone, navy shadows, glowing blue energy, gold accents. Seven modular rooms: two courtyards, two indoor shrine chambers, a bridge/cliffside, a reward room, and a boss arena.

## Art direction
- Original Kōsen faction: olive tactical gear, white bandage accents, distinctive three-spire emblem, high mountain fortress, precision/resonance arts.
- Cloud Clan: white garments, pale-blue cloud motifs, gold trim, black tactical layers.
- Standard production character sprites 128×128 RGBA, standing height about 100–112 px (see [orders/README.md](../orders/README.md)); world tile scale is provisional, set against that character in the in-engine test arena, subject to owner approval.
- Four directional animation sets; initial target 640×360 resolution with nearest-neighbor scaling.
- Faux-isometric backgrounds and straightforward 2D movement/collisions.
- Approx. 132 player animation frames across idle/run/combo/dash/cast/hit/defeat in four directions; use placeholders first.

## Technical plan
Godot 4, GDScript, Camera2D, AnimatedSprite2D, TileMapLayer, Godot Resources, Windows PC first. Asset production in Aseprite or LibreSprite.

## Six-week prototype target (scope-dependent)
1. Movement, dash, camera, collision, HP, one test room.
2. Melee, hitboxes, chakra, lightning, damage/death.
3. Three enemy behaviors, room waves, rewards.
4. Art, sprites, VFX, UI, sound.
5. Boss, village menu, upgrades, mission completion.
6. Polish, balancing, playtesting, Windows build.

## MVP acceptance criteria
One playable Kōsen/Cloud ninja; responsive dash and melee; four core abilities; three enemy types; one boss; a seven-room run; basic rewards and permanent upgrade; keyboard/mouse support; readable HP/chakra HUD; playable Windows build.

## Not in MVP
Multiplayer, full open world, character creator, extensive story/cutscenes, procedural world generation, large jutsu library, complex hand-sign controls.

## Original IP
Do not use Naruto village insignia, protected characters, or branded techniques. Review terminology and visual references before commercial release.


## Primary input: PlayStation controller (required for MVP)
The game is designed **controller-first**, targeting DualSense and DualShock 4 when connected to a PC. Keyboard/mouse is a secondary option. Controller support on PC does **not** imply PlayStation console certification or a console release.

### Default gamepad mapping
| Input | Action |
|---|---|
| Left stick | 360-degree movement |
| Right stick | Directional aiming; retain last aim direction when neutral |
| Cross (X) | Dash / evade |
| Square | Light attack / three-hit combo |
| Triangle | Heavy attack / launcher |
| Circle | Interact / contextual counter (context priority) |
| L1 | Guard / timed parry |
| R1 | Quick technique |
| R2 | Signature technique |
| L2 (hold) | Technique wheel; right stick selects; release activates |
| D-pad | Consumables / equipped technique shortcuts |
| Options | Pause |
| Touchpad press | Map / mission status |

### Controller-first requirements
- Use Godot 4 InputMap **actions**, not hard-coded keyboard keys or gamepad IDs; expose remapping and input presets.
- Support DualSense and DualShock 4 over USB and Bluetooth where recognized by the operating system. Test both native and Steam Input paths; avoid double-input.
- Detect connected/disconnected controllers and swap on-screen button glyphs between PlayStation and keyboard/mouse based on last active device. Include a manual glyph override.
- All menus, pause screens, technique wheel, rewards, and hub interfaces must be fully navigable by D-pad/sticks, with visible focus, confirm/cancel, and no mouse requirement.
- Tune dead zones, dash response, directional aim assist, buffered inputs, and optional vibration. Do not depend on adaptive triggers, touch gestures, or platform-exclusive features.
- Test on a real controller for movement, aiming, attack chaining, pause/resume, controller reconnection, remapping, and menu navigation.

### MVP acceptance criteria additions
A complete 8–12-minute run can be played from launch to exit using only a PlayStation-style controller on Windows PC, with no keyboard or mouse needed. The game must clearly show the correct prompts and handle unplug/replug without losing progress.


## PC / Steam release plan (confirmed)
- **Launch platform:** Windows PC, downloadable through Steam.
- **Primary input:** PlayStation DualSense; keyboard/mouse secondary.
- **Development engine:** Godot 4; export Windows x86_64 builds.
- **Distribution progression:** local PC controller playtests → private Windows playtest builds → Steam demo/playtest → full Steam release.
- **Steam Input:** test PlayStation controller support both with Steam Input enabled and disabled; prevent double inputs and display accurate button glyphs.
- **Release readiness:** full controller navigation, rebindable controls, windowed/fullscreen settings, persistent save data, performance targets, crash/error logging, clear build/version numbers, and a reproducible export pipeline.
- **Steam publishing:** requires a Steamworks partner account, store assets, app setup, review, and applicable fees; console PlayStation publishing is not part of this scope.
- **First milestone:** launch a standalone Windows build, complete a full mission on DualSense without keyboard/mouse, and verify save/load and controller reconnect.

## Proposed Black Myth: Wukong-inspired controller preset (pending playtest)
Use Black Myth: Wukong Type A as the ergonomic reference, while retaining original Shinobi Rush abilities and identity. This **supersedes the earlier default proposal for playtesting**, not yet a locked final scheme.

| DualSense | Shinobi Rush action |
|---|---|
| Left stick | Move |
| Right stick | Aim / select target direction |
| R3 | Lock on / cycle target |
| Square | Light combo |
| Triangle | Heavy / charged attack |
| Circle | Dodge / dash |
| Cross | Jump or traversal (prototype; omit if no meaningful verticality) |
| R1 / L3 | Sprint |
| L1 | Heal |
| L2 | Guard / parry |
| R2 + Square | Technique 1 (Shadow Clone prototype) |
| R2 + Triangle | Technique 2 (Lightning Strike prototype) |
| R2 + Circle | Technique 3 (Wind Palm prototype) |
| R2 + Cross | Technique 4 (custom / ultimate prototype) |
| D-pad | Consumables or fighting stances, pending combat test |
| Touchpad | Mission map |
| Options | Pause |

Test two selectable presets: **Face Attacks** (above) and **Shoulder Attacks** (R1 light, R2 heavy; move technique modifier to L2 and guard to L1). Support full rebinding and correct on-screen glyphs. For the isometric camera, right stick should aim/select rather than rotate the world camera; add soft lock-on and a visible target indicator. Prioritize dodge timing, attack cancel windows, buffered inputs, and responsive combo chains.


## L2 Substitution Jutsu — confirmed control requirement
**L2 is dedicated to Substitution Jutsu**, replacing the previous proposed L2 guard/parry mapping. This is a timed defensive escape inspired by arena fighting games, but must use original Shinobi Rush visual effects and implementation.

- On a correctly timed L2 press as an enemy strike connects, cancel incoming damage and reposition the player behind or to the side of the attacker, subject to safe collision/arena bounds.
- Play a distinct smoke/afterimage effect and a brief recovery/response window; the ability should not guarantee a free counterattack.
- Early/late presses fail and consume no charge in the initial prototype (tune during testing).
- Prototype with 3 substitution charges, shown in the HUD. Compare timed recharge versus combat-earned recharge in playtests.
- Circle remains the standard evasive dodge/dash, with its own timing and recovery.
- Guard/parry is unassigned pending controller playtesting; do not overload L2.
- Prototype tests: multiple enemies, projectiles, boss attacks, corner positioning, no valid teleport destination, repeated presses, charge exhaustion, controller input buffering, and clear success/failure feedback.


## Confirmed combat design decisions — October 2026
These decisions are approved for Shinobi Rush and supersede any earlier tentative descriptions.

### Aerial combat — YES
- Ground light/heavy combos can launch enemies; the player can pursue and chain aerial strikes.
- Add air attacks, aerial technique use, air recovery, landing states, and limits to prevent indefinite juggling.
- Maintain clear depth shadows and readable height indicators in the faux-isometric view.
- Prototype controlled jump arcs and grounded hitboxes before committing to full sprite sheets.

### Awakening system — YES
- Each playable character has a temporary powered-up state earned through active combat.
- Awakening modifies selected attacks, technique behavior, effects, and combo finishers.
- Specify gauge gain, activation input, duration, cancel rules, and balance in a dedicated design pass; avoid consuming an already-assigned button.
- Prototype after the base combat loop is stable.

### Fluid multi-enemy combat with optional lock-on — YES
- Default movement and attacks support fighting multiple enemies fluidly.
- R3 toggles optional hard lock-on for bosses and elite enemies; right stick cycles targets when locked.
- Without hard lock-on, right stick provides directional aim and soft-target assistance.
- Enforce clear enemy attack telegraphs, fair off-screen aggression rules, and camera framing that keeps threats visible.
- Prototype targeting and camera behavior alongside combos, dash, and L2 substitution.


## Revised MVP direction — guided semi-open world (confirmed October 17, 2026)
**This section supersedes the earlier seven-room roguelite / Storm Shrine MVP, three-enemy roster, and 8–12-minute room-run structure.** The game is now a guided, interconnected semi-open-world action RPG inspired by Black Myth: Wukong's exploration pacing, while retaining original Shinobi Rush IP, 2D faux-isometric presentation, and previously confirmed combat systems.

### Locked MVP content
- **One playable character.**
- **One continuous, playable biome** with authored pathways, branching exploration, optional discoveries, shortcuts, and checkpoints; no room-by-room roguelite run selection.
- **Two regular enemy archetypes:** Basic Bandit and Heavy Bandit.
- **One boss** at the biome's main objective.
- Preserve DualSense-first combat, L2 Substitution Jutsu, combos, aerial launch/pursuit, awakening, and optional R3 hard lock-on.

### Proposed first-biome traversal (layout concept, not final map)
Starting outpost/tutorial → forest approach (basic bandits) → fork between mountain trail (heavy bandits) and hidden ruins (optional exploration) → bandit stronghold and boss. Provide return routes and shortcuts, with readable navigation and limited loading transitions as required by performance.

### Scope and implementation
- Build an authored interconnected map using streamed or segmented Godot scenes as needed; the player's experience should feel continuous.
- Prototype checkpoints, respawn, persistent pickups, shortcut unlocks, enemy reset rules, and boss retry flow.
- No procedural combat-room generation required for the MVP.
- Target a short but complete exploration-to-boss vertical slice; playtime to be established through testing rather than assumed.
- Prioritize navigation readability in a 2D faux-isometric camera, clear elevation cues, and robust collision/occlusion handling.
- The existing six-week schedule is an outdated estimate; re-estimate after mapping and movement prototypes.


## Exploration structure — FINAL MVP DECISION
**Branching guided-world exploration is locked for the MVP.** This supersedes any earlier uncertainty about linear vs. open layout.
- One interconnected, hand-authored biome with a clear main objective and destination: the bandit stronghold/boss.
- A readable main route, multiple optional side paths, discoverable secrets and rewards, backtracking, and unlockable shortcuts.
- Checkpoints for healing, saving, and respawning; specify enemy reset and boss retry behavior during implementation.
- Use environmental landmarks and composition to guide navigation rather than constant objective markers.
- Design around one basic bandit, one heavy bandit, and one boss; reuse these thoughtfully in varied terrain.
- Test navigation readability, shortcut utility, return routes, and controller-only traversal before expanding content.


## Kōsen Village gate / forest world topology — confirmed
- The player starts **outside the gates of Kōsen Village**, at the home gate.
- The long-term world has **three forest paths** leaving this gate.
- One forest route ends in a **dead end**, but forks before its endpoint.
- Another route also forks: one branch **connects back to the previously forking forest route**, and the other reaches **a neighboring village gate**.
- The third forest route exists as part of the larger world plan; its downstream topology remains to be designed.
- **MVP scope: home gate and two playable forest paths only**. Do not build the neighboring village gate or the third full forest route yet.
- Preserve the eventual interconnection in the world layout; blocked future routes should read as natural, intentional boundaries.
- Keep the already approved basic bandit, heavy bandit, one boss, optional exploration, shortcuts, controller-first combat, and guided branching structure. Boss placement within the two MVP paths is not yet finalized.
- The route names A/B/C in planning diagrams are placeholders, not official region names.

## Canonical world map
The evolving Kōsen forest topology and potential unlockable shortcut are maintained in [`world/maps/README.md`](../world/maps/README.md). Update that diagram whenever the biome expands; it is the source of truth for route connectivity.
