# Job Report — Modular weapon audit and proposed art contract
- Agent: Codex
- Order: orders/Codex/2026-10-19-modular-weapon-art-poc.md
- Date: 2026-10-19
- Final status: IN_PROGRESS
- Commit / PR: Not committed; art proof in progress

## Work completed
Audited main ce81f6d. The approved player_128 manifest contains idle, walk, run, sprint, jump and dodge:847 production PNGs, all unarmed. No847-frame conversion is necessary or authorized. New combat source studies contain baked katana pixels and some rejected baked-trail frames; those are not in the production manifest. Independent light/heavy trails and hit spark already exist on Codex's combat draft and will be reused.

SpriteActor renders one AnimatedSprite2D. SpriteSet parses whole-frame textures, FPS and a foot anchor; it has no per-frame weapon sockets, separate weapon layer, orientation tracks or attack-family attachment contract. Aki owns those engineering changes. No controller, state machine, camera or runtime manifest changes are made by this art proof.

## Proposed contract sent to Aki
Notified through PR31 comment6278805017. Body128×128, native pixel coordinates, fixed foot anchor[64,116]. Each frame supplies primary-hand grip position, sword angle clockwise in screen/Godot y-down space, weapon layer front/behind body, and optional hand occluder. Both swords share a canonical grip pivot and blade local+X; body files remain identical on swap. Exact timing is a visual proposal pending Aki, not a gameplay decision.

## Files changed
New Codex order, this audit and isolated modular_poc art folder. Southeast only. The existing fully drawn southeast combo is the comparison reference. Broader combat production is deferred by the owner's revision.

## Tests performed BEFORE commit
- Read player_128.manifest.json and SpriteActor/SpriteSet; searched sprites/player code for weapon, socket and hand_anchor: no attachment implementation found.
- Existing847-frame audit and dimensions/alpha evidence recorded in combat inventory report on PR31.
- Runtime/art proof tests pending; no implementation commit yet.

## Issues encountered
Aki attachment/timing schema is not published on main and no response has arrived yet. The proof can demonstrate art alignment and swapping in an isolated browser harness; this does not establish gameplay hitbox/movement integration.

## Questions for project owner
None. Scope is explicitly one character, SE direction, one three-hit combo, two compatible swords.

## Outstanding work / next steps
Finish current sword clip, produce weaponless body set and separate swords, curate per-frame anchors/orientation/draw order, compare against baked approach, validate Godot imports and browser preview, then hand tested art to Aki in a dedicated PR. Do not expand until the proof passes review. Live deployment: not applicable to this audit checkpoint.
