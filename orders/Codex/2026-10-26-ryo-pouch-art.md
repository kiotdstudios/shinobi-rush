# ORDER — Classic ryo pouch pickup art
- Agent: Codex
- Owner: Codex (art); Aki (future backend integration, per owner)
- Status: REVIEW
- Priority: P1
- Branch: codex/ryo-pouch
- Dependencies: approved generic pickup timing and owner mockup

## Objective
Create the mockup's brown leather pouch, red drawstring and gold square-hole coin, with the same float, glow, sparks and collection animation treatment as existing pickup items.

## Context / References
Owner attachment A1C295A5-F87E-4179-9810-A882FDDA1527/1-Photo-1.jpg. Existing HealthGourd art and GourdPickupFx timing are reference only.

## Scope / Deliverables
Art and animations only: transparent body and independent golden VFX, animation resources / manifests, normal and half-speed previews, source provenance and Aki integration notes. No pickup registration, currency rewards, inventory, spawning, input, gameplay/controller or main-scene changes. This explicit scope supersedes automatic runtime integration for this art handoff.

## Acceptance Criteria / Tests
Consistent three-quarter pixel-art style; fixed canvas / anchors; matching pickup scale; no background or floor shadow baked into body; separate glow and sparks; clean unique frames and Godot resource import. Inspect contact sheets and full animation previews. Commit / push art PR and job report. Live gameplay deployment not applicable until Aki integrates the art.

## Verification
All art QA and Godot resource import checks passed. Five animation tracks, 60 source textures, separate gold VFX, normal/half-speed previews and Aki handoff ready. Live deployment is not applicable to this explicitly art-only assignment.
