# ORDER — Substitution smoke and log animation assets
- Agent: Codex
- Owner: Codex (art)
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/substitution-jutsu-art — https://github.com/kiotdstudios/shinobi-rush/pull/37
- Dependencies: current summoning rolling smoke visual language; Aki gameplay integration

## Objective
Create separate substitution smoke and log animations for a successful timed L2 evade. Smoke conceals the outgoing player, a log replaces them, and the player appears behind the attacker.

## Context / References
Owner's23-frame animated substitution reference and existing approved128px game art. Match current summoning smoke palette, shaded rolling billows and wispy breakup.

## Scope / Files owned
Independent departure smoke, curling smoke ribbons, arrival wisps,128px log reveal/tumble/bounce/settle, metadata/source, normal/half-speed previews and Aki handoff. No movement/combat/camera/state-machine implementation. Preview uses an explicitly labeled attacker marker, not a new enemy character or evidence of implemented gameplay.

## Deliverables
Transparent independent clips, frame timings/pivots, conceal/reveal/log-contact event recommendations, source receipts, contact sheet, tested browser/mobile review and PR.

## Acceptance Criteria / Tests
Smoke consistent with summoning; recognizable wooden log at native game pixel scale; clean alpha, stable roots, no baked shadows/terrain/character/VFX across layers, no missing or duplicate drawn frames. Preserve production sprite library/controllers. Provide collision-aware behind-attacker placement requirements to Aki without changing gameplay code. Asset audit, Godot import and independent-layer/browser checks.

## Handoff / Notes
Trigger only on confirmed timed evade success, not any L2 press. Gameplay owns validity, i-frames, relocation and safe landing position. Art timing proposals do not set gameplay balance.

Assets and choreography previews delivered; see reports/2026-10-20-substitution-jutsu-art-report.md. Aki engineering order queued separately; no gameplay implementation claimed.
