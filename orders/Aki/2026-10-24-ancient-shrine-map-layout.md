# Aki — Ancient Shrine map section (2026-10-24)

Implement the user's attached Ancient Shrine reference screenshot as a playable, editable section of the existing Shinobi Rush world. **Match the reference layout** rather than using the image as a flattened background.

## Layout
- Upper terrace: blossom trees at upper-left, existing shrine shelter at upper-center-left, surrounding foliage, wooden fences, dirt/stone courtyard, guards, and four fire pillars.
- Central terrain: cliff face and waterfall falling into lower river/pond, with stones, reeds and grass.
- Lower tier: winding walkable paths, crossing/bridge, red shrine marker, stone lanterns, guard placements and forest edge.
- **No stairs:** replace stair area with tall grass tiles and trees, preserving valid navigation.
- Keep perspective, relative positions, terrain height illusion, and the full screenshot's overall composition.

## Existing repo
Godot: `scenes/main.tscn`, `scenes/arena/training_arena.tscn`. Existing shrine art: `assets/environment/blightwood/ancient_shrine/shrine_shelter_01.png`. Existing test: `tests/test_ancient_shrine.gd` expects exactly one shrine in the starting level. Inspect actual world editor and placed object catalog, available grass, fence, trees, water, cliff, torches and bridge assets before building. Follow `AGENTS.md`, `orders/README.md` and `docs/visuals/CAMERA_AND_ART_DIRECTION.md`.

Use live Shinobi Rush grass palette (#1A2D2F, #283E31, #364C3E, #485F55, #5B7262, #728872, #89A087, #9DB399) and blossom palette (#203A57, #38547C, #476898, #5F82B5, #7699CA, #808EAC, #99A7C2, #B9CBE2), respecting existing approved textures.

## Delivery
1. Build using actual tile/prop placements and proper draw ordering, collision, navigation, persistence, no duplicated shrine.
2. If an asset is absent, document the missing art and use only a visually appropriate placeholder.
3. Run scene load and relevant tests; validate playable paths and no water/cliff collision softlocks.
4. Capture in-engine full-area screenshot, compare to reference and iterate.
5. Commit changes via feature branch and PR, report links, tests, screenshot and any unresolved gaps. Do not claim live until deployed and checked.
