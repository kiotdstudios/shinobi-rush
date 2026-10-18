# Shinobi Rush mobile animation review

Production scale: **128x128**, selected by the owner.

[Current idle — preferred half-speed breathing](idle-current.gif).
Default review speed is 0.5x. Gameplay playback is tuned per action.

## Eight-direction idle with synchronized timer

All eight directions use the same clock and frame index. The clock resets after
one 16-frame loop (0.667 seconds of source animation time).

- [Normal speed](idle-timed-normal.gif)
- [Half speed](idle-timed-half-speed.gif)
- [Quarter speed](idle-timed-quarter-speed.gif)

The slow versions are useful for inspecting foot contact, head/hair movement,
body drift and differences in motion spacing. These are review previews; final
Order 01 art production and integration are still in progress.

## Earlier scale comparison

- [Ninja sprint](ninja-sprint.gif)
- [Normal run](normal-run.gif)
- [Idle](idle.gif)

These earlier comparisons show 64px on the left and 128px on the right.

## Idle refinement v2
South-east preserved; south/north-east redrawn with planted breathing; south-west retimed to one breath per reference loop.
- [V2 normal speed](idle-v2-normal.gif)
- [V2 half speed](idle-v2-half-speed.gif)
- [V2 quarter speed](idle-v2-quarter-speed.gif)
