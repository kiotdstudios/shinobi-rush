# ORDER — Verify restored wide gameplay camera framing
- Agent: Kiro
- Status: QUEUED — REVIEW REQUIRED
- Priority: P1
- Context: Owner screenshot 2026-10-18 shows arena much more zoomed-in after 2.25x world scale; owner explicitly requests the previous wider view.
- Change proposed in this PR: Camera2D zoom 0.444444 (inverse of WorldScale.SCALE 2.25) to restore approximately the pre-scale visible world area. This is an unverified first-pass camera setting, not a verified final fix.

## Before merge
1. Compare the old screenshot with latest and the PR export at identical browser viewport size. Confirm visible arena area, obstacle sizes and player visibility. Adjust zoom if needed; prioritize owner's requested old framing while retaining **128x128 native production sprite frames**. Camera zoom is not sprite export resolution.
2. Confirm animation lab `Z` / mouse-wheel zoom does not unexpectedly override baseline framing; update lab zoom to be relative to baseline if needed. Coordinate with Orcha's camera director.
3. Validate camera limits near all four arena edges and no clipped player; preserve existing occlusion bug order #9 as separate work.
4. Run actual Godot tests, Web export, Chromium smoke/controls and manual visual screenshots. Check 128x128 sprite legibility at the wider camera scale; report tradeoffs and any requested owner choice.
5. Open evidence-backed follow-up if camera framing needs deeper design. No claim of deployed or verified before actual browser testing.

## Report
Write report in `orders/Kiro/reports/` with old/new comparison, camera setting, tests and PR/build links.
