# ORDER — Red-scarf bandit idle/run/ninja sprint
- Agent: Codex
- Owner: Codex (art)
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/bandit-locomotion — https://github.com/kiotdstudios/shinobi-rush/pull/38; art commit e211daeb02bf461c1754daf8e91fe4c299660aa7
- Dependencies: owner appearance reference; approved128px game style; Aki enemy integration

## Objective
Create bandit enemy using owner's masked red-scarf/topknot reference, with NO logos/emblems anywhere. Deliver idle, normal pumping-arm run and distinct forward-leaning arms-back ninja sprint in existing eight directions.

## Context / References
Owner's3-view Photo1.jpg. Plain deep-red CLOTH headband, no engraved metal plate or symbol. Masked face, tan skin, black hair/topknot, tattered red scarf/sash, charcoal clothing/mesh, wraps, hip pouches and sandals. Elevated three-quarter overhead game camera; native128×128 RGBA and standing scale comparable to104px player.

## Scope / Files owned
New assets/characters/bandit/ art/source/metadata and previews. No player sprites, enemy AI/combat, state machine or camera edits. Hit/death/attack animations not in this request. Runtime SpriteLibrary recursively scans all *.manifest.json under characters: use opt-in bandit_128.art.json until Aki integrates, to prevent accidental player auto-selection.

## Deliverables
8-direction design views, idle/run/sprint loops, native transparent frames, direction/root/FPS metadata, normal/half-speed review, contact sheets, source receipts and Aki integration notes/report/PR.

## Acceptance Criteria / Tests
No logos or marks on headband/clothes; distinct bandit identity; stable size/root/direction; breathing idle without body sway; run has alternating arm/leg action; sprint arms stay back with forward momentum/scarf follow-through. No baked floor shadow/background, duplicated/missing frames, clipping or blurred/interpolated pixels. Export at128 without shrinking to hide overflow. Audit all directions and loop timing; Godot import, browser/mobile review and order/whitespace checks before commit.

## Handoff / Notes
All24 clips/160motion frames exported; native RGBA/timing/uniqueness checks, Godot160texture load, resource validation, desktop/phone browser review controls and order/whitespace checks passed. See reports/2026-10-20-bandit-locomotion-art-report.md. Owner visual acceptance pending. Live deployment not applicable: runtime binding remains Aki-owned.
Latest owner instruction resolves the earlier Bandit-design approval dependency in combat-v1-animation-request. Only requested locomotion states are authorized in this art phase. Enemy gameplay integration remains Aki-owned.
