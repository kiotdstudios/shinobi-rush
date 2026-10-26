# Archive — stale Body Flicker order PRs (closed 2026-10-26)

Three old order-ticket PRs from 2026-10-21 were closed unmerged on 2026-10-26 because the work
they describe is **done and superseded**, and in two cases the order file itself already exists
on `main` under a different merged PR. Closing them without archiving would lose the paper trail,
so the three original order files are preserved here exactly as they stood on their stale branches.

## What happened (chronological)
1. **PR #55** `orders/orcha-body-flicker-jutsu-2026-10-21` — the original P0 order: build an
   original Naruto-inspired Body Flicker visual prototype (SE-only proof first). Never merged.
2. The described prototype work was actually built and delivered via a **different** branch/PR
   (`orcha/body-flicker-in-game-preview`, merged as PR **#61** on 2026-10-22): an Animation Lab
   Tab+Y preview (`scripts/vfx/body_flicker_demo.gd`). That merge **also added**
   `orders/Orcha/2026-10-21-body-flicker-in-game-preview.md` and
   `orders/Orcha/2026-10-21-body-flicker-delivery-rules.md` directly to `main` — the same two
   order files that PRs #56 and #58 (below) were separately, and redundantly, still trying to add.
3. **PR #56** `orders/orcha-body-flicker-in-game-preview-2026-10-21` — stale duplicate. Its file
   content is identical to what PR #61 already put on `main`, except the stale branch is frozen at
   `Status: QUEUED` while main's merged version correctly reads
   `Status: REVIEW -- Godot 742/0, Web export PASS, browser smoke PASS (11/11)`. Main's copy is
   strictly more complete; nothing is lost by closing this PR unmerged.
4. **PR #58** `orders/orcha-body-flicker-delivery-rules-2026-10-21` — stale duplicate, byte-for-byte
   identical to the copy PR #61 already merged to `main`. Zero diff.
5. Gameplay then moved on twice more: the dodge's Body Flicker was replaced by an evade-burst +
   `ninja_evade` streak (commit `6822d4ac`), and finally Codex delivered the current **premium**
   eight-direction Body Flicker that is live today (`codex/body-flicker-premium`, PR **#209**,
   merged 2026-10-26, commit `4e248c1b`).

## Net result
The functionality all three orders asked for shipped long ago and has since been superseded by a
better implementation that is live right now. Closing PRs #55, #56, #58 removes stale, non-mergeable
clutter from the open PR list without losing any information — see the archived files in this folder
for the exact original order text.
