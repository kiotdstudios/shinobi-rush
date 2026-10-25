# ORDER — Animated tag bomb items
- Agent: Codex
- Owner: Codex
- Priority: P1
- Status: DONE
- Branch/PR: codex/tag-bomb-items / https://github.com/kiotdstudios/shinobi-rush/pull/194 (merged)
- Dependencies: existing gourd pickup, inventory and paper-tag throwing systems

## Objective
Create two obtainable, throwable spherical tag bombs with dynamic animation and pickup glow.

## Context / References
Owner concept: white paper explosive bomb with black calligraphy and red seams; smoke bomb must be BLACK with WHITE calligraphy and RED seams, never blue. Preserve existing paper tags and gourds.

## Scope / Files owned
New PixelLab bomb body/flight/armed art, separate effects, manifests, previews and review. Small explicit item integration in inventory, pickup, player throw dispatch and builder; no AI/controller redesign. This direct owner request takes priority over historical superseded queued art orders.

## Deliverables
Two animated item packs, pickup and throw support, separate smoke effect, builder entries, review scene, integration notes and tested PR.

## Acceptance Criteria / Tests
Transparent aligned native pixel frames; no blue smoke-bomb body; readable at gameplay zoom. Collect, assign, consume and throw both items. Preserve existing paper-tag damage/fuse and gourd behavior. Smoke must not damage actors. Native tests, Web export/playtest, reviewed integration and canonical live verification.

## Handoff / Notes
Smoke is a visual screen; AI stealth/line-of-sight behavior remains Aki-owned unless separately assigned. Report that limit explicitly.

## Completion — 2026-10-25
112 native PixelLab frames delivered; obtainable/throwable items and builder entries live. PR #194 merged as `d410ff30c51bf26c228a2108a52814909249cb61`. Main workflow [40178592040](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40178592040) fully succeeded including deploy, post-deploy and gate; 2828 native tests passed. Public `?bombs=review` validated at 2026-10-25T09:13:47.455Z against that exact SHA: 12/12 passed, zero console errors. Pickup/explosion/smoke screenshots inspected. See own job report and docs/visuals/tag-bombs/live-browser. Smoke AI stealth remains separately owned, not implemented or claimed.
