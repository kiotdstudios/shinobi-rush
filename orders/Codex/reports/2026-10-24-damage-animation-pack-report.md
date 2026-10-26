# Job Report â€” Player and Bandit damage animations
- Agent: Codex
- Order: orders/Codex/2026-10-24-damage-animation-pack.md
- Date: 2026-10-24 (America/New_York)
- Final status: DONE — animation assets committed/integrated and public art review verified; gameplay binding is explicitly pending for Aki.
- Commit / PR: runtime merge1a5b897e10486847de4a53d03e37c6340562a86b / https://github.com/kiotdstudios/shinobi-rush/pull/188. Initial report written before implementation commit.

## Work completed
Audited both manifests: neither had dedicated hit reaction, knockback or death. Added hit_react (8frames), knockback (12frames), death (16frames), all8headings for both approved characters:48clips/576production frames. Actual approved native idle PNGs seed PixelLab animate_image directly, avoiding animate_character's automatic canvas expansion and any need to rescale characters. All frames128x128 RGBA, fixed64,116origin, native hard alpha, no clipping/duplicates/resampling. Each incoming source frame0 is checked pixel-identical to its approved input; production exports source frames1..N. Death is non-looping with a held final prone pose. No new weapons, background, floor shadow or VFX.

Separate per-character damage.art.json gives source jobs/hashes, canvas/anchor, nominal24FPS/durations, incoming impact and recovery recommendations, empty offensive hitbox windows, and independent root-motion guidance. Existing manifests preserve all old actions and append the three new ones. Gameplay wiring remains pending for Aki: player still immediately respawns at zeroHP; bandit retains existing gameplay/render hooks. No HP, state machine, damage, controller, AI or respawn changes are made by this art delivery. Explicit integration guidance is in docs/visuals/damage-animations/INTEGRATION.md.

Own ?damage=review scene shows16actors together or one enlarged paired heading. Normal/half, pause/step/replay, direction selection, clock, final-pose holds and a separate illustrative knockback Travel control. Production clips never loop; review GIFs replay for inspection.

## Files changed
Both character manifests; new assets/characters/{player,bandit}/damage (576PNG exports, import settings, frame/timing metadata and ignored raw/rejected sources); new art review scene/script, minimal art gate registration; native tests/test_damage_art.gd and runner registration; docs/visuals/damage-animations production/QC/download/preview tools and evidence. No gameplay-owner files changed.

## Tests performed BEFORE commit
Windows PowerShell, pinned Godot4.7.2, bundled Python/Pillow and Node/Playwright. Commands run from .tools/dynamic-shrine.

| Command / manual steps | Actual result / evidence |
| --- | --- |
| python docs/visuals/damage-animations/fetch_clips.py | PASS indexed PNG downloads with native128x128 RGBA/size/magic checks; source originals retained |
| python docs/visuals/damage-animations/export_pack.py | PASS48clips/576frames; exact input identity, unique hashes, hard alpha, border containment; validation.json |
| python scripts/ci/godot_ci.py import --project . --godot <pinned executable> --log-dir build/damage-final-import | PASS/no engine errors; expected untracked sidecar warning before staging own578sidecars |
| python scripts/ci/godot_ci.py tests --project . --godot <pinned executable> --log-dir build/damage-tests | PASS2727/0FAIL before the later review marker fix/4additional review cases; only expected malformed-sheet fixture warning |
| Godot --headless --path . --script res://build/damage-focus.gd | PASS206/0FAIL after marker fix, including real imported clips,8way literal facing/no mirrors, fixed anchor, terminal frame clamps/native one-shot hold,16actor review, enlarged view and overview restoration; no engine errors |
| python scripts/ci/godot_ci.py export --project . --out ../damage-art-final-web-20261024 --godot <pinned executable> --log-dir build/damage-final-export | PASS final debug Web export. Local SHA is unknown because GITHUB_SHA is unset; no public build claim |
| node --check docs/visuals/damage-animations/browser-proof.mjs | PASS syntax |
| Native contact-sheet/manual image inspection | Inspected all6direction sheets (both skins Ã—3actions), key poses and enlarged endpoints. Fixed unwanted graphic artifacts and supported/floating death endpoints before final export |
| python scripts/ci/validate_orders.py; git diff --check | PASS |

## Issues encountered
PixelLab caps active jobs at10; after initial rate-limit responses, queued remaining directions in batches as slots freed. Those rejected submissions had no job IDs and are not counted as completed. Four death versions were rejected (propped poses or a24pixel-high endpoint), and two knockbacks with unwanted white graphics were regenerated. Three edited prone key poses were aligned by whole-pixel translation only and used as pinned endpoints. All rejected versions remain in source/provenance. Initial browser check caught a typed-array assignment in the enlarged view's marker drawing. Fixed the marker and added native review-scene coverage; final browser rerun is pending at this report entry. Initial failed browser result is not counted as passed.

PixelLab balance was463.80before generation,279.80after:184generations used, no purchase/credits added. Exact job requests and selected/rejected IDs are recorded in queue.json/state.json and receipts. No keys logged.

## Questions for project owner
None for art production. Gameplay timing/respawn binding belongs to a separate Aki integration task; it is not silently altered here.

## Outstanding work / next steps
Finish final Web checks/previews, integrate latest main through normal reviewed PR/CI, deploy the opt-in art review and verify exact canonical build. Gameplay combat binding remains explicitly pending; distinguish a published art review from live combat wiring. Owner visual approval is not claimed.


## Final local browser / preview acceptance — before implementation commit
node docs/visuals/damage-animations/browser-proof.mjs ../damage-art-final-web-20261024 build/damage-browser passed all28checks with no console/page errors after the marker fix. Actual Web captures cover both skins, all8literal headings, three one-shot actions, terminal holds, normal/half/pause/step/replay and independent knockback travel. The final source clips/metadata were unchanged by the marker repair.

python docs/visuals/damage-animations/make_previews.py packaged72actual24FPS Web captures per view into normal3second and half-speed6second review GIFs, for enlarged SE and all-headings views. No art resampling or generated in-between frames. GIF replay is labeled separately from production one-shot behavior. browser-validation.json/preview-validation.json record exact results. Screenshots and all6native direction sheets were visually inspected, including both corrected knockbacks and enlarged death endpoints.

Local implementation is tested and ready for the protected PR workflow. Gameplay hooks remain explicitly pending for Aki; only the isolated art review is being published by this job.

## Latest-main integration before merge commit
Implemented/tested source commit b479ab37256dc69e4af76cda0b8a2dc6cdfdb018. Integrated main3930efb61b24868b985061ce0d5a980f588715f2 with git merge --no-commit --no-ff, preserving Aki's editor/void-checker changes unchanged. BEFORE committing that merge: focused native floor-replacement + world-editor + damage-art/review harness passed313/0FAIL with no engine errors (build/damage-integration.log); fresh Web export to ../damage-art-integrated-web-20261024 passed; all28browser checks passed again with no errors using --no-capture. Exact evidence in integrated-browser-validation.json. Source character art/review images did not change during this integration, so existing tested72frame previews remain valid.

## Protected PR result
PR https://github.com/kiotdstudios/shinobi-rush/pull/188 merged normally as1a5b897e10486847de4a53d03e37c6340562a86b after required Repository checks and Godot gate passed on head2abd4d4be28cd07bfa26659e75c4924e4afc2f27. PR Godot run40154204033 passed through browser controls/debug probes. Native job121051979164 logs report2738PASS/0FAIL and339scripts/22scenes validated with0failures. This full integrated result is distinct from earlier local2727 and206/313focused checks. Main deployment/public verification remain pending at this entry.

## Main native/resource build evidence
Main workflow40154927657 import/test/export job121054207694 completed success for runtime1a5b897e10486847de4a53d03e37c6340562a86b. Connected GitHub log retrieval confirms339scripts/22scenes validated with0failures and full native summary2738PASS/0FAIL. Deployment/postdeploy and own exact public review checks remain pending at this entry.


## Final canonical public verification
- Canonical review: https://kiotdstudios.github.io/shinobi-rush/?damage=review . Public probe uses paused=1 for deterministic inspection.
- Exact deployed/tested SHA: 1a5b897e10486847de4a53d03e37c6340562a86b (matches PR188 merge).
- Tested at: 2026-10-25T02:49:21.930Z (ISO UTC; local job date2026-10-24 America/New_York).
- Command: node docs/visuals/damage-animations/browser-proof.mjs https://kiotdstudios.github.io/shinobi-rush/ build/damage-live --no-capture . All28checks PASS; no console/page errors. Verified16actors, literal8way headings, normal/half/pause/step/replay, all3actions, terminal holds and independent illustrative travel.
- Inspected actual PUBLIC death-all.png and knockback-all.png with view_image: both approved skins render at stable scale/anchors, all directions show distinct action poses, death stays prone and no unwanted white graphics remain. Local enlarged SE snapshots and all6native key-pose sheets were also inspected before publication.
- Main workflow https://github.com/kiotdstudios/shinobi-rush/actions/runs/40154927657 completed SUCCESS through native/import/export, predeploy browser checks, Pages deployment, postdeploy live smoke and final gate. Full merged native suite2738PASS/0FAIL;339scripts/22scenes validated with0failures.
- Exact public URL/time/SHA/checks: docs/visuals/damage-animations/live-browser-validation.json; actual screenshots: live-all-directions.png, live-death-all.png, live-knockback-all.png.

## Final scope / handoff
No remaining art-pack/review work. Deliverable:48clips/576native128RGBAframes, both updated manifests, non-loop timing/event metadata, raw/rejected source provenance,4actual Web GIFs,6native direction sheets, automated native/browser coverage and published review. Owner visual approval remains separate. Gameplay damage/death/HP/respawn hooks are NOT claimed implemented: detailed source locations and recommended normalized-progress binding are in INTEGRATION.md for Aki. Existing immediate player respawn remains unchanged.

This follow-up commit contains only report/status updates and recorded public screenshots/JSON. Live deployment: not applicable to the follow-up itself (no runtime change); runtime delivery above is already live and verified. validate_orders.py and git diff --check passed before committing final evidence. The report follow-up uses a normal PR and required checks without bypass.
