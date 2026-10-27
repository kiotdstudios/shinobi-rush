# ORDER — natural Blightwood dirt path revision
- Agent: Codex
- Status: DONE — PR226 integrated through PR231; main deployment/postdeploy passed; canonical live comparison 9/9 at c4c33696.
- Branch: codex/brown-dirt-path
- PR: https://github.com/kiotdstudios/shinobi-rush/pull/226
- Dependencies: existing grass/earth art, authored Blightwood map, floor coverage standard.

## Objective
Replace rectangular dirt silhouettes with organic clearing/trail boundaries and broken vegetation blends.

## Context
Owner requests art AND map implementation, same camera before/after game screenshots and a PR. Preserve grass, palette, resolution, isometric grid, combat space, route and collision.

## Scope / Deliverables
Composite existing generated earth and approved grass through one continuous map-space transition mask, then cut registered full-coverage diamonds. Bind presentation to matching authored dirt/grass cells, preserve editor IDs/save format, refresh art after builder moves. Supply actual main-scene review hook, screenshots and tests. Do not edit stair/ledge geometry, AI, player movement or camera outside the optional review hook.

## Acceptance criteria
Asymmetrical clearing, curved and variable-width connections, broken grass tufts and darker/lighter earth variation; no full diamond voids, layout/collision edits or save overwrite. Native/build/browser checks pass. Normal reviewed PR integration and verified canonical live deployment required before DONE.

## Live completion
2026-10-27: merged through [PR231](https://github.com/kiotdstudios/shinobi-rush/pull/231), main `c4c336964e42e73a59b0b2984aa9aae57e4f15be`; [CI/deploy/postdeploy](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40477062807) all passed. Actual canonical game before/after comparison passed 9/9, same camera, 3154 floor/object entries and 103 obstacles. Evidence: `docs/reviews/2026-10-27-live-integration/natural-path/`.
