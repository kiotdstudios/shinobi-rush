# ORDER — Replace the in-game bandit placeholder

- Agent: Codex
- Status: DONE — merged PR45, live build98add79 verified in Chromium
- Priority: P1
- Owner: Codex, explicitly assigned runtime art binding by the owner in chat
- Branch/PR: `codex/bandit-runtime`, https://github.com/kiotdstudios/shinobi-rush/pull/45 (merged)
- Dependencies: Corrected sprint-arms-v3 bandit art from PR38/f1fed19; latest main63bbd6c

## Objective
Owner request: “commit the bandit to replace bandit placeholder in game”. Bind existing red-scarf bandit locomotion to enemies and deliver through normal reviewed CI/deployment.

## Context / References
`orders/README.md`, Codex inbox, project integration/browser skills, existing Bandit/BanditVisual, PR38 corrected art.

## Scope / Files owned
160 existing128RGBA bandit PNGs and import settings, explicit enemy-only art JSON binding, minimal BanditVisual mapping and regression tests. No enemy AI/combat/camera/player selection changes. Dedicated death art is not supplied by this locomotion request; retain existing death fallback.

## Deliverables
Committed art/runtime binding, tested idle/run/eight directions/sprint option, hurt/hitstop/HP preservation, report, reviewed PR, verified live test build.

## Acceptance Criteria / Tests
All eight idle/run/sprint views load at root64,116 with nearest filtering. Run while approaching, idle when stopped; hit reaction freezes/flashes current pose. Enemy set cannot become player's first-valid set. Existing gameplay tests and Web controls pass. Use configured CI/Pages pipeline and verify actual deployed SHA before claiming live.

## Handoff / Notes
Approach defaults to regular run. BanditVisual's `approach_animation` option supports corrected arms-back sprint without changing AI speeds or creating a new state. Dedicated attack/hurt/death art remains separate future work.
