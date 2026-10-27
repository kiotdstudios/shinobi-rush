# ORDER — existing ground/path to brown dirt transitions
- Agent: Codex
- Status: DONE — PR230 integrated after PR226 through PR231; main deployment/postdeploy and canonical live 4/4 checks passed at c4c33696.
- Branch: codex/ground-dirt-transitions
- PR: https://github.com/kiotdstudios/shinobi-rush/pull/230
- Dependencies: PR226 brown earth material, existing Ground / paths artwork.

## Objective
Create the same organic broken blending for existing ground/path material meeting brown dirt.

## Context / References
Owner requests a companion to the grass-to-dirt revision. Preserve existing art, native pixel scale, palette and 72×36 diamond grid.

## Scope / Deliverables
Reuse exact ground and soil pixels: 16 corner masks with three variations, nine familiar edge/corner aliases, contact sheet and tiled preview. Add a separate builder filter using standard floor placement/move/delete/save behavior. Do not repaint the map or modify collision, AI, camera or controls.

## Acceptance criteria
Organic broken ground/soil boundaries; native opaque diamonds without gaps; matching source colors; all variants import; builder filter, placement, movement, deletion and persistence work; required tests/report and reviewed PR integration before live completion.

## Live completion
2026-10-27: [PR231](https://github.com/kiotdstudios/shinobi-rush/pull/231), main `c4c336964e42e73a59b0b2984aa9aae57e4f15be`; [CI/deploy/postdeploy](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40477062807) all passed. Canonical game demo has 121 native transition tiles, dedicated builder filter, working player movement and no browser/engine errors. Evidence: `docs/reviews/2026-10-27-live-integration/path-dirt/`.
