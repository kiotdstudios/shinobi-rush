# Timed idle review previews
- Agent: Codex
- Related order: orders/Codex/order_01.md
- Date: 2026-10-18
- Status: REVIEW — timed review media ready; full character order remains incomplete
- Branch: codex/mobile-animation-preview

## Owner request
Some directions appear to move faster; provide a visible clock/timer or speed control.

## Changes
Added a common animation-time display, 1–16 frame counter, speed label and progress
bar to all-eight-direction idle review GIFs. Provided 1x, 0.5x and 0.25x playback
versions. Every panel uses the exact same source frame index on each output frame.
The source character art and individual motion poses are unchanged.

## Tests before commit
- build_timed_idle_preview.py: PASS; asserts eight directions with 16 source frames.
- Reopened all GIFs with Pillow: PASS; 16 frames, infinite loop, 600x1240.
- Verified all decoded GIF frame durations exactly match the planned sequence.
- Total playback lengths: 670ms normal, 1330ms half speed, 2670ms quarter speed.
- Visually inspected the rendered normal-speed GIF header and all eight panels:
  PASS; no overlap or clipping in timer, labels or sprites.
- Repository order validator and staged diff checks run before commit.

## Timing detail
The clock shows source animation time at 24fps; it resets each 16-frame loop
(0.667s nominal). Slower versions slow playback while the source-time clock still
shows which animation moment is being inspected. GIF timing is quantized to
centiseconds, so cumulative timestamp rounding alternates durations rather than
rounding every 41.67ms source frame down to 40ms. It preserves the overall rate to
within GIF's timing precision.

All directions share playback timing. Differences in the amount/spacing of
generated movement may still make some directions look more active. This tooling
helps compare those differences; it does not claim to fix animation continuity,
amplitude or body drift. Links offer fixed review speeds rather than an
interactive slider, which a GIF cannot support.

## Files
assets/characters/player/previews/mobile/idle-timed-normal.gif
assets/characters/player/previews/mobile/idle-timed-half-speed.gif
assets/characters/player/previews/mobile/idle-timed-quarter-speed.gif
assets/characters/player/previews/mobile/timed-preview-validation.json
assets/characters/player/previews/mobile/README.md
This report.

## Issues / owner questions
None for this preview-media change.

## Delivery
Public raw GIF responses and frame counts verified after push. No gameplay code,
main merge or live game deployment applies to this media-only review update.
