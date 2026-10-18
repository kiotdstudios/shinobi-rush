# Job Report — Kiro summary for the chief (Order 01, P0 debug log, 128x128 follow-ups)
- Agent: Kiro
- Order: [Order 01](../order_01.md) (Bootstrap Godot CI and live browser deployment), [P0 browser debug log](../2026-10-18-debug-log-export-and-browser-errors.md), the owner's 128x128 instructions, and the owner's request to merge PRs #1, #2, #3 and #5
- Date: 2026-10-18
- Final status: **Order 01 DONE (verified live).** P0 debug log: **REVIEW** (browser side done and verified live; the in-game event producer is Aki's and does not exist yet). P2 wall/player occlusion ([PR #9](https://github.com/kiotdstudios/shinobi-rush/pull/9)): **QUEUED, now unblocked, not started.**
- Commit / PR: nine PRs merged today (table below). This report ships in the Order 01 closure PR (the PR that adds this file).

## TL;DR
- **The game is live:** https://kiotdstudios.github.io/shinobi-rush/ . It is a placeholder arena (clearly labelled) built by a real pipeline: Godot 4.7.2, headless import and tests, single-threaded Compatibility Web export, browser smoke test, deploy to GitHub Pages, post-deploy smoke test against the live URL. Every merge to `main` redeploys it.
- **Codex can drop art in without code changes:** a `*.manifest.json` plus PNGs under `assets/characters/`. CI validates the manifest (128x128 enforced) and the in-game animation lab (Tab) shows it, with a turntable, zoom, grid, foot-anchor and height-ruler overlays and a two-set compare view.
- **128x128 RGBA is enforced, not just documented:** the validator errors on any other production frame size, the placeholder world was rescaled for a ~108 px character, and the contradictory 64x64 guidance was removed from the docs.
- **The browser debug log works on the live build** (13/13 live checks), but its main purpose (input/controller/interaction events) needs Aki's producer, which has not started.
- **One gap in the safety net was closed:** `godot-ci-gate` is now a required check, so a red Godot job blocks merging.

## What was completed
| PR | Merge commit | Merged (UTC) | What |
| --- | --- | --- | --- |
| [#4](https://github.com/kiotdstudios/shinobi-rush/pull/4) | 5dcad32 | 12:08 | Order 01 stage 1: the CI/deploy pipeline (pinned Godot, import/validate/test/export, smoke tests, Pages deploy, self-test with must-fail cases, docs) |
| [#6](https://github.com/kiotdstudios/shinobi-rush/pull/6) | d651078 | 14:54 | Order 01 stage 2: minimal real Godot project at the repo root, sprite drop-in contract and animation lab, `.gdignore` markers, first deployment |
| [#1](https://github.com/kiotdstudios/shinobi-rush/pull/1) | 8588a73 | 15:02 | Codex standards incl. the LOCKED 128x128 decision (merged on the owner's instruction; not my content) |
| [#2](https://github.com/kiotdstudios/shinobi-rush/pull/2) | 17a8c8e | 15:08 | Debug-telemetry spec and the Aki and Kiro P0 orders (not my content) |
| [#5](https://github.com/kiotdstudios/shinobi-rush/pull/5) | 6b88da1 | 15:14 | Orcha's dynamic combat camera order and spec (not my content) |
| [#3](https://github.com/kiotdstudios/shinobi-rush/pull/3) | 6c78986 | 15:39 | Codex mobile animation previews and reports (a draft; I marked it ready and merged it on the owner's instruction) |
| [#10](https://github.com/kiotdstudios/shinobi-rush/pull/10) | 0f01f81 | 15:53 | P0 browser debug log: opt-in `?debug=1`, JS error capture, JSONL/TXT download, copy bug report, sanitizer, bounded store, CI probe |
| [#7](https://github.com/kiotdstudios/shinobi-rush/pull/7) | e15abac | 18:44 | Docs only: removed contradictory 64x64 production guidance (11 files) |
| [#8](https://github.com/kiotdstudios/shinobi-rush/pull/8) | 068047e | 19:28 | 128x128 alignment: validator rules, export filters, world rescaled 2.25x, performance budget measured |

Open: [#9](https://github.com/kiotdstudios/shinobi-rush/pull/9) (deferred P2 order, docs only). Not merged by me because it was not in the owner's list and it says it waits for this work to finish.

## Live deployment evidence (verified by me, not only by CI)
- **First deployment:** [Godot CI run 39138070349](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39138070349) (push to `main`, commit d651078): detect, build, pre-deploy smoke, deploy, post-deploy smoke and `godot-ci-gate` all success. The live `build-info.json` reported that exact commit. Post-deploy smoke on the real URL: 11/11 checks (WebGL2, served files match the build's SHA-256 hashes, engine start 3.3 s, canvas 1280x720 and not blank, ready hook, keyboard input changes the picture, no fatal console events). I opened the evidence screenshots: the placeholder arena renders, and holding D moved the player from x=0 to x=90.
- **Latest verified:** [run 39158946428](https://github.com/kiotdstudios/shinobi-rush/actions/runs/39158946428), commit 068047e (PR #8), built 19:29 UTC, deploy and post-deploy smoke success; the live `build-info.json` reports 068047e. I opened a live screenshot at the new scale: figure about 108 px tall, larger diamond tiles and blocks, debug panel present.
- **Live click-through of the debug panel** (my own Playwright run against the deployed URL, real canvas clicks, no hooks or shortcuts): 13/13 pass. The downloaded log is valid JSONL whose header carries the live build commit; both induced browser errors (a thrown error and an unhandled rejection) were captured; text typed into the page never appears in the log; clicking Download causes no network request; nothing is written to local/session storage or cookies; the TXT button downloads; Copy Bug Report puts a 1,048-character report with the tester note and build SHA on the clipboard; with the clipboard denied, the panel shows "Copy was refused" and a selectable text box.
- **Wire size:** Pages serves gzip; the Web build is about 10 MB over the wire (the wasm is about 38 MB raw).

## Test results
| What | Result | Where |
| --- | --- | --- |
| In-engine tests (`tests/run_tests.gd`) on the final `main` build | **245 passed, 0 failed** | CI log of Godot CI run 39158946428 |
| Python CI tooling tests | 131 + 33 (sprite validator), all OK | local at stage 3b head, plus CI "Tooling lint and unit tests" |
| Node smoke-harness tests | 23 pass | local; CI |
| Pipeline self-test (generated throwaway projects, positive and must-fail cases) | green on every PR/push that touches the pipeline | Pipeline self-test runs on `main` |
| Browser smoke (pre-deploy, per PR and per `main` push) | pass on every PR; post-deploy pass on every `main` deploy | Godot CI runs |
| Controls probe (walk, sprint, wall stop via `window.__SHINOBI_STATE__`) | pass | Godot CI |
| Debug probe (induced errors, download, privacy, flood) | 28 PASS lines, VERDICT PASS | Godot CI (PR #10 run) |
| Performance budget, full-size synthetic 128x128 set (8 directions, 1024 frames) | PCK 8.4 MiB as sheets (10.1 loose); load about 0.5 s; texture memory 7.1 to 92.4 MiB (28.4 MiB with VRAM compression); no growth when cycling animations | measured in real Chromium on software GL (`GODOT_CI_AND_DEPLOYMENT.md`) |

## Changes made outside code (all authorized by the owner, all reversible)
1. **GitHub Pages enabled** (Actions source). Reverse: `gh api -X DELETE repos/kiotdstudios/shinobi-rush/pages`.
2. **Ruleset "Agent Rules": `godot-ci-gate` added** to the required status checks next to `validate-orders-and-project`. Verified by re-reading the ruleset: every other rule (pull request, strict up-to-date, no force-push, no deletion, no bypass) is byte-identical to before. Reverse: remove that one entry from the rule.
3. **PR #3 marked ready for review and merged** (it was a draft with 12 commits, no new commits for about an hour; Codex was told in a comment that later commits need a new PR).
4. **Branch updates** (merge commits by Kiro on the branches) for PRs #1, #2, #3 and #5 so they could merge under the strict up-to-date rule.
5. **Comments** on PRs #2 (interface proposal for Aki), #3 (live link and drop-in contract for Codex) and #5 (camera/test hooks for Orcha).

## Judgment calls you may want to review
- **Project at the repository root,** not `game/`: the locked handoff architecture lists `project.godot` next to `scenes/` and `assets/`, and Codex delivers art to `assets/characters/player/`. Non-game folders are hidden from Godot with empty `.gdignore` files. The only touch under `assets/` is the empty `assets/characters/player/references/.gdignore`, which keeps the approved turnaround out of the game.
- **Debug export template for the live test build** (not release): release templates swallow GDScript runtime errors (verified on 4.7.2), which would blind the smoke test.
- **World rescaled 2.25x** (factor in `scripts/world_scale.gd`) so the arena is a fair reference for a ~108 px character. All numbers (tile 144x72, footprint, speeds) are provisional prototype values for Aki and Orcha to re-tune, not balance.
- **Debug-log build SHA (option A):** the export step bakes `res://build-info.json` (identity fields only) into the PCK so the log header carries the commit without any network request. The debug code makes zero network calls and writes no storage.
- **Merge commits, not squash,** so the SHAs cited in the reports stay reachable from `main`.
- **Removed from `GAME_DESIGN_DOCUMENT.md` line 40:** the old "boss 96x96 or 128x128" canvas. 96x96 contradicts the lock; if bosses need a different canvas, that is a new owner decision.

## Not verified (said plainly)
- Controller hardware, DualSense in browsers, Safari and mobile browsers, real 128x128 art (none exists yet), and **frame rate on a real GPU** (only software GL was available; 4 to 6 FPS in headless Chromium proves nothing about smoothness).
- The debug log's keyboard/controller/interaction events: Aki's producer does not exist, so only the browser side (errors, metadata, export, privacy, limits) is verified.
- Debug-panel behaviour on iOS Safari (downloads and clipboard rules differ).

## Questions for the chief
1. **PR #9 (wall/player occlusion, P2):** its dependency is cleared. May I merge it and start now? Plan: re-test the live build at the new 128x128 scale first; if the player no longer disappears under the wall unexpectedly, close it as "resolved by other work, no code change" with evidence.
2. **Aki's telemetry producer:** no reply on PR #2 and no code on `main` or any branch. Should I wait for Aki, or write a minimal producer (keyboard and gamepad actions only) behind the agreed `DebugTelemetry` interface so Aki can extend it? The second risks overlapping edits.
3. **Live build flavour:** keep the debug-template test build, or add a release build for phone play-tests (smaller and faster, but script errors are hidden)? Needed before any wider beta.
4. **World scale and camera:** please look at the live build on desktop and phone. Is the 128x128-sized arena right, and who approves tile geometry and zoom (the camera doc says the owner)? Orcha's camera director will also need to take over the lab's zoom control.
5. **Review rules:** the ruleset requires 0 approvals and every agent commits through the same GitHub account, so GitHub cannot enforce a second pair of eyes. Our substitute is an independent reviewer agent plus CI. Do you want a human approval for changes under `.github/workflows/**` and `scripts/ci/**` (CODEOWNERS), or separate accounts per agent?
6. **Repository size:** PR #3 added about 9 MB of preview GIFs (18 files, 75 KB to 620 KB each) to git history. They are not shipped in the game build, but they are permanent in history. If Codex will add many more, should previews move to Releases or Git LFS?
7. **Maintenance OK?** (a) a `.github/dependabot.yml` for the SHA-pinned GitHub Actions, (b) stay on Godot 4.7.2 until 4.8 is stable (betas exist) and bump through a PR, (c) delete the merged remote branches (I deleted none).

## Comments
- **Every PR now waits about 10 minutes** for the Godot gate, even docs-only ones, because the workflow deliberately has no path filter (a path-filtered required check can hang forever). If that cost bites, a job-level change detector can skip the heavy jobs while still reporting the gate.
- **Security posture:** workflow actions are pinned to full commit SHAs, permissions are least-privilege, only the deploy job can write Pages, the `github-pages` environment allows `main` only, and no secrets are used. Reviews found and fixed a log-injection gap in the CI sanitizer and a stale scale gate in Codex's order heading.
- **Process notes:** agents occasionally stalled on built-in "am I stuck in a loop?" prompts and when the laptop slept; I unblocked or replaced them. A keep-awake with a heartbeat log is running (it also holds the display on because this machine uses Modern Standby). Plug in and keep the lid open for long unattended runs.
- **Attribution:** commits, PRs and comments from all agents appear under one GitHub user. Commit message prefixes ("Order 01 (Kiro):", "Docs (Kiro):") are the only marker. Consider an `Agent:` trailer.
- **For Codex:** when the first real manifest lands, expect a first-contact round of CI feedback from the validator. Full 128x128 sets are texture-heavy (92 MiB uncompressed for 1024 frames), so plan VRAM compression for Web before mass production.
- **For Orcha:** the animation lab writes the camera zoom directly; route it through the camera director when that lands. `window.__SHINOBI_STATE__` is the stable contract the CI probes read; tell me any new field names.

## Next steps
- Your answers to the questions above.
- If approved: merge PR #9 and investigate the occlusion report; re-run the live checks after each merge.
- Aki: build the in-game event producer (interface: `docs/development/DEBUG_LOG_INTERFACE.md`); then I verify the full chain live.
- Codex: first real manifest and sprite sets; I will check the validator and lab against real art.
- Orcha: camera director; I will extend the CI probe for camera fields on request.

## Where to look
Per-job reports in this folder: [stage 1](2026-10-18-bootstrap-godot-ci-deploy-report.md), [stage 2](2026-10-18-minimal-godot-project-and-first-deploy-report.md), [debug log](2026-10-18-debug-log-export-report.md), [128x128 alignment](2026-10-18-128-standard-alignment-report.md), [64x64 docs cleanup](2026-10-18-128-docs-consistency-report.md). Operations guide: [GODOT_CI_AND_DEPLOYMENT.md](../../../docs/development/GODOT_CI_AND_DEPLOYMENT.md). Project handoff: [GODOT_PROJECT_HANDOFF.md](../../../docs/development/GODOT_PROJECT_HANDOFF.md). Codex contract: [SPRITE_DROP_IN.md](../../../docs/prototype/SPRITE_DROP_IN.md). Debug log: [guide](../../../docs/development/DEBUG_LOG_USER_GUIDE.md) and [interface](../../../docs/development/DEBUG_LOG_INTERFACE.md).
