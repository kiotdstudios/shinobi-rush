# Shinobi Rush — Mandatory PixelLab API Art Pipeline

## Owner rule — LOCKED
**Use the PixelLab API as the source for all newly generated pixel-art assets.** This includes player/NPC/enemy sprites, character animation frames, equippable armor/clothing/weapons, environment tiles, props, pixel UI assets, and pixel-art VFX textures/flipbooks. Do not quietly substitute other image-generation services or hand-wave placeholder art as final.

## Responsibilities
- **Codex (art owner):** create, iterate, validate and export assets through the PixelLab API. Maintain consistent style, palette, 128×128 player-frame target, eight directions, fluid animation and three-quarter camera.
- **Aki / Orcha / Kiro:** consume approved assets and coordinate art requests through Codex. They must not independently generate replacement art with another provider.
- Manual cleanup, pixel-perfect correction, layering, texture packing, rigging, animation timing, shaders, particle logic and integration are permitted after PixelLab generation; procedural effects not involving generated pixel-art images are also permitted.

## Operational safeguards
1. Consult the **current official PixelLab API documentation** and confirm actual endpoints, supported generation/animation workflows, rate limits, export formats and commercial-use terms before coding. Do not invent endpoint names or claim API capabilities not verified.
2. Read the approved player reference `assets/characters/player/references/baseline_turnaround.png` and [camera spec](./CAMERA_AND_ART_DIRECTION.md). The reference determines **appearance**, not gameplay camera projection.
3. Obtain credentials through repository/org **Actions secrets** or a local untracked environment variable; never store credentials in Git, reports, screenshots or logs. Do not request users to paste keys into public issues or PRs.
4. Save repeatable **generation manifests** per asset: descriptive ID, PixelLab generation request parameters excluding secrets, output frame dimensions, direction, animation FPS, foot anchor, palette, generation date, provenance and license notes. Retain editable source/exports when permitted.
5. Validate generated outputs: sprite fidelity, 8-way directional consistency, stable attachments, alpha transparency, frame pacing, visual artifacts, VFX readability, and Web export memory/performance. PixelLab output still needs human review and in-engine playtesting.
6. If the API cannot produce a required asset or its use is blocked by missing credentials, quota, unsupported feature or policy, document the blocker and ask for a decision; **do not silently switch to another generator**. Reuse previously approved art where appropriate.

## Quality target
Premium high-detail pixel art and motion, consistent across characters, equippables, effects and environments. More generated frames do not guarantee fluidity: use well-timed original poses and meaningful in-betweens. Follow [Codex Order 01](../../orders/Codex/order_01.md) and the [premium action-RPG vision](../vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md).
