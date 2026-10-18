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

## Idle refinement v3
East and north revised for planted breathing. Other six directions retain v2 frames. Half speed remains the default; timer now shows actual playback seconds (1.333s per loop at half speed).

- [V3 normal speed](idle-v3-normal.gif)
- [V3 half speed](idle-v3-half-speed.gif)
- [V3 quarter speed](idle-v3-quarter-speed.gif)

## Idle refinement v4
West and north-west revised for quieter planted breathing. Other six directions preserve v3 frames. Default remains half speed.

- [V4 half speed](idle-v4-half-speed.gif)
- [V4 normal speed](idle-v4-normal.gif)
- [V4 quarter speed](idle-v4-quarter-speed.gif)

## Idle shoulder refinement v5
East and north-west shoulder breathing revised with fixed head/lower-body cels. Other six directions retain v4 frames. Half-speed default preserved.

- [V5 half speed](idle-v5-half-speed.gif)
- [V5 normal speed](idle-v5-normal.gif)
- [V5 quarter speed](idle-v5-quarter-speed.gif)

## Eight-direction walk review v1
Idle v5 approved by the owner. Next review: 16 unique walk poses per direction at approved 128px scale. Synchronized timer and shared playback speed.

- [Walk half speed - default](walk-v1-half-speed.gif)
- [Walk normal speed](walk-v1-normal.gif)
- [Walk quarter speed](walk-v1-quarter-speed.gif)
