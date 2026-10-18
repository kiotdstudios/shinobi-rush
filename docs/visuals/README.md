# Shinobi Rush — Visual Design Library

This directory is the canonical home for **visual design source files, UI diagrams, mockups, and asset specifications**. The future interactive HTML GDD should use this library rather than reconstructing visuals from chat history.

## Directory map
- [HUD](./hud/README.md): placement, status bars, Substitution diamonds, four-slot R2 jutsu loadout, minimap, quest tracker, and combat feedback.
- [Jutsu cards](../jutsu-build-cards/README.md): individual jutsu stat illustrations (currently Markdown mockups; not rendered PNG artwork).
- Future directories: `characters/`, `world/`, `combat/`, `progression/`, `equipment/`. Add these when actual visual assets exist.

## Standards
1. Store every **new reusable visual** as an actual versioned repository file: SVG/HTML/CSS for editable diagrams or mockups, PNG/WebP for exported art, plus its source when available.
2. Each asset gets a short description of purpose, dimensions/aspect ratio, status (approved / example / draft), and associated gameplay design file.
3. Do not treat in-chat previews, external search images, or visual descriptions as committed assets. A visual is in Git only after its file is uploaded and verified.
4. Preserve references as **references**, not original owned artwork. Do not copy external image assets into the repo without permission.
5. Keep gameplay numbers marked **illustrative** until balanced.
6. HTML GDD can embed these assets and link to the gameplay specifications.

## Main design sources
- [MVP World Map and current confirmed rules](../../world/maps/MVP_WORLD_MAP.md)
- [Game Design Document](../GAME_DESIGN_DOCUMENT.md)
