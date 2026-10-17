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
