# ORDER — Blightwood ground mist
- Agent: Codex
- Owner: Codex (art and presentation integration, explicitly requested by owner)
- Status: REVIEW
- Priority: P1
- Branch: codex/ground-mist
- Dependencies: current Blightwood trees and DynamicShrine; no gameplay changes

## Objective
Thin wisps move between trees and around the Ancient Shrine, adding depth without obscuring the player.

## Context / References
Existing Blightwood grey-green stone, blue wisteria, three-quarter camera and diamond ground scale.

## Scope / Deliverables
Original transparent mist atlas, bounded presentation-only drifting wisps, automatic tree/shrine attachment discovery, player readability fade, normal/half-speed review and integration notes. Preserve other pending work in the dynamic-shrine checkout.

## Acceptance Criteria / Tests
Low-opacity ground-level mist; visible negative space; smooth looping drift; player silhouette readable; no movement/combat/camera changes. Native resource/tests, Web export, actual browser review, reviewed PR, canonical live verification and job report.

## Pre-commit verification
3,441 native tests passed, 15 focused mist tests, 14 mist browser checks, 36 controls probe checks, successful Web export and resource validation. Job report: reports/2026-10-26-ground-mist-report.md. Reviewed integration and canonical live verification pending.
