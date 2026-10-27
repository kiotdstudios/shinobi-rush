# ORDER — natural Blightwood dirt path revision
- Agent: Codex
- Status: REVIEW — 3647/0 native; 131/0 final floor checks; 9/9 actual Web-game comparison. NOT LIVE until integrated and verified.
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
