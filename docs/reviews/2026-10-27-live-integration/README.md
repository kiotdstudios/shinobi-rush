# Verified canonical integration — October 27, 2026

- Site: https://kiotdstudios.github.io/shinobi-rush/
- Verified runtime: `c4c336964e42e73a59b0b2984aa9aae57e4f15be`, merged [PR231](https://github.com/kiotdstudios/shinobi-rush/pull/231).
- [Main pipeline](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40477062807): all jobs succeeded, including deploy and postdeploy. Exact jobs in `main-jobs.json`; filtered actual check logs in `predeploy-checks.txt` and `postdeploy-checks.txt`.
- All nine original PRs (35, 36, 176, 220, 226, 227, 228, 229, 230) automatically marked merged; none discarded. Isolated art studies were not promoted to production animations. Cliff order is a specification, not delivered cliff art.
- `gameplay/`: 7/7 actual live checks, includes exact `build-info.json`, Square inventory drop/owner grace/recovery, four bandits/two crews and animated smoke cover. Zero engine/browser errors.
- `natural-path/`: 9/9 actual live checks, same-camera before/after and real movement. Both views have 3154 floor/object entries and 103 obstacles. The before switch disables the new natural-path presentation on the same build; it is not a different historic deployment.
- `path-dirt/`: 4/4 actual live checks, 121-tile temporary demo in the actual map, dedicated builder filter and player movement. Zero errors.
- Screenshots are from the canonical game, not an illustrated concept or local export. JSON files contain exact UTC capture times and telemetry.

Final report: `orders/Codex/reports/2026-10-27-open-pr-integration-report.md`. This proof follow-up only changes documentation/evidence; no runtime assets or logic.
