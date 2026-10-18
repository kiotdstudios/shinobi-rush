# Kiro — Orders

This is **Kiro's dedicated work-order inbox**. Read [shared rules](../README.md) before starting.

Only take orders explicitly assigned to **Kiro**. Create separate dated Markdown orders here; update their statuses and attach commits/PRs and test evidence.

**Current status:** No new orders assigned by this folder setup.


## Mandatory completion process
Before **any implementation commit**, run relevant tests and playtest changed gameplay, record actual results, and fix failures. After **every job** (including blocked work), write a report in `orders/Kiro/reports/YYYY-MM-DD-task-name-report.md` detailing work done, files changed, pre-commit tests/results, issues, questions, outstanding tasks, and commit/PR link. **Read and follow the full mandatory policy and report template in [shared orders README](../README.md).** Do not mark work DONE without a report and verified tests.


## Start immediately and publish to live testing
When you read a `QUEUED` order assigned to you, **start it immediately without another prompt**. After testing and committing, integrate using the shared PR/branch process and **publish gameplay changes to the live browser test build automatically**. Open the deployed game and verify the change, then record the live build URL/version, result, issues, and questions in your report. See [master execution and deployment policy](../README.md). Do not mark DONE if the live build was not verified (unless deployment is genuinely not applicable).
