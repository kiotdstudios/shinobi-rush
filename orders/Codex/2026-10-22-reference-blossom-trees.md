# ORDER — Five reference blossom trees and independent falling foliage

- Agent: Codex
- Status: IN_PROGRESS
- Priority: P0 — direct owner request
- Owner: Codex (environment art and decorative animation)
- Branch/PR: `codex/blossom-trees`
- Dependencies: current main; supplied five-tree JPEG

## Objective
Place all five exact tree designs supplied by the owner into the live game, preserving their detailed lavender/blue and pink-white blossom clusters, gnarled trunks and stone bases. Animate gentle, fluid wind sway and separately animated falling leaves/petals.

## Context / References
Owner attachment `A2B4F9F0-7B32-4E94-A9E9-C260C0F5638F/1-Photo-1.jpg`, 1280×511. Keep original source pixels where possible; transparent extraction, fixed base anchors, no redesign. Follow camera/art direction. The character 128×128 rule does not reduce larger environment props.

## Scope / Files owned
New environment assets, foliage animation component, tree scene and decorative placement hook. No player/combat/AI/camera changes; preserve traversable lanes and existing navigation. Separate leaves from tree body animation. Current direct request takes precedence over queued character art work.

## Deliverables
Five transparent tree assets, documented wind cycle/frame timing, separate detailed tumbling foliage assets, independent falling-foliage component, in-game placement and normal/half-speed review route, previews/contact sheet, QA manifest, job report and reviewed PR/live verification.

## Acceptance Criteria / Tests
All five reference silhouettes remain recognizable at gameplay zoom. Roots/rocks stay fixed while canopy and branch tips sway. No clipping, white rectangles, obvious loop seams or synchronized identical motion. Falling foliage starts from canopies, sways/tumbles and fades at ground independently. Confirm Y sorting, safe placement, bounded particles and browser performance. Godot import/resource tests, relevant automated tests, Web export, live browser keyboard/mouse checks and exact deployed SHA.
