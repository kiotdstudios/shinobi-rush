# HUD visual specifications

**Reference layout:** 1536 × 1024 original image supplied in conversation; dark near-black metallic panels, gold bevels, red HP, electric-blue Chakra, white outlined typography.

## Screen regions
- Top left: diamond portrait, HP and Chakra bars, **three diamond Substitution charge indicators** beneath bars.
- Top right: dark framed minimap with objective markers; mission tracker directly below.
- Bottom left: **four jutsu slots only**, with controller prompts **R2 + □, △, ○, ✕**. Do not include normal attacks or dodge in this bar.
- World space: enemy HP bars and floating damage numbers.

## Confirmed gameplay/UI behavior
- L2 Substitution has **three independent charge cooldowns**. Each spent charge independently recharges; other charges remain usable.
- The three diamonds each show available, charging, or unavailable states. Suggested visual: blue fill progress inside fixed gold outline.
- Jutsu slots show equipped technique icon, cooldown, and insufficient-Chakra state.
- DualSense-first, keyboard fallback; control glyphs change by input device.
- Preserve safe screen-edge anchoring and legibility at 16:9 and other ratios.

## Palette (initial mockup, not locked)
Charcoal `#10131D`; gold `#B99755`; gunmetal `#454B58`; HP `#B82B35`; Chakra `#2878D8`; text `#E8ECF4`.

## Asset status
- [Substitution diamond SVG](./substitution-diamond.svg) — editable **example** showing gold border and blue charge fill; not final pixel art.
- [HUD wireframe SVG](./hud-wireframe.svg) — editable layout illustration, not final rendered HUD.
- The user-provided full gameplay screenshot is a **visual reference** discussed in chat; it has not been uploaded into this repo.

**Related gameplay spec:** [MVP World Map](../../../world/maps/MVP_WORLD_MAP.md).
