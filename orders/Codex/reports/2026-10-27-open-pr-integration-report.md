# Job report — scheduled open-PR integration
- Agent: Codex
- Date: 2026-10-27 America/New_York
- Order: `orders/Codex/2026-10-27-open-pr-integration.md`
- Status: REVIEW — final combined native/import/resource/Web checks passed; required integration CI/deployment pending. NOT LIVE.
- Branch / PR: `codex/2026-10-27-pr-integration`; implementation/conflict-resolution merge `3ea04dc0`, source-ancestry-only merge `a55833ad`; [PR231](https://github.com/kiotdstudios/shinobi-rush/pull/231).

## Review and work completed
Inspected all nine open PRs, exact heads, descriptions, changes, review threads and CI. Existing worktree was clean on `codex/ground-dirt-transitions`; its branch/source commits are preserved. Started the integration branch from current main `46a01f1006407d3b6239fbd82a74d2cf1a9bb318`.

| Source PR | Decision / integration scope |
| --- | --- |
| 226 | Natural dirt parent integrated into candidate first. Native/Web evidence reviewed; no outstanding review comments. |
| 230 | Companion transition kit integrated after parent; main's PR225 stair fixes retained byte-for-byte. |
| 35, 36 | Isolated running-jutsu and summoning source/art previews archived. No production character manifest/controller promotion or false visual-acceptance claim. |
| 176 | Non-canon story idea bank only; locked lore/progression remains untouched. |
| 220 | Verified historical live-mist documentation/evidence only; original date/SHA retained. |
| 227 | Aki cliff-kit specification only. Merging the document does not deliver or approve unfinished cliff art/runtime work. |
| 228 | Smoke visibility, existing bandit-world/belt/crew work and rock-base cleanup reviewed; conflicted against current main. Resolved in candidate, retaining latest stairs and new path catalog. |
| 229 | Small inventory-drop feature reviewed and fixed. Patch included in combined tests; source-head ancestry recorded after verification that the merge leaves the tested runtime tree byte-identical. |

Direct normal merge of PR226 returned HTTP405: **2 of 2 required status checks expected**. Read the active ruleset: required checks bind to GitHub Actions app15368, and strict up-to-date policy is enabled. Actual named head checks were successful, but PR226 was behind current main. The integration candidate starts at current main and will get fresh checks for the complete combined tree. No rule or check bypass, status spoofing, force push or direct main write.

## Fixes / implementation decisions
- Resolved map prop nudges from Aki's collision fixes; preserved latest stair/ledge geometry and collider behavior.
- Retained combined builder catalog (ryo, both stair directions and 48 transition pieces).
- Retained layout-based nav and added Aki stair/bridge routes; crew-aware combat uses the shared same-level predicate.
- Removed a duplicate Bandit elevation declaration created by the merge, which caused parse errors, and a duplicated per-frame elevation update that would advance climbing twice.
- Found PR229 drops at 28 px inside the 40 px pickup radius, causing immediate reacquisition when facing east/west. Dropped items now exclude only their owner until that owner leaves the radius; returning or another fighter can collect normally. Invalid item/out-of-tree drops fail safely before consuming inventory.
- Incoming variable-value RyoPouch used a code-drawn placeholder although approved animated art already exists. Its display now reuses the approved `HealthGourd` ryo layers; its existing amount/crew/grace/elevation logic remains authoritative. The visual child is excluded from pickup groups and auto-collection, preventing duplicate fixed-value rewards.
- Added a regression test for the actual overlap→leave→return flow and approved pouch art/single pickup identity.
- Normalized CRLF in the source-shape vision guard; the first full run's only failed assertion was a line-ending-sensitive text search, not changed perception order. The guard still verifies the same state ordering.
- Opt-in read-only inspection and actual UI browser probe cover real Inventory Square input, dropped kunai recovery, four live bandits/two crews, and three smoke banks with active cover.

## Tests performed before final implementation commit
Pinned Python and Node from `C:/Users/dielp/.cache/codex-runtimes/codex-primary-runtime/dependencies/`; pinned Godot primary `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`. Workdir `.tools/ground-mist`.

| Command / step | Result | Evidence |
| --- | --- | --- |
| PR metadata / CI / threads / ruleset reads | All nine reviewed; eight heads had successful workflows, PR228 head had no runnable PR workflow due conflicts; no open review threads | `docs/reviews/2026-10-27-open-pr-audit.json` |
| Initial import | Failed on duplicate Bandit elevation after auto-merge; corrected before any implementation commit | `build/pr-integration/import` |
| Corrected import | PASS | `build/pr-integration/import-fixed` |
| Focused inventory/drop/smoke/crew tests | 154 assertions passed, but dummy-renderer texture initialization errors occurred on first tag-bomb frame load; not classified as a clean pass | `build/pr-integration/focused.log` |
| First full `godot_ci.py tests` | 3875 passed, 1 failed; no engine errors. Sole failure: CRLF-sensitive perception source guard; fixed without weakening semantics | `build/pr-integration/tests/tests-builtin.log` |
| `python scripts/ci/godot_ci.py import --project . --godot <pinned> --log-dir build/pr-integration/import-final` | PASS | local log |
| `python scripts/ci/godot_ci.py tests --project . --godot <pinned> --log-dir build/pr-integration/tests-final` | **3876 passed, 0 failed**, no engine errors; only intentional malformed-sprite warning | full local log |
| `python scripts/ci/godot_ci.py validate-resources --project . --godot <pinned> --log-dir build/pr-integration/validate` | PASS: 421 scripts, 30 scenes, 2 resources, zero failures | local log |
| `python scripts/ci/godot_ci.py export --project . --out ../pr-integration-web-20261027 --godot <pinned> --log-dir build/pr-integration/export` | PASS local debug Web export, unknown SHA, explicitly not live | local log |
| `node scripts/ci/smoke/pr-integration-probe.mjs --serve-dir ../pr-integration-web-20261027 --out-dir docs/reviews/2026-10-27-integration-gameplay` | **6/6 PASS**; real keyboard menu Square, drop remains inside pickup radius, walking away/back recovers it; four bandits/two crews; three visible smoke banks/active cover; zero browser/engine errors | screenshots/result JSON, UTC 2026-10-27T08:05:10.369Z |
| `python scripts/ci/validate_orders.py`; `python scripts/ci/validate_sprite_manifests.py`; `git diff --check` | PASS | local output |

## Issues encountered
Strict branch freshness prevented direct PR226 merge. Used an ordinary integration candidate based on current main, preserving original source ancestry, to validate the actual combined state. Other issues and exact fixes are listed above. No source PR has been closed or discarded merely to clear the list.

### Required CI first attempt and tested tooling correction
[Run 40471465492](https://github.com/kiotdstudios/shinobi-rush/actions/runs/40471465492) imported, validated, passed native tests, exported and passed the standard browser smoke with zero fatal errors. The controls probe failed three vision assertions because it still required exactly one bandit, while PR228 intentionally adds three rivals. Actual output showed four bandits, one shared overlay node, zero AI/overlay disagreements, successful cleanup, and zero browser errors. Corrected both exact-count checks to require the authored four bandits; retained the 12 toggle cycles, strict node cleanup and AI agreement checks. No runtime code or test thresholds changed. Full corrected local Web controls probe must pass before this tooling correction is committed.

Before committing the correction, ran `node scripts/ci/smoke/controls-probe.mjs --serve-dir ../pr-integration-web-20261027 --out-dir build/pr-integration/controls-corrected`: full probe **PASS**, including all 12 ON/OFF cycles, four visible bandits, no node leaks and zero console errors. Evidence: `docs/reviews/2026-10-27-integration-gameplay/controls-result.json`. `node --check`, orders validation and `git diff --check` also passed. Runtime export bytes are unchanged; the already-passed 3876-assertion native suite remains applicable.

## Questions for project owner
None currently; existing instructions and repository evidence resolved implementation choices.

## Outstanding work
All nine exact source heads verified as ancestors; source-ancestry recording did not alter tested scripts/tests. Push reviewed integration PR, wait required CI, normal merge, verify main deploy/postdeploy and exact canonical browser build. Delete the one-time automation only after this pass has a terminal outcome; no daily repetition.
