# Shinobi Rush — PixelLab-Assisted Art Workflow (Owner Revision)

## LOCKED decision — artist autonomy with mandatory PixelLab skill review
**Codex may generate original game art with its own effective tools and skills. PixelLab API is available and preferred where it improves quality, consistency, directional animation, iterative editing, or production efficiency, but is NOT mandatory for every image.** Codex **must review applicable PixelLab API/skill documentation** before deciding how to produce a new asset batch. Do not discard successful existing art simply because it was not generated with PixelLab.

### Mandatory before producing an art batch
1. Review the project's `skills/three-quarter-game-art/SKILL.md`, the current official PixelLab API/MCP documentation, and any PixelLab skills available in the Codex environment. Examples for investigation (not automatic endorsements): `https://api.pixellab.ai/mcp/docs`, `https://github.com/protonspy/pixellab-cli/tree/main/src/pixellab_cli/skill/pixellab-cli-assets`, `https://github.com/Shilo/pixellab-pip/tree/main/skills/pixellab-pip`. Verify safety, maintenance, terms and API compatibility before using third-party skills.
2. Check whether PixelLab credentials are already configured in Codex's environment **without exposing the key**. Do not assume they are missing or ask the owner for a new key until checked. Never commit or log secrets.
3. Select **PixelLab API or Codex's proven art workflow** per asset. Record the choice and reason in the generation manifest/report; disclose which assets actually used PixelLab. No fake API-use claims.
4. Preserve the approved visual reference and test at the actual elevated three-quarter gameplay camera, not only on an orthographic turnaround.
5. For each source, export actual transparent PNG assets, animation manifest, frame dimensions, directions, FPS, consistent foot anchor, equippable attachment alignment and in-engine previews. Manual correction, rigging, compositing and effects are allowed.

## Pixel dimensions
Production sprite frames are locked at 128×128 RGBA (see the FINAL OWNER DECISION below and [orders/README.md](../../orders/README.md)). Before mass-generating animations, test at actual gameplay zoom, including diagonal pose, idle/run/sprint test motion, equippable readability, and Godot Web texture/performance costs. Do not confuse the resolution of an uploaded *composite reference image* with the underlying sprite frame size.

## Motion quality
Aim for premium, responsive, well-timed animation. More frames only help when they improve motion arcs, transitions and secondary movement. Frame-count tables in Order 01 are **targets to evaluate**, not required filler. Use the best viable frame counts and timing after gameplay preview.

## Coordination
Codex owns art. Other agents may request assets and integrate approved outputs, but should not overwrite art or mandate a particular generator. The project's existing persistent-world RPG design and quality bar remain unchanged.


## FINAL OWNER DECISION — Production sprite frame size (2026-10-18)
**LOCKED: All standard production character sprite frames MUST be 128×128 pixels, RGBA with transparency.** This overrides any earlier 64×64 vs 128×128 evaluation or scale-approval requirement in this file or linked orders. Do not create 64×64 production character sprites. Legacy 64×64 artwork may be retained as reference only. Larger canvases may be used for attacks/VFX extending outside the base frame, but keep the character's world-space/body scale, proportions, foot anchor and alignment consistent. Maintain eight-direction animation targets and premium fluid motion. PixelLab remains optional after mandatory skill/API review as separately documented.
