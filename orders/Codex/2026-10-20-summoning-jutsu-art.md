# ORDER — Summoning jutsu art preview
- Agent: Codex
- Owner: Codex (art)
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/summoning-jutsu-art
- Dependencies: approved128px player; no runtime controller dependency

## Objective
Hand signs, forceful single-palm ground slam, large black summoning contract spreading over the ground, then delayed smoke. Leave summon content empty for future use.

## Context / References
Owner's summoning reference image and request. Preserve approved character appearance and elevated three-quarter camera.

## Scope / Files owned
One SE art preview. Separate character/sign/slam clip, ground contract clip and smoke clip with independent timing/pivots. Native128px character and larger unscaled VFX canvases. No gameplay/movement/combat/camera changes or runtime manifest replacement.

## Deliverables
Transparent independent clips, timing/ground-contact metadata, source receipts/recipes, full and half-speed loops, labeled contact sheet and browser layer review.

## Acceptance Criteria / Tests
One hand visibly contacts ground; other hand stays off ground. Seal large and legible in close gameplay view, laid flat on ground, black marks without baked terrain/shadow. Smoke delayed until after seal reveal and exported separately with future spawn anchor. Stable player scale/origin, sharp pixels/alpha, no clipping, Godot import and browser/mobile checks, job report and PR.

## Handoff / Notes
Art-only delivery. Future summon should appear at smoke/contract ground anchor; no creature/object is included. Final visual review required.

Independent clips and full/half-speed previews delivered. See reports/2026-10-20-summoning-jutsu-art-report.md for tests and integration notes.
