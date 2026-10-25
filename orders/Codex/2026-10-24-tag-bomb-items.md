# ORDER — Animated tag bomb items
- Agent: Codex
- Owner: Codex
- Priority: P1
- Status: IN_PROGRESS
- Branch/PR: codex/tag-bomb-items
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
