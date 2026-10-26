# Job Report — Premium knockback impacts and substitution vortex
- Agent: Codex
- Order: orders/Codex/2026-10-26-knockback-substitution-vortex.md
- Date: 2026-10-26
- Final status: REVIEW — implementation tested; awaiting reviewed PR integration and canonical live verification.
- Commit / PR: Implementation aac25020; integration commit and PR pending.

## Work completed
Audited existing player/bandit damage assets: both already have approved128×128 eight-direction knockback bodies bound to gameplay. Preserved them. Added a12-frame authored directional contact/fragment impact with two sharp high-contrast early contact frames, reached-position damaged-body afterimages in a12-slot pool, and physical skid dust. A presentation node reads accepted hits/health changes and existing knockback state; it writes no health, movement, timers, input, AI or camera configuration. Impact nodes are capped at32 per observer. Rejected/invulnerable damage produces no new impact.

Created16-frame detailed coiling substitution smoke and complementary foreground/background atlases. Five bounded overlapping passes wrap around the existing log during wobble, fall and bounce. At1.02s ground contact plays one authored impact. The log/collider disappear at the unchanged1.88s poof, smoke dissipates through the unchanged2.95s end. Replaced old flat departure/ribbon overlays and procedural smoke circles; retained existing arrival smoke and original assets. No substitution trigger, teleport, invulnerability or tap-L2 / hold-charge rule changes.

Raw art uses built-in image_gen, after PixelLab review/credential check earlier in this session. Deterministic processor only removes chroma spill, extracts at fixed scale and splits layers. Review scene uses real player/bandit damage entry points and existing physics, with fixture resets and AI freeze isolated from gameplay. Normal/Half, all8 headings and replay included.

## Files changed
- assets/vfx/premium_damage/: two source images, impact/vortex/front/back RGBA sheets, import settings and exact layer/timing manifest.
- scripts/vfx/premium_impact.gd, knockback_presentation.gd and shared substitution_fx.gd presentation.
- scenes/main.tscn: attach presentation observer; scripts/art/kunai_proof_gate.gd: isolated impact=review route.
- scripts/art/impact_vortex_review.gd, build_impact_vortex.py and scenes/art/impact_vortex_review.tscn.
- tests/test_impact_vortex.gd and runner registration.
- docs/visuals/impact-vortex/: integration notes, contact sheets, normal/half previews and reproducible browser proof.

## Tests performed BEFORE commit
| Command / steps | Result / evidence |
|---|---|
| Python scripts/art/build_impact_vortex.py | Pass:12unique impact frames,16unique vortex frames, RGBA/no cell-edge contacts; complementary front/back union pixel-exact. asset-qa.json. |
| Python scripts/ci/godot_ci.py import --project . --godot [pinned4.7.2] --log-dir build/impact-vortex-review-import | Pass; new sidecars retained, unrelated tool sidecars preserved outside commit. |
| Python scripts/ci/godot_ci.py tests --project . --godot [pinned4.7.2] --log-dir build/impact-vortex-tests |3315passed/0failed. Expected bad-sheet fixture warning only. Final minor presentation cleanup/cap then focused rerun below. |
| Godot --headless --path . --script res://build/impact_focus.gd | Final86passed/0failed:17new VFX/layer/lifetime checks plus existing substitution/kunai/damage regressions. No gameplay writes, rejected damage, stationary afterimages, front/back ordering, log collision and smoke cleanup checked. |
| Python scripts/ci/godot_ci.py validate-resources --project . --godot [pinned4.7.2] --log-dir build/impact-vortex-final-validate |389scripts/28scenes/0failures. |
| Python scripts/ci/godot_ci.py export --project . --out ../impact-vortex-web-20261026c --godot [pinned4.7.2] --log-dir build/impact-vortex-release-export | Pass, fresh single-threaded Web debug export; local build SHA intentionally unknown. |
| Node docs/visuals/impact-vortex/browser-proof.mjs ../impact-vortex-web-20261026c docs/visuals/impact-vortex/release-proof | Final18/18pass, zero console/page errors:8actual damage headings for both actors, normal/half, wrap/bounce/dissolve/collision/cleanup. release-proof/validation.json and inspected PNGs. |
| Python scripts/ci/validate_orders.py; git diff --check | Pass before commit. |

Exact logs: ignored build/impact-vortex-* and build/impact_focus.gd. Executable: primary checkout .tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe; bundled Codex Python/Node runtimes.

## Issues encountered
The initial local implementation commit retained one extra blank line at EOF; removed during the integration commit, with final git diff --check rerun clean before publication. Initial review constant attempted to call normalized() inside a GDScript constant expression; fixed by normalizing at use, then validated/exported. Initial standalone focused harness left bandit substitution enabled, causing pre-existing damage-art assertions to encounter a legitimate substitution; corrected harness setup to match the full runner's substitution-disabled fixture. Rerun86/0 and full suite3315/0 passed. This was not a combat change.

Headless Chromium does not establish physical gamepad/hardware performance. Keyboard/browser review and existing native control tests were executed. Short GIF sampling may omit a20ms flash; the contact sheet and live half-speed viewer expose authored impact frames. No full-screen strobe or new camera rule is introduced.

## Questions for project owner
None.

## Outstanding work / next steps
Final release-browser proof and normal/half GIFs recorded; reviewed PR, required CI, main deploy/postdeploy, exact live SHA and browser verification. Until those complete: NOT LIVE — awaiting integration. Earlier waterlife delivery is preserved in merged PR213; its live pipeline is tracked separately.

## Integration checkpoint
Merged origin/main bde58e778da9bf593ef7d33bbf443853339a21dc with --no-commit --no-ff. This is the already-reviewed waterlife PR213 base; no gameplay conflict or behavior change. Final focused86/0 rerun and order/diff checks precede integration commit.

## CI regression investigation and fixture correction
Initial PR214 Godot CI40304682176 (head734b9fd1) failed four existing World Builder grass-selection/deletion checks:3311passed/4failed. Downloaded immutable artifact12642655343 and read full tests-builtin.log. Native reproduction inserted a floating health gourd30px below the fixed grass click: the old editor fixture reproduced exactly the same four failures (83/4), because foreground pickup art correctly takes picking priority. This points to the fixture random scatter, not VFX changing picking. The reset/scatter-count assertion remains intact; subsequent object-editing fixtures now remove random pickups before recording their base object counts. No builder runtime/picking behavior changed. Isolated corrected editor fixture87/0. Full suite rerun and order/diff checks recorded below before the fix commit.

Extra actual normal-game keyboard capture had no console errors and moved the player, but the wandering bandit stayed over1000px away behind the authored world during the short attempt; no natural-world combat hit is claimed from that capture. Confirmed hit/substitution coverage comes from real-controller review and native combat regressions.

### Fixture-fix verification before commit
Controlled old-fixture reproduction (build/editor_pick_repro_runner.gd) with a gourd30px below the dragged grass produced exactly83passed/4failed, matching all four CI failure labels. Corrected isolated editor87/0; final full suite rerun via godot_ci.py tests --log-dir build/impact-vortex-ci-fix-tests:3315passed/0failed, expected bad-sheet warning only. No runtime code changed after final release-browser18/18proof. Order structure and staged diff checks passed before publishing the fix.
