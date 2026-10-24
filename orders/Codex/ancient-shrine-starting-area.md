# CODEX ORDER — Ancient Shrine / Asset 01 ONLY: Roofed Shrine Shelter

**STATUS: This replaces the previous broad Ancient Shrine implementation order. Do not execute the earlier Phase 0–2 instructions.**

## Scope and credit guardrails
Generate **exactly ONE new art asset**: the small roofed wooden shrine shelter at the upper-left of the approved Ancient Shrine mockup. **Do not implement a map, modify scenes, edit collisions, change player spawn, alter scripts, or touch any existing game assets.** Do not generate other props or variants.

Before generating:
1. Inspect existing in-game screenshots/assets to establish the isometric camera angle, pixel density, slate-blue-gray palette, nearest-neighbor rendering and top-left lighting. Inspect only relevant files; avoid full-repo refactors.
2. Confirm a usable PixelLab API connection and available generation budget. Read credentials from a secure environment/secret only; never print or commit credentials.
3. If PixelLab access is missing, API errors, or the cost/credit budget is uncertain: **STOP and report the blocker without generating or substituting another image model.**
4. Limit to **one PixelLab generation request**. No automatic retries, edits, upscales, variations, or batch jobs. If the first result is imperfect, save it for review and stop. Never start a second paid request without user approval.

## PixelLab prompt
"One small ancient Japanese-inspired forest shrine shelter, isometric three-quarter view matching an existing 2D pixel-art action RPG. Compact square wooden open-sided shelter, dark aged timber support posts, shallow pitched gray slate-tile roof with distinct layered tiles, worn wood beam detailing, subtly mossed stone footing, abandoned and weathered but structurally intact. Muted desaturated slate gray, charcoal, brown-gray, blue-green moss. Top-left lighting, crisp intentional pixel clusters, authentic pixel art, no antialiasing, no perspective mismatch. Single isolated complete building prop, transparent background, no terrain tile, no surrounding trees, no characters, no UI, no labels, no text, no cast shadow beyond immediate contact footprint. Match current Shinobi Rush environment scale and faux-isometric projection."

Use the existing PixelLab-supported resolution/aspect ratio nearest the game's prop scale, with transparent background. **Do not assume 128×128 without inspecting current asset conventions.**

## Output and stop condition
- Save **one** resulting PNG under `assets/environment/blightwood/ancient_shrine/shrine_shelter_01.png` (or report the actual PixelLab download path if file upload is not supported).
- Do not overwrite any file. Do not wire asset into a Godot scene.
- Report API call count, asset dimensions, transparency status, output path, generation status, and a preview link/image.
- Commit **only the new art asset** on a dedicated feature branch, and open a PR for review if possible. Do not merge or deploy.
- Stop and wait for user approval before creating Asset 02 or changing the game.

**Success = one PixelLab-created shrine shelter PNG for visual approval, with zero gameplay/code changes and at most one paid generation.**
