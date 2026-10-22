# ORDER — Builder grass, type filters and scroll isolation
- Agent: Codex
- Status: IN_PROGRESS
- Priority: P0 — direct owner request
- Owner: Codex (owner explicitly assigned builder changes in this session)
- Branch/PR: codex/builder-grass-filters
- Dependencies: current main e561574 and existing grass delivery

## Objective
Add existing grass tiles to World Builder, including moving/deleting current grass; stop wheel zoom while pointer is over builder; checkbox filters hide/reveal asset types.
## Context / References
Owner request in this conversation. Preserve Aki builder save/download behavior, collision, gameplay and approved grass art.
## Scope / Files owned
PlacedObjects, WorldEditor, grass field adoption, additive arena hook, wheel routing and relevant tests/probes. Explicit owner request authorizes these overlapping builder files for this job.
## Deliverables
Thirteen grass palette entries; editable starting grass and persistent placements; type visibility checkboxes; UI wheel isolation; tests, PR, report and live verification.
## Acceptance Criteria / Tests
Place/move/delete/save/reload grass without collision; old saves migrate defaults once, new saves preserve deletions; filters hide world/palette and exclude hidden objects from picking; UI wheel scrolls palette at both limits without zoom, outside wheel still zooms; full Godot checks/Web export and actual browser proof.
## Handoff / Notes
Wall-art order remains separate; current owner request takes priority.
