# Shinobi Rush — playable combat by Saturday October 24, 2026

**Owner outcome:** On the official browser game, player and Level 1 Bandit engage in real fast ninja combat with kunai, Body Flicker, fair AI, visible detection and testable wall/arena interactions. **Aki is integration lead**; Codex art, Orcha VFX, Kiro debug/camera. No feature expansion before core loop works.

| Day | Owner | Required playable checkpoint |
| --- | --- | --- |
| Thu Oct 22 | Aki + Codex | Normal arena **J** visibly uses kunai attack sprites and damages Bandit; Bandit attack states/vision are verified; Kiro cone debug integrated. |
| Fri Oct 23 | Aki + Orcha + Codex | Space dodge Body Flicker, optional two-hit double backward retreat; Bandit red-scarf kunai attacks with real art and can hurt player; Bandit uses flicker. |
| Sat Oct 24 | All; Aki lead | Live integrated fight: spot/chase/robber threat/attack/counter/dodge/double flicker/re-engage; collisions/LOS, hits, recovery, controls, no crashes; smoke and evidence. |

## Definition of Saturday basics
- Player attack key triggers correct kunai art **in normal gameplay**, not just a proof query; hits register on Bandit.
- Bandit spots player according to actual LOS, closes, **attacks player with kunai art**, damages player and can evade/flicker. Level 1 remains intentionally predictable.
- Both share **core ninja capabilities** and animation state contract; don't equate AI skill with available abilities. Full eight-direction bespoke art can follow SE MVP with safe fallbacks.
- Actual Bandit vision overlay toggle, walls block sight and movement, arena starts opposite sides.
- One live build https://kiotdstudios.github.io/shinobi-rush/ with documented controls, commit SHA and recorded real-browser test.
- No forced combo retreat, no new inventory/economy, no RPG progression changes.

## Mandatory integration cadence
For every **meaningful tested increment**: test locally → commit → **push remote branch** → PR + required checks → merge to main → deploy → verify public live build → post evidence/links. Do not claim an order is delivered because code exists only locally or in an unmerged PR. Don't bypass branch protections or claim CI passed without checking. Report blockers immediately, no parallel conflicting file edits. Saturday is a target, not permission to ship broken code. Freeze new gameplay scope Friday evening; Saturday reserved for integration, playtesting, fixing regressions.
