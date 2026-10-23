# ORDER — Charge-body revision for player and bandit
- Agent: Codex
- Status: REVIEW
- Priority: P0 direct owner request
- Owner: Codex art
- Branch/PR: codex/charge-body-revision
- Dependencies: owner rejects V2 VFX; confirms player and bandit

## Objective
Create the charging-body animation shown by the owner's pose reference for both existing characters. Archive rejected V1/V2 effects on Desktop for later standalone giveaway.
## Context / References
Wide planted bent-knee stance, joined vertical ninja hand seal at sternum, elbows out, controlled symmetric chest/shoulder tension. Existing approved128px identities and three-quarter camera. No VFX redesign in this order.
## Scope / Files owned
Body-only charge art/metadata/previews for both skins; eight direction labels; original S/SE/E/NE/N poses with native western mirrors where appropriate. Separate new art review package; no movement/combat/AI/camera controller edits or resurrecting rejected VFX. Archive packaging, verification and rejected-PR metadata.
## Deliverables
Both character body sets, normal/half-speed side-by-side review with all headings, fixed(64,116) feet and consistent anatomical scale. Desktop V1/V2 standalone VFX folders/ZIPs plus private original archive, excluded character/reference imagery from public bundles.
## Acceptance Criteria / Tests
Readably correct seal/arms and wide squat; stable grounded feet; no left/right rocking, no backpack cloth swing;128x128 RGBA; native sprite/QC/import and preview playback checks; provenance/report and art PR. Verify Desktop archive bytes before relocating sources.
## Handoff / Notes
Builtin image generation for authored poses, deterministic extraction/registration only. PixelLab reviewed read-only; built-in reference workflow chosen for design/anchor matching. Old rejected VFX remain outside new body review. Owner clarified 'builder' meant bandit.

Completed body-only art review package and verified Desktop archive. Automated native/frame/browser checks pass; see reports/2026-10-23-charge-body-revision-report.md. Await owner visual review before runtime binding. Live deployment: not applicable to this unbound art candidate.
