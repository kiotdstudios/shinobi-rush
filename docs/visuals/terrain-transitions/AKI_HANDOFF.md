# Aki — remaining integration contracts

Art families and brown banks are provided in the new manifests. All flat blends use 72×36 / (36,18), full floor coverage, no collision; rock families are explicitly flat only. The existing world/editor IDs remain stable.

## Automatic selection
`AutoTile` is untouched. It still recognizes grass/ground/temple/water and generic land. Brown dirt currently remains a position-bound visual treatment of authored ground IDs. Before automatic blending, assign a real independent material identity for brown dirt versus olive path and define corner ownership, split 6/9 masks and three-material junctions. Use manifest corner meaning, not old exposed-side dirt bits. Hand placement is functional now.

## Bridge/stair landings
Bridge already supplies start/end half-tile caps for both axes, start/end sockets, 2-tile width and 4/6/8 lengths. Reuse those modules. Existing SE/SW stair definitions expose ramp mouth/top/half, rise=66, landing polygon and anchors. Flat grass/soil/rock families can cover adjacent same-level floor. Do not put these surfaces on a vertical cliff or substitute them for ledge collision.

No extra landing artwork is invented without a demonstrated gap: use the existing bridge caps and current stair joint snap tests in a connected proof-of-fit, then request a measured substrate overlap only if still visible. Original PR240 audit counted these as integration needs, not missing generic end caps.

## Waterfall
Existing 16-frame cascade, foam and droplets are retained. Current renderer offsets are cascade (0,-73), foam (0,-1), not an arbitrary-height attachment contract. Aki's modular cliff order requires an upper-river/cliff opening/lower-basin fit before commissioning lip or rock-edge art. No speculative new cliff silhouette or waterfall-size change is included here. Brown bank land layers can be selected beside the lower basin immediately.

## Acceptance split
Codex supplies complete flat mask art, manifests, catalog/filter, native undo/persistence regression, seam validation and actual-game demo. Aki owns automatic material blending, cliff modules/height, bridge/stair geometry and measured waterfall attachments. These handoff tasks are not claimed complete by flat tile delivery.
