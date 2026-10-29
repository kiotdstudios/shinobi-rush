# Smart Terrain Family Suggestions — Phase 1

The existing **Auto Blend** editor brush remains the authoritative painter for grass, ground, dirt, temple, and rock. PR #245 and #251 are merged on main.

`TerrainFamilyMatcher` is an opt-in helper for imported art. It checks the native **72×36** footprint, reads explicit `terrain_family` metadata first, recognizes registered transition and junction IDs, and can compare sampled RGB/alpha features with registered reference textures. It returns suggestions with a confidence score and `approved: false`. No texture is automatically assigned to a terrain family based on color alone.

An explicit caller must invoke `approve()` to store a confirmed mapping in its overrides dictionary. This does **not** change `TerrainBlend.FAMILIES`, generate transition masks, or register new assets in `PlacedObjects`. Import approval UI, manifest persistence, full isometric diamond edge sampling, and browser integration remain future work.

The existing brush supports painting, fill, erase, undo/redo, and persistence independently of this helper. Do not advertise the helper as an end-to-end smart import workflow until those integrations are implemented and tested.
