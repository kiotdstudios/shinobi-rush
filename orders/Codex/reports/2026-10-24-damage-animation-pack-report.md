# Job Report — Player and Bandit damage animations
- Agent: Codex
- Order: orders/Codex/2026-10-24-damage-animation-pack.md
- Date: 2026-10-24 (America/New_York)
- Final status: IN_PROGRESS — final browser verification/PR/deployment outstanding; not yet live.
- Commit / PR: Not committed; report written before implementation commit.

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
| Native contact-sheet/manual image inspection | Inspected all6direction sheets (both skins ×3actions), key poses and enlarged endpoints. Fixed unwanted graphic artifacts and supported/floating death endpoints before final export |
| python scripts/ci/validate_orders.py; git diff --check | PASS |

## Issues encountered
PixelLab caps active jobs at10; after initial rate-limit responses, queued remaining directions in batches as slots freed. Those rejected submissions had no job IDs and are not counted as completed. Four death versions were rejected (propped poses or a24pixel-high endpoint), and two knockbacks with unwanted white graphics were regenerated. Three edited prone key poses were aligned by whole-pixel translation only and used as pinned endpoints. All rejected versions remain in source/provenance. Initial browser check caught a typed-array assignment in the enlarged view's marker drawing. Fixed the marker and added native review-scene coverage; final browser rerun is pending at this report entry. Initial failed browser result is not counted as passed.

PixelLab balance was463.80before generation,279.80after:184generations used, no purchase/credits added. Exact job requests and selected/rejected IDs are recorded in queue.json/state.json and receipts. No keys logged.

## Questions for project owner
None for art production. Gameplay timing/respawn binding belongs to a separate Aki integration task; it is not silently altered here.

## Outstanding work / next steps
Finish final Web checks/previews, integrate latest main through normal reviewed PR/CI, deploy the opt-in art review and verify exact canonical build. Gameplay combat binding remains explicitly pending; distinguish a published art review from live combat wiring. Owner visual approval is not claimed.


## Final local browser / preview acceptance � before implementation commit
node docs/visuals/damage-animations/browser-proof.mjs ../damage-art-final-web-20261024 build/damage-browser passed all28checks with no console/page errors after the marker fix. Actual Web captures cover both skins, all8literal headings, three one-shot actions, terminal holds, normal/half/pause/step/replay and independent knockback travel. The final source clips/metadata were unchanged by the marker repair.

python docs/visuals/damage-animations/make_previews.py packaged72actual24FPS Web captures per view into normal3second and half-speed6second review GIFs, for enlarged SE and all-headings views. No art resampling or generated in-between frames. GIF replay is labeled separately from production one-shot behavior. browser-validation.json/preview-validation.json record exact results. Screenshots and all6native direction sheets were visually inspected, including both corrected knockbacks and enlarged death endpoints.

Local implementation is tested and ready for the protected PR workflow. Gameplay hooks remain explicitly pending for Aki; only the isolated art review is being published by this job.
