# Two-tier CI completion audit — order PR238

The implementation is already merged in PR239 (`08cb2e3e`, smoke-fixture compatibility fix `c6378c6c`). No workflow or required-check settings need replacement. This audit closes the stale specification without pretending it is implementation.

## Measured results

Successful main runs; wall time is run_started_at to final job completion and includes setup/queue gaps. Hardware/load and suite size vary; this is observational, not a controlled benchmark. P90 uses linear interpolation. All sampled deploy and post-deploy jobs passed.

| Tier | Run | SHA | Wall time |
|---|---|---|---|
| fast | [40624435792](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40624435792) | `4c79fda6` | 15m 26s |
| fast | [40621591903](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40621591903) | `7fa1a167` | 15m 57s |
| fast | [40613332981](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40613332981) | `7a4cf8b5` | 12m 33s |
| fast | [40599315528](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40599315528) | `28a46f18` | 13m 19s |
| fast | [40595087133](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40595087133) | `bf96f014` | 13m 40s |
| baseline | [40540318653](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40540318653) | `bbf06b88` | 30m 4s |
| baseline | [40524470044](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40524470044) | `0564d371` | 30m 59s |
| baseline | [40477062807](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40477062807) | `c4c33696` | 30m 0s |

Baseline (3 runs): median **30m 4s**, p90 **30m 48s**. Fast tier (5 runs): median **13m 40s**, p90 **15m 45s**. Median reduction: **54.5%**. Raw per-job/per-step timings: `ci-benchmark.json`.

**The 7–10 minute aspiration is not achieved.** Native suite/build growth and browser/setup time now dominate; no checks were removed to manufacture that target. Follow-up performance work can reduce these costs while keeping correctness. The two-tier architecture and its required acceptance checks are complete.

## Architecture verified

- Fast path retains import, resource validation, full native tests, one Web export, essential browser smoke with real movement, deploy of those exact bytes, and exact-SHA post-deploy smoke.
- Comprehensive controls/debug probes run separately on nightly 07:00 UTC, workflow_dispatch, and release tags. Release procedure requires their green exact-SHA result.
- Example same-head verification: fast Godot run **40620237089** and full regression **40620237087**, both on `6c9a332cc87c16ca73e7b883b80e96d51123e0bc`, all passed. Main deployment run **40621591903** verified the merged runtime SHA and post-deploy smoke; its source tree matches that tested head.
- Existing required checks remain `validate-orders-and-project` and `godot-ci-gate`, active strict mode. No permissions, protections, SHA checks or deployment gates are bypassed. PR builds do not deploy.
- Stale documentation describing comprehensive probes as part of pre-deploy has been corrected. Full probes, failure artifacts and release gating remain intact.
