# ORDER — L2 chakra charge integration
- Agent: Codex
- Owner: Codex, direct owner assignment for integration
- Status: IN_PROGRESS
- Priority: P0
- Branch/PR: codex/charge-body-revision / PR126
- Dependencies: owner confirms preserve substitution press, add L2 hold charge

## Objective
Hold L2 to charge chakra using approved body art; defer VFX.
## Context / References
Owner2026-10-23 explicitly requests runtime integration. Approved player/bandit charge assets. L2 currently substitution; asked owner whether tap/hold or charge-only with Q substitution.
## Scope / Files owned
Player input/state, animation manifests, controls labels/telemetry, relevant tests. Body art already reviewed; no VFX work or enemy AI balancing.
## Deliverables
Grounded body charge, chakra recovery, release and action/hit interruption,8 headings, tested browser build, reviewed PR and live deployment verification.
## Acceptance Criteria / Tests
Correct L2 behavior per owner clarification, planted feet, half-speed looping charge, no aura, chakra caps at maximum; no attack/jump/dodge regressions. Native regression suite, Web export and real browser input checks. Report before implementation commit.
## Handoff / Notes
Direct user instruction authorizes integration touching player systems. Preserve other agent work and use reviewed PR pipeline.

Owner confirmed existing press substitution must remain unchanged. Added0.30second hold on existing substitution input; no changes to substitution press/window/charges. Final native regressions and browser export checks in progress; see own report. No aura work.
