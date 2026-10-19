# Kiro — Orders

This is **Kiro's dedicated work-order inbox**. Read [shared rules](../README.md) before starting.

Only take orders explicitly assigned to **Kiro**. Create separate dated Markdown orders here; update their statuses and attach commits/PRs and test evidence.

**Current status:** No new orders assigned by this folder setup.


## Mandatory completion process
Before **any implementation commit**, run relevant tests and playtest changed gameplay, record actual results, and fix failures. After **every job** (including blocked work), write a report in `orders/Kiro/reports/YYYY-MM-DD-task-name-report.md` detailing work done, files changed, pre-commit tests/results, issues, questions, outstanding tasks, and commit/PR link. **Read and follow the full mandatory policy and report template in [shared orders README](../README.md).** Do not mark work DONE without a report and verified tests.


## Start immediately and publish to live testing
When you read a `QUEUED` order assigned to you, **start it immediately without another prompt**. After testing and committing, integrate using the shared PR/branch process and **publish gameplay changes to the live browser test build automatically**. Open the deployed game and verify the change, then record the live build URL/version, result, issues, and questions in your report. See [master execution and deployment policy](../README.md). Do not mark DONE if the live build was not verified (unless deployment is genuinely not applicable).


## Premium roguelike-inspired game vision
**Required reading:** [Shinobi Rush quality and inspiration brief](../../docs/vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md). Aim for premium AAA-level polish in combat, animation, VFX, enemy readability and replay appeal. **Do not change the locked persistent RPG progression, world layout, death/save rules, or add permadeath/procedural run resets without owner approval.**





## Owner revision — PixelLab skill review and art scale
Codex may use its own proven art-generation skills; **review PixelLab API skills and existing credentials first** and use PixelLab when advantageous, not by default for every asset. Sprite frame size is locked at 128×128 (see the FINAL OWNER DECISION below); test at actual gameplay zoom before bulk animation generation. See [revised art workflow](../../docs/visuals/PIXELLAB_API_ART_PIPELINE.md). This owner revision supersedes earlier mandatory-PixelLab wording.


## FINAL OWNER DECISION — Production sprite frame size (2026-10-18)
**LOCKED: All standard production character sprite frames MUST be 128×128 pixels, RGBA with transparency.** This overrides any earlier 64×64 vs 128×128 evaluation or scale-approval requirement in this file or linked orders. Do not create 64×64 production character sprites. Legacy 64×64 artwork may be retained as reference only. Larger canvases may be used for attacks/VFX extending outside the base frame, but keep the character's world-space/body scale, proportions, foot anchor and alignment consistent. Maintain eight-direction animation targets and premium fluid motion. PixelLab remains optional after mandatory skill/API review as separately documented.


## Chief report after every task (standing rule, owner instruction 2026-10-18)
The project owner asked for a chief-facing document for every finished task: "put all of this in a doc for the chief to review; if not, make this a rule after every task." Kiro, as orchestrator, writes it **after the live result is verified** and **before** telling the owner a task is complete. A "task" is any unit of work reported on: a PR or group of PRs merged, an investigation closed, a deployment verified, a review of another agent's PR, or a batch the owner asked for. A small task gets a short report (10 to 20 lines), never none.
- **File:** `orders/Kiro/reports/YYYY-MM-DD-chief-<topic>.md`, one per task, plus a one-line entry (newest first) in [`reports/CHIEF_INDEX.md`](reports/CHIEF_INDEX.md).
- **Shipping:** a docs-only branch and PR from a git worktree (not the shared clone, never straight to `main`); `godot-ci-gate` must be green; then merge.
- **Not the job report:** workflow agents write the per-job report in the [shared template](../README.md). They do not write the chief report and do not set an order to DONE; the orchestrator does both after its own live verification.
- **Contents, in this order:** (1) final status per assignment, DONE only with verification evidence; (2) what was completed, with a PR table; (3) evidence and test results, every claim labelled VERIFIED or ASSUMED; (4) live verification when runtime-visible (URL, `build-info.json` commit equals the merge commit, screenshots actually opened, post-deploy smoke result); (5) changes made outside code, with how to reverse each; (6) findings about other agents' work and hazards; (7) judgment calls the chief may overturn; (8) what was not verified, said plainly; (9) numbered questions for the chief, each with a recommendation; (10) comments and recommendations; (11) next steps; (12) where to look.
- **Final message to the owner:** the path of the chief report, the PR that carries it, and whether that PR is merged. If it is not merged yet, the task is not fully closed.
