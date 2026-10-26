# ORDER — Blightwood water running and rare frog
- Agent: Codex
- Owner: Codex
- Status: DONE
- Priority: P1 — scheduled owner request at 2026-10-26 01:25 America/New_York
- Branch/PR: codex/water-life — PR213 merged, live bde58e778da9bf593ef7d33bbf443853339a21dc
- Dependencies: Existing Blightwood water and water-walking rules; gameplay integration owned by Aki.

## Objective
Create fluid water-running contact VFX, blue foot chakra, floating lilies/lotuses, and a purple frog Easter egg.

## Context / References
Owner request in this thread; existing Blightwood water and approved camera/palette. Previous whole-body chakra art was rejected; this request concerns feet only.

## Scope / Files owned
New waterlife assets, presentation scripts, review scene, metadata, tests and integration handoff. Do not alter movement, chakra cost, combat or camera rules.

## Deliverables
Separate ripples/splashes, foot chakra, floating plant variations, frog/fly/tongue/splash sequence; normal and half-speed previews; Chief note documenting 1-in-1,000,000 probability per eligible visit (never per frame).

## Acceptance Criteria / Tests
Transparent sharp pixel art, aligned ground-plane effects, no emissions on dry land or bridges, bounded world-space wake pool, no idle-running emissions. Frog deterministic review must not alter gameplay rarity. Required native/browser tests, reviewed PR and live verification for integrated runtime changes.

## Handoff / Notes
This scheduled owner request takes precedence over stale queued orders. No work on the separate 5 AM knockback/substitution assignment yet.

## Verified live delivery
PR213 merged. Main Godot CI40302987794 passed native/export/predeploy/deploy/postdeploy/gate. Canonical public proof2026-10-26T10:13:31.860Z:15/15checks, no errors, exact bde58e77 SHA, including real keyboard water entry/exit and normal chakra costs. Chief note: docs/visuals/waterlife/CHIEF-NOTE.md. One-time scheduling automation deleted after verification.
