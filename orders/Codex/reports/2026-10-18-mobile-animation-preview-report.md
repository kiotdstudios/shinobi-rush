# Mobile animation preview report
- Agent: Codex
- Date: 2026-10-18
- Related order: orders/Codex/order_01.md
- Preview task status: REVIEW — tested preview files ready for owner viewing
- Full Order 01 status: incomplete; production-scale approval pending
- Branch: codex/mobile-animation-preview
- Commit / PR: prepared for commit after the tests below

## Work completed
Created phone-sized GIF comparisons from the existing PixelLab scale-study frames.
Both columns show equal world size: 64px left, 128px right; south on top and
south-east below. Includes idle (4 unique frames), normal run (8), and arms-back
ninja sprint (20). These are review samples, not a final production pack.

## Files
assets/characters/player/previews/mobile/idle.gif
assets/characters/player/previews/mobile/normal-run.gif
assets/characters/player/previews/mobile/ninja-sprint.gif
This report.

## Tests before commit
Pillow reopened each exported GIF and verified frame counts: 4, 8, 20 respectively.
Each is 600x660 and loops indefinitely. Existing source clips passed eight Godot
Compatibility-renderer cases, with no runtime stderr; the browser comparison
reported no console warnings/errors. No new gameplay code or live game deployment.
Remote GIF response and frame-count checks will follow push.

## Issues
localhost is inaccessible from the owner's phone away from the PC. PixelLab
gallery preserves uploaded frames but its download returns a static PNG atlas.
A separate GitHub preview branch makes the actual animated GIFs accessible.

## Questions for owner
Choose 64x64 or 128x128 after viewing. 128x128 is recommended for costume detail.

## Next steps
Open the direct GIF links on mobile, collect the required scale decision, and
continue full art production. Reviewed integration and actual live game deployment
remain separate work. Live game deployment: not applicable to this art-review-only
snapshot. No main merge performed.
