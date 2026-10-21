# Job Report — Bandit placeholder replacement

- Agent: Codex
- Date:2026-10-21
- Order: `orders/Codex/2026-10-21-bandit-runtime-replacement.md`; explicit owner assignment in chat
- Final status: IN_PROGRESS — local checks passed; integration/live verification pending
- Commit / PR: Not committed when this pre-commit report was written

## Work completed
Copied160 corrected existing128×128 transparent bandit PNGs from art branch f1fed19 (idle32,run64,sprint64), with no body artwork changes. Explicitly loads bandit_128.art.json in BanditVisual through SpriteSet.parse rather than adding it to player-discovered manifests. Shared cached SpriteFrames, nearest filtering, native104px body and root64,116. Approaching movement uses run, stopping uses idle, eight facings. Editor option permits corrected arms-back sprint without changing AI/speed/state behavior. Hurt freezes/flashes current authored pose; hitstop pauses animation and then resumes. HP/name indicators remain above the new sprite. Existing procedural fallback remains for missing art/death; no dedicated new combat/death clip claimed.

## Files changed
Bandit sprite PNGs/import settings and explicit art JSON; scripts/enemy/bandit_visual.gd and a stale-comment update in bandit.gd; tests/test_bandit_art.gd and runner registration; owner order/report and browser screenshot/results in docs/visuals/bandit-runtime. Isolated .tools/bandit-runtime checkout from current main63bbd6c; primary dirty checkout untouched. No Aki combat state changes, camera changes, player sprite selection changes or new generation.

## Tests performed BEFORE implementation commit
Windows, Godot4.7.2 stable, bundled Python/Pillow, Node and pinned Playwright Chromium reused via local ignored node_modules junction.

| Exact command / inspection | Result |
| --- | --- |
| `python scripts/ci/godot_ci.py import --project . --log-dir build/bandit-checks` with GODOT_BIN pointing to primary .tools/godot-4.7.2 console executable | PASS; generated bandit PNG import sidecars and new test UID included for commit. |
| `python scripts/ci/godot_ci.py tests --project . --log-dir build/bandit-checks` | PASS603tests/0failures.55new assertions cover actual enemy art binding, all24action/direction combinations, anchors, player selection, stopped approach, hurt, hitstop/resume and death fallback. Existing combat/damage/death/controls tests remain green. Expected negative-test badsheet warning only. |
| `python scripts/ci/godot_ci.py validate-resources --project . --log-dir build/bandit-resources` | PASS35scripts/6scenes/0failures. |
| `python scripts/ci/godot_ci.py export --project . --out ../bandit-runtime-web --log-dir build/bandit-export` | PASS debug single-thread Web export. Initial inside-project output request was correctly refused by exporter guard; retried outside project. |
| `python scripts/ci/godot_ci.py finalize-export --project . --out ../bandit-runtime-web --kind game --commit-sha 63bbd6c16f449d77d3e14e5a4c1afedb80864380` | PASS38MiB local export; local pre-commit metadata labels base snapshot, not deployed revision. Initial command lacked GODOT_BIN; supplied existing executable and succeeded. |
| `node scripts/ci/smoke/smoke.mjs --serve-dir ../bandit-runtime-web --out-dir build/bandit-smoke --label bandit-local` | PASS real Chromium engine start,1280×720 canvas, nine served file hashes, nonblank/input effect, no fatal console. Four software-WebGL warnings. |
| `node scripts/ci/smoke/controls-probe.mjs --serve-dir ../bandit-runtime-web --out-dir build/bandit-controls` | PASS movement, faster sprint, walls, lab/jump/dodge, wide/close camera, player_128 still selected, zero console errors. |
| Close browser preview `?camera=close`, screenshot and visual inspection | Red-scarf bandit rendered next to original player at close zoom1.211538, no page errors. Screenshot docs/visuals/bandit-runtime/close-gameplay.png. |
| Pillow inspection all160PNGs | PASS128×128 RGBA/binary alpha/eight directions per animation; approved original PNGs reused unchanged. |
| `python scripts/ci/validate_orders.py`; `git diff --cached --check` | PASS before implementation commit. |

## Issues encountered
No remaining local failures. Software-rendered headless browser runs slowly; no hardware performance claim. Dedicated death art is missing and retains its prior fallback. Physical gamepad not available; keyboard/browser controls and existing action tests used.

## Questions for owner
None. Owner explicitly assigned replacing the in-game placeholder; this authorizes the minimal runtime art binding despite older art handoff assigning integration to Aki.

## Outstanding work
Push dedicated PR, wait for required CI, integrate without bypassing review/protection requirements, deploy through existing main→Pages pipeline, verify live SHA and open actual live build. Update this report with SHAs/PR/deployment evidence. Do not claim live until verified.
