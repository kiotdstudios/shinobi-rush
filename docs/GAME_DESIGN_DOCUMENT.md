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
- 32×32 environment tiles; player/enemy sprites 64×64, approx. 44–52 px tall; boss 96×96 or 128×128.
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
