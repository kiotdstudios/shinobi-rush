# Order - Blightwood shoreline kit
- Agent: Codex
- Owner: Codex
- Status: REVIEW
- Priority: P1 - latest owner request
- Branch: codex/blightwood-shorelines
- Dependencies: live72x36 river grid and grass/path/stone palettes available; PixelLab authenticated.

## Objective
Create grass-to-water, dirt-to-water and rocky shoreline transitions on the existing diamond grid.

## Context / References
Existing live Blightwood water pack and approved grass/ground/stone tiles. Preserve72x36 ground dimensions, three-quarter camera, native pixel scale and shared animated river current.

## Scope / Deliverables
Three connected shoreline families, transparent land and water-mask layers, source provenance, placement metadata, contact sheets and Godot previews. Builder catalog/filter integration, paint/move/delete/persistence, own tests/report and reviewed live deployment. No terrain physics/swimming, combat, camera or automatic map repaint. Historical queued character/wall tasks remain outside this current request.

## Acceptance Criteria / Tests
Straight banks, inner/outer corners and diagonal joins connect on the existing grid. Existing water flows through exposed regions, with no new baked static water patches or dark seams. Palettes sampled from live assets. Asset QC, Godot import/native/Web export, real browser visual/tools/persistence checks, required PR/main deployment and dated canonical-site verification before DONE.

## Local validation
48 native pieces,192 corner probes and384 compatible edge-pair configurations PASS. Godot import/export PASS;2501 native checks PASS;14 builder checks and12 review checks PASS;192 actual preview captures (8s normal/16s half). Await reviewed integration and exact canonical deployment verification.
