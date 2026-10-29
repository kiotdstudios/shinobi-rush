# ORDER — Purple ferns and water-plant recovery
- Agent: Codex
- Owner: Codex; direct user assignment (includes presentation logic)
- Status: DONE
- Priority: P1
- Branch/PR: [PR261](https://github.com/kiotdstudios/shinobi-rush/pull/261), merged `5a689112e7ce8c14444cd83ec412348b2dc8cd07`
- Dependencies: integrated foliage PR258/259; preserve water movement/chakra and rare frog rules.

## Objective
Make existing ferns purple and make lilies/lotuses settle back onto the water at varied speeds after the player crosses them.

## Context / References
Owner reviewed the live Blightwood riverbank editor. Preserve approved fern silhouettes and native pixels, vine colors, water scale/palette and diamond grid.

## Scope / Deliverables
Native runtime color variant for all three ferns, matching editor cards/ghosts and previews; water-plant contact dip/tilt/drift with bounded individually paced recovery. Existing ground anchors and water surface elevation remain authoritative. Provide tests, browser evidence, normal/half-speed previews, reviewed PR and canonical deployment verification.

## Acceptance Criteria / Tests
Ferns render purple in game and editor without raw-art regeneration. Vines unchanged. Wet reached movement disturbs plants; dry/idle/air/teleport and different-elevation movement do not. Repeated contact stays bounded, recovery continues after leaving water, rates differ deterministically, anchors/water tier never accumulate drift. Preserve chakra costs, controllers, frog rarity and pool bounds. Run native/resource/export/browser checks before commit and exact live checks after deployment.

## Handoff / Notes
Only cosmetic/presentation behavior and related editor appearance are owned here. Original PNGs/provenance stay intact; purple is an editable engine color setting, not newly generated bitmap art. No new art generation/API charge is needed.

Completion: canonical build verified 2026-10-29T19:35:39.574Z; 16 live feature checks and main deploy/post-deploy smoke passed. [Completion report](reports/2026-10-29-purple-ferns-lily-recovery-report.md).
