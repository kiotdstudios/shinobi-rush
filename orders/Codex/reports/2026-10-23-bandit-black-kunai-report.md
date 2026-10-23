# Job Report — Bandit black kunai projectile
- Agent: Codex
- Order: ../2026-10-23-bandit-black-kunai.md
- Date: 2026-10-23
- Final status: REVIEW — local checks complete, reviewed integration/live deployment pending
- Commit / PR: Implementation e900c56 plus whitespace cleanup a4f961d; PR https://github.com/kiotdstudios/shinobi-rush/pull/134 merged as b53651d8f29bf0f07fbacc5323c2b7e7add7cbf7. Original report preceded implementation commit.

## Work completed
Replaced the silver polygon, white blade highlight, red grip/ring and pale motion streak with a Sprite2D using the existing shared assets/weapons/kunai/black_kunai.png. Native pixel scale, nearest filtering, hand-height DRAW_LIFT retained; blade source +X rotates to the fixed throw direction.64px transparent canvas centered with1px vertical correction for blade axis y31. No newly generated art. Physics, speed, damage, hit radius, collision queries, range, throw timing and substitution code unchanged.

## Files changed
scripts/enemy/bandit_kunai.gd presentation; scripts/ci/smoke/bandit-black-kunai-probe.mjs browser QA driver; own order/report. No controller/camera or other agent's changes overwritten. Dedicated codex/bandit-black-kunai branch from main19cfae4.

## Tests performed before commit
Windows, bundled Python/Node/Playwright Chromium, Godot4.7.2console via GODOT_BIN. Commands from the dedicated worktree.

| Command/manual step | Result | Evidence |
| --- | --- | --- |
| Python scripts/ci/godot_ci.py tests --project . --log-dir build/black-kunai-tests | PASS2092,0failed; includes existing projectile hit/evade/substitution/wall-or-range and throw state-machine checks | tests-builtin.log; expected deliberate bad-sheet fixture warning only |
| Python scripts/ci/godot_ci.py export --project . --out ../black-kunai-web --log-dir build/black-kunai-export | PASS debug Web export, no engine/script errors | export.log |
| Node scripts/ci/smoke/bandit-black-kunai-probe.mjs ../black-kunai-web | PASS normal keyboard movement to bandit and retreat, real AI throw animation/frame9 observed,0console/page errors | build/bandit-black-kunai-browser/result.json, states.json, flight-31.png |
| Browser screenshot review | Normal arena/character/throw rendered; procedural silver blade removed from runtime source; existing black texture is native sprite | flight-31.png |
| Python scripts/ci/validate_orders.py; git diff --check after whitespace cleanup | PASS | stdout |

## Issues encountered
Initial QA driver assumed bandit_log is exported as a JavaScript array; the existing hook doesn't expose that field. Corrected to existing bandit_animation/frame fields. Initial stationary approach led to melee instead of ranged AI; QA driver now retreats using actual keys to create a ranged opportunity. Those were harness failures, not projectile-code failures; no AI/gameplay changes made to force a pass. The first diff check flagged trailing blank lines at EOF; removed them in a follow-up whitespace-only commit and rechecked before PR. No physical gamepad tested; this is a visual-only projectile swap.

## Questions for project owner
None.

## Outstanding work / next steps
Commit/push, reviewed PR/CI, merge through existing policy, configured Pages deployment, verify exact live build and repeat browser probe. No live update claimed before deployment.


## Integration and live verification
- PR game CI39990898801 passed native/import/validate/Web export, pre-deploy browser smoke/controls/debug probes and godot-ci-gate; repository checks39990898611 passed. The separate throwaway pipeline self-test39990898659 completed success as well (finished after the normal merge).
- Main CI39992260424 passed import/validate/tests/export, pre-deploy browser checks and Pages deployment. Its separate post-deploy smoke job was still running when this delivery report was finalized; its final conclusion is not claimed.
- Live build-info.json reports b53651d8f29bf0f07fbacc5323c2b7e7add7cbf7. Public URL https://kiotdstudios.github.io/shinobi-rush/?v=b53651d verified2026-10-23 13:15EDT.
- Node scripts/ci/smoke/bandit-black-kunai-probe.mjs https://kiotdstudios.github.io/shinobi-rush/?v=b53651d: PASS actual normal-play keyboard approach/retreat; bandit throw frames0and13 observed; zero browser console/page errors. Screenshot visibly shows the dark kunai between enemy and player; no silver procedural blade remains.
- Evidence: docs/visuals/bandit-black-kunai/live-throw.png and live-validation.json. Flight/hit/substitution behaviors remain covered by the unchanged native suite,2092passes.
- Final report/evidence-only update pushed to delivery branch after implementation merge; does not change the live build.
