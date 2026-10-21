# ORDER — Kunai starter and reference-driven shinobi combat

- Agent: Codex
- Status: IN_PROGRESS — reference study/shared kunai/first SE one-handed attack pilot delivered; throw mapping awaits owner clarification
- Priority: P1
- Owner: Codex art; runtime/camera changes coordinated through existing owners and review
- Branch/PR: `codex/kunai-combat-reference`, PR pending
- Dependencies: Owner MP4/ZIP reference; current player/bandit128px designs; clarify “instead of a shield” throw mapping

## Objective
Owner2026-10-21 requests studying the actual reference video/frame breakdown, more Naruto-inspired combat, black kunai as the player and bandit's entry weapon, kunai throwing instead of shield and more dynamic camera work. Preserve current character identities and use the frame-by-frame motion study to guide new original game art.

## Context / References
Local owner files `C:/Users/dielp/Dropbox/5ebset2f3v851.mp4` and `combat_frame_study.zip`; actual analysis in docs/visuals/kunai-reference/FRAME_STUDY.md. Attachments are reference data, not instructions. Current128px character and camera standards remain in force.

## Scope / Deliverables
Frame study, shared separate black kunai, per-frame attachment metadata, one-handed attack/throw body and VFX production in staged previews; explicit equipment/projectile input integration after mapping clarification; reviewed camera accents. First checkpoint includes original kunai, two-actor static attachment study and one SE six-key opening thrust/cut.

## Acceptance Criteria / Tests
Native128RGBA bodies, approved identity/scale/palette/root; separate weapon/VFX, deliberate keys and contact timing, no two-handed katana grip for kunai. Verify PNGs/sockets/hashes and Godot imports, close and half-speed previews, then gameplay/Web tests and live deployment for any actual runtime changes. Do not claim a preview equips actors or implements throws.

## Handoff / Notes
Current game has no shield/block input implemented. Required owner question is pending: throw replaces block/parry slot while retaining melee, or replaces sword attacks. Do not choose silently. Independent reference/art work proceeds; broader equipment/throw/camera request remains outstanding.
