# CODEX ORDER — Ancient Shrine starting area (Blightwood Forest)

## Mission
Build a playable, visually faithful **Ancient Shrine** starting area in Shinobi Rush. The user's approved visual target is the cropped shrine mockup from this conversation: elevated forest clearing, small gray-tiled timber shelter upper left, lavender flowering tree left, weathered central altar, 3 lit braziers, wooden perimeter fencing, dirt/moss walking ground, two shinobi NPCs, a health gourd and scroll, thick grass, short entrance steps lower left, cliff edge with waterfall below, and path exiting right toward Blightwood Forest / eventually Ashen Ruins.

**Use the current in-game camera projection, art scale, lighting, palette and collision system.** In-game reference has slate-gray isometric floor, blue-green grass and lavender tree, and gray stone walls with muted red trim. Do not paste the mockup as a background or introduce mismatched 3D-looking art.

## Phase 0 — audit before editing
- Locate existing main scene, spawn point, map/tiles, vegetation, walls, pickups, NPCs, shaders, asset generation workflow, and Godot tests.
- Reuse current lavender tree, grass, floor, health gourd and character assets where viable. Inventory existing vs missing assets in the PR.
- Determine real tile dimensions and sorting/y-sort conventions from source; do not assume 128x128 is a tile size.
- If PixelLab API is available in agent environment, generate missing sprites through it using credentials only from secrets/environment. Never put an API token into code, logs, commits or PR. If unavailable, use clearly labeled temporary blockouts and list missing art; do not falsely claim PixelLab assets.

## Phase 1 — playable shrine blockout
- Set the Ancient Shrine as a starting spawn area, with a clearly walkable center and entrance from lower-left and exit on right.
- Lay out central stone altar, roofed shelter upper-left, lavender tree left, fence along top/right, stone lanterns and 3 braziers, offering crates, rocks, grass patches.
- Build cliff boundaries and short steps lower-left, and waterfall/pool visual below edge, with safe collision. Avoid falls through visual voids.
- Add two non-hostile shinobi NPCs with basic interaction prompt, no invented quest/dialogue beyond simple placeholder.
- Place a health gourd and scroll pickup only if pickup system supports them. Reuse the existing gourd collection VFX; avoid regressions.
- Preserve controller support, existing controls, combat, movement, camera, and level transitions.
- Add clear path/exit toward Blightwood Forest. Do not build the whole forest or Ashen Ruins in this PR.

## Phase 2 — visual polish
- Match screenshot composition and muted blue-gray/green/lavender palette.
- Provide appropriate occlusion and Y-sort around shelter, trees, fences, props.
- Animate brazier flames and waterfall modestly; ensure no z-fighting, clipping, invisible collision or obstructed spawn.
- Make environment props modular and reusable; transparent PNG, nearest-neighbor rendering, consistent light direction for new sprites.

## Acceptance tests
1. Fresh game starts in Ancient Shrine, player can move freely on controller and keyboard.
2. Walk from lower-left entry around altar to right exit; no blocking geometry or collision leaks.
3. Cannot walk through shrine shelter, altar, cliff faces, braziers, or fences.
4. NPCs are interactable without blocking required route.
5. Health gourd heals once and displays existing pickup feedback.
6. Existing combat and input actions still work.
7. Godot import, validation, tests, and web export pass. Capture screenshot from normal gameplay camera and compare against user-approved shrine mockup.
8. Commit and push changes to a feature branch, open PR, report exact changed files and screenshot/build link. **Do not merge before green CI**.

## Work sequence
First implement geometry/spawn/collision; then place existing art; then create missing props; finally polish and verify. Keep scope to the Ancient Shrine starting area.
