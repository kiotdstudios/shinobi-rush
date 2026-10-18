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
Codex may use its own proven art-generation skills; **review PixelLab API skills and existing credentials first** and use PixelLab when advantageous, not by default for every asset. **64×64 and 128×128 are both candidates**; test at actual gameplay zoom and seek owner approval before bulk animation generation. See [revised art workflow](../../docs/visuals/PIXELLAB_API_ART_PIPELINE.md). This owner revision supersedes earlier mandatory-PixelLab and fixed-128px wording.
