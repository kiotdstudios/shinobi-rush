# Eight-direction idle production checkpoint
- Agent: Codex
- Related order: orders/Codex/order_01.md
- Date: 2026-10-18
- Status: REVIEW — idle technical checks passed; full Order 01 incomplete
- Owner-selected scale: 128x128
- Branch: codex/mobile-animation-preview

## Work completed
PixelLab completed all eight idle directions with 16 frames each (128 frames).
Exported transparent 128x128 copies using a common anatomical scale and per-clip
ground root. Standing silhouette ranges from 100 to 107 pixels. Original source
PNGs preserved locally. Created an eight-panel phone GIF from these actual frames.

## Tests before commit
- build_review.py export: PASS; no output clipping/empty frames.
- Every direction contains 16 unique PNG frames: PASS (8/8).
- Godot 4.5.1 Compatibility rendering: idle east/north/north-east/north-west/south/
  south-east/south-west/west all PASS, 16 frame captures each, no stderr.
- Full review runner: 16/16 pose and motion cases PASS, including older samples.
- Mobile GIF reopened with Pillow: PASS, 600x1190, 16 frames, infinite loop.
- Order validator and git diff checks executed before commit.

## Issues and remaining work
This is a technically checked idle review, not final AAA-quality acceptance or
completed game integration. Walk is accepted in all eight directions under
PixelLab group e24eae75-7e91-4711-b8d0-85b74c544234. Full production run, remaining
sprint directions, jump/dodge/combat/hit, equipment overlays and VFX remain.
The previous idle batch occupied all eight API slots; other batches had not
started during that time. No false overall-completion claim.

## Owner questions
None for continuing the approved scale.

## Publishing
Only the mobile review GIF and this report are committed here. No main merge or
game deployment. Preview URL is verified after push; integration remains reviewed
under draft PR 3.
