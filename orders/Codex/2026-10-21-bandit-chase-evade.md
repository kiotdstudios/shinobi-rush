# ORDER — Bandit locomotion continuity, chase and ninja evade
- Agent / Owner: Codex (owner explicitly assigns behavior integration in current request)
- Status: DONE
- Priority: P1
- Branch: codex/bandit-chase-evade
- Dependencies: approved bandit 128px idle/run/sprint already on main

## Objective
Pause kunai. Analyze reported skipping, enable existing bandit locomotion, pursue detected player and evade player approach or lock-on with original separate dark traversal streak art.

## Context / References
Owner current request; approved red-scarf bandit assets; camera/art direction. Gameplay files overlap Aki ownership; this request explicitly assigns the bounded bandit behavior changes to Codex. No player combat/camera controller edits.

## Scope / Deliverables
Bandit AI and enemy visual continuity, separate six-frame VFX, minimal target toggle/helper and legend, regression/browser tests, animation audit, report, PR and verified live test build.

## Acceptance Criteria
Detect/run/sprint/idle; gait phase retained through turns; evades approaching or locked player with collision/cooldown; hurt/death interrupt; original separate transparent streaks; tests and Web controls pass; integrated deployed SHA verified. No enemy attacks yet.

## Handoff
Kunai work remains paused. Existing run source frame ordering retained after audit; no duplicate PNGs. Runtime restarting and threshold chatter fixed without changing player SpriteActor behavior.

## Verified delivery
PR https://github.com/kiotdstudios/shinobi-rush/pull/52 merged fa85e9399c019f627ceb806f6805f427ed68554f. All CI/deploy jobs passed; independent public-build SHA/hash smoke and actual-keyboard bandit feature probe passed. Full evidence/status in reports/2026-10-21-bandit-chase-evade-report.md. Live: https://kiotdstudios.github.io/shinobi-rush/?camera=close&v=fa85e93
