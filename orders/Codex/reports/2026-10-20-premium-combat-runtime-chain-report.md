# Job Report — SE runtime-chain comparison

- Agent: Codex
- Order: `orders/Codex/2026-10-20-premium-combat-animation-pack-v1.md`
- Date:2026-10-20
- Final status: REVIEW — follow-up concrete timing/layer proof; eight-direction production and runtime integration not complete.
- Commit / PR: `52618ae053be151ca106d270ff87f5afcc41d2d8`, pushed to `codex/premium-combat-poc`; https://github.com/kiotdstudios/shinobi-rush/pull/42 remains open/ready/unmerged. This SHA entry is a follow-up report-only update; original report preceded implementation commit.

## Work completed / files changed

Fetched latest orders/main and inspected Aki's newly merged PR43, main `63bbd6c16f449d77d3e14e5a4c1afedb80864380`. Existing four ground AttackDef timings/cancel gates are unchanged. Current approved run/dodge use12FPS;12-frame dodge lasts1000ms in runtime, unlike original300ms art proposal. Added a second opt-in `.art.json` timing profile, using existing bodies and the existing dodge exit pose, and new normal/half close-scale GIFs. No new generation or paid API call.

Runtime chain uses750ms approach, light1→2 at200ms, light2→3 at216.667ms, light3→dodge at350ms, dodge→dash at920ms (80ms remaining), full400ms dash.44 played poses,2836.667ms exact nominal timing. Body and sword pairs are cut together, effects keep their independent clock across transitions. No idle action added. Source intervals are retained separately from clipped played intervals. This illustrates legal nominal gates, not input/physics/collision/hitstop replay or implemented art-event integration.

Browser now defaults to Runtime chain with Full art study selectable; both swords, layers, scales, clock and stepping retained. Added executable builder/validator, extended browser/Godot checks, updated handoff/order/audit. Deepened legacy source inventory: normalized baked-weapon candidates for light1 in7directions, light2 S/NW and dashSE; all visual-review candidates/workspace-only, not production modular coverage. No regeneration or modification of existing847frames, no Aki/Kiro gameplay/camera changes. Original art-study metadata/GIFs remain available.

## Tests performed BEFORE implementation commit

Same Windows/bundled Python/Pillow/Node/Chromium/Godot4.7.2 environment as SE proof report. Commands from `.tools/premium-combat-poc`:

| Command / inspection | Result / evidence |
| --- | --- |
| `python docs/visuals/premium-combat-v1/build_runtime_chain.py` | PASS. Verified exact audited source AttackDef values, combo/dodge eligibility expressions,80ms late-dodge threshold and12FPS approved locomotion. Exported44-pose profile and two close-scale GIFs. |
| `python docs/visuals/premium-combat-v1/validate_runtime_chain.py` | PASS. Body hash/128RGBA/binary alpha; all44 sockets opaque;88 body/sword composites without stage clipping; frame indices/holds; legal combo/dodge exits; four contacts in active intervals; total2836.667ms. GIF10ms quantization2840ms normal/5680ms half. `runtime-chain-validation.json`. |
| `node docs/visuals/premium-combat-v1/browser_smoke.mjs` with existing shared `PLAYWRIGHT_MODULE` override | PASS desktop1280×900/mobile390×844 touch.74 unique images, six actions and stepping, four active/contact markers, exact sequence branches at950/1166.667/1516.667/2436.667ms, both profile totals/switching, two swords share bodies, layer toggles, pause/play, normal/half, native/close, reload.0page errors/HTTP missing assets, no horizontal overflow. Updated browser-smoke.json/four screenshots. |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script docs/visuals/premium-combat-v1/validate_imports.gd --log-file docs/visuals/premium-combat-v1/godot-runtime-chain-validation.log` | PASS exit0.58art+44chained body references, two swords and20VFX loaded as expected Texture2D; close formula confirmed. Import validation only, not gameplay playtest. |
| Inspected actual dodge exit PNG enlarged; checked legacy normalized PNGs and clip status metadata | New exit hand socket corrected to `[49,80]`. Legacy80PNGs expected128RGBA; candidate status and baked-weapon boundary documented. |
| `python scripts/ci/validate_orders.py` | PASS. |
| `git diff --cached --check` | PASS before implementation commit. |

## Issues / limitations

Newly included dodge exit pose initially inherited a socket outside opacity; validator caught it. Inspected original hand, corrected to `[49,80]`, rebuilt and passed. Original full-study300ms dodge is a proposed art timing, so runtime-chain comparison explicitly uses the current1000ms source action. Neither profile changes gameplay. Nominal gate timestamps are not deterministic real-input replay; no enemy, root movement, collision, hitstop simulation or confirmed Aki event adapter.

Source video unavailable locally, no source-video timing claim. No paid generation; legacy other-direction sources remain baked weapons and need art evaluation before modular conversion. Light3 rotational facing and hybrid dash still require visual review.

## Owner questions / outstanding work

None required for this timing comparison. Review the concrete SE look/feel before8-direction expansion as Chief's Phase1 requires. Continue with Aki event API/tuning coordination and dedicated offensive directional art after that gate. Defensive/aerial/bandit combat are later milestones.

Live deployment: not applicable; opt-in art review harness/metadata, no runtime-selected art or controller change. PR42 remains the review artifact. New public GIF links will be verified after push; no live game update claimed.

## Publication verification

After push, fetched raw GitHub `runtime-chain-half.gif` and `runtime-chain-normal.gif`: both HTTP200, image/gif,1204233bytes. Public prefix `https://raw.githubusercontent.com/kiotdstudios/shinobi-rush/codex/premium-combat-poc/assets/characters/player/previews/premium-combat-poc/`. PR42 description updated with both timing profiles, phone GIF links, latest test evidence and limits. No main merge or live game deployment claimed.
