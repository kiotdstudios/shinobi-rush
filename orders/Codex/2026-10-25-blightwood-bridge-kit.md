# ORDER — Blightwood modular bridge kit
- Agent: Codex
- Owner: Codex
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/blightwood-bridge-kit
- Dependencies: Existing Blightwood palette and 72x36 diamond grid; Aki owns gameplay traversal integration.

## Objective
Create three bridge lengths, end caps, support posts, damaged variant and optional rope version in the matching Blightwood palette.

## Context / References
Owner request 2026-10-25; existing wooden lantern post, grass, shoreline and water assets; camera direction document.

## Scope / Files owned
New assets/environment/blightwood_bridges and docs/visuals/blightwood-bridges; this order and own report. Art and import-ready metadata only. No gameplay, navigation or map changes.

## Deliverables
Transparent modular PNGs, short/medium/long assembled examples, damaged and rope versions, grid sockets/anchors, palette, provenance, contact sheet and integration notes.

## Acceptance Criteria / Tests
Inspect images, validate transparency/dimensions/socket alignment, confirm lengths share a fixed width and grid convention, import resources in Godot, run order validation and diff checks before commit. Submit art PR. Runtime integration remains Aki-owned; label NOT LIVE awaiting integration.

## Verification
584 asset checks passed; 103 PNGs loaded and rendered in Godot; resource validation passed (357 scripts, 24 scenes). See own job report and docs/visuals/blightwood-bridges/godot-render.png. NOT LIVE awaiting gameplay integration.

## Handoff / Notes
Use built-in image generation and deterministic extraction/alignment. PixelLab documentation and configured service reviewed; raw art workflow chosen for modular prop generation. Latest direct priority supersedes stale historical queued work for this turn.
