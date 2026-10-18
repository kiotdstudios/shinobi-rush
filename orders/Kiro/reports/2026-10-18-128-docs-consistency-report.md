# Job Report — Remove contradictory 64x64 production guidance (128x128 is final)
- Agent: Kiro
- Order: Owner instruction "128x128 RGBA is the final locked production sprite standard. Remove contradictory 64x64 production guidance. Keep 64x64 assets only as non-production references." (follow-up to Kiro Order 01 workstream; no separate order file)
- Date: 2026-10-18
- Final status: Docs change complete; local validation and CI green on the PR head; independent review: see the PR (merge by the orchestrator)
- Commit / PR: [PR #7](https://github.com/kiotdstudios/shinobi-rush/pull/7). Commits on the branch: a1bdc81 (job report), 9e8dd9b (the 11-file docs change), 1413943 (clean merge of origin/main 0f01f81 into the branch). CI on head 1413943: [Godot CI run 39153583020](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39153583020) and [Repository checks run 39153583025](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39153583025), all jobs success (Deploy and Post-deploy skipped by design on a PR).

## Work completed
Docs-only change. Rewrote guidance that treated 64x64 as a production candidate, default or pending comparison so it states the locked 128x128 RGBA standard (standing height about 100-112 px) and links to the FINAL OWNER DECISION in orders/README.md instead of duplicating it. Removed the superseded "64x64 and 128x128 are both candidates ... seek owner approval before bulk animation generation" text and the "Pixel dimensions - 64x64 vs 128x128" comparison section content. Kept still-valid guidance: PixelLab skill/API review before a batch, test at actual gameplay zoom, Godot Web texture/performance review. World-tile scale statements derived from the 64 px canvas now say the scale is provisional, set against the 128x128 character in the in-engine test arena, subject to owner approval; no new numbers were invented.

Remaining 64x64 mentions in scope (all intentionally kept): the canonical locked decision text, which says it overrides the earlier 64x64 vs 128x128 evaluation (decision history), in orders/README.md, orders/Aki|Kiro|Orcha|Codex READMEs, orders/Codex/order_01.md, docs/visuals/CAMERA_AND_ART_DIRECTION.md, docs/visuals/PIXELLAB_API_ART_PIPELINE.md and skills/three-quarter-game-art/SKILL.md.

Not touched (out of scope): orders/*/reports/**, assets/**, code/workflows/scripts, orders/Kiro/order_01.md, and the four files rewritten by the stage 3b code PR (docs/prototype/SPRITE_DROP_IN.md, docs/prototype/TESTING.md, docs/development/GODOT_CI_AND_DEPLOYMENT.md, docs/development/GODOT_PROJECT_HANDOFF.md). Known leftover 64x64 wording in those four files is owned by stage 3b.

## Files changed
- docs/GAME_DESIGN_DOCUMENT.md (line 40)
- docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md (line 14)
- docs/visuals/CAMERA_AND_ART_DIRECTION.md (status, line 31, owner revision paragraph)
- docs/visuals/PIXELLAB_API_ART_PIPELINE.md (dimensions section)
- orders/README.md, orders/Aki/README.md, orders/Kiro/README.md, orders/Orcha/README.md, orders/Codex/README.md (owner revision paragraph; Codex README also line 30)
- orders/Codex/order_01.md (line 81, owner revision paragraph)
- skills/three-quarter-game-art/SKILL.md (line 12, owner revision paragraph)
- orders/Kiro/reports/2026-10-18-128-docs-consistency-report.md (this report)

Files owned by other agents with changed lines (please check): orders/Codex/README.md (30, 41), orders/Codex/order_01.md (80 heading, 81, 99), orders/Aki/README.md (26), orders/Orcha/README.md (26), and the Codex-facing art docs docs/visuals/CAMERA_AND_ART_DIRECTION.md (27, 31, 35), docs/visuals/PIXELLAB_API_ART_PIPELINE.md (13-14), skills/three-quarter-game-art/SKILL.md (12, 25), docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md (14).

Removed content worth the owner's attention: docs/GAME_DESIGN_DOCUMENT.md line 40 no longer states a boss canvas size. The old text said "boss 96x96 or 128x128"; 96x96 contradicts the lock and 128x128 is now the standard for production character sprites, so the sentence was replaced by the single locked statement. If bosses need a different canvas, that is a new owner decision.

## Tests run before commit
| Test / command / manual steps | Result | Evidence |
| --- | --- | --- |
| `python scripts/ci/validate_orders.py` | Pass (exit 0) | "Agent READMEs and order structure validated." |
| Re-run of the inventory search over in-scope `*.md` (excluding `orders/*/reports/**`, `assets/**` and the four files owned by the 128x128 code PR). Patterns: `64x64`, `64×64`, `64 px`, `64-px`, `64 vs`, `both candidates`, `pending in-engine`, `scale approval`, `controlled comparison`, `44-52 px`, `32x32 world tile`, `fixed-128px`; widened after review with `owner review`, `subject to owner`, `scale subject`, `pending`, `candidate` | Pass after one fix: the review found a stale heading "scale subject to owner review" at `orders/Codex/order_01.md:80` that the first patterns could not match; it now reads "LOCKED — High-detail character production and fluid animation". No other genuine scale gate remains (the other hits are camera tile geometry that stays prototype-tunable and unrelated TBDs in the world map). A pattern search can only prove absence of the patterns searched. | search output reproduced by the commands above |
| `git diff --name-only origin/main` scope check | Pass: 11 in-scope files, 17 insertions / 17 deletions | git diff --stat |
| Re-check after merging origin/main (PRs #1, #2, #3, #5, #6, #10 had landed) | Pass: no new category-A hits; remaining hits are the LOCKED decision text and the four files owned by the 128x128 code PR | search over in-scope `*.md` excluding `orders/*/reports/**` and `assets/**` |
| `python scripts/ci/validate_orders.py` after the merge | Pass (exit 0) | "Agent READMEs and order structure validated." |
| GitHub CI on PR head 1413943 | Pass | Godot CI run 39153583020, Repository checks run 39153583025 |
| Runtime / Godot build | Not applicable, no code changed (CI still builds and smoke-tests the unchanged project) | n/a |

## Issues encountered
None. Residual 64x64 wording in the four stage 3b files is expected and handled by that PR.

## Questions for project owner
None

## Outstanding work / next steps
- Orchestrator review and merge after CI is green.
- Codex, Aki and Orcha to check the changed lines listed above.
- Live deployment: not applicable (docs only, no runtime impact).
