# Job Report - Eight-direction jump v1
- Agent: Codex
- Order: Order01
- Date: 2026-10-18
- Final status: REVIEW - owner visual acceptance pending
- Commit / PR: pending; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner passed latest sprint v5 and authorized eight-direction jump: anticipation, takeoff, airborne tuck, descent, soft landing/recovery. PixelLab PixMiniMax generated24real poses per direction. Initial groupc4a87d88-7e0b-4417-bc1c-bf6cf960afd2 cost16generations. Rejected original north/north-east turning toward camera and south second bounce. Replacements cost1generation each: NEa4b14b6c-85c0-4365-b18b-f9da5fed6ab8, S0981490e-edf4-49fb-89a7-9ede09fe219b, Nad3a71d5-9218-4550-a9df-c5c10f4e118e. Total19generations. Job receipts/exact URLs and rejected originals retained locally.

One common grounded root per direction uses first/last2poses; uniform104/108anatomical scale,128x128RGBA, origin[64,116]. No per-frame recentering: vertical rise stays visible. All fit128without overflow/shrinking. To align the review, cyclically move existing grounded recovery poses to the beginning: south4, north4, NE3. All24unique poses retained, no interpolation or duplicate holds. Three visual phases remain distinct. Per-direction timing still varies slightly; generation prompt ranges are intentions rather than final gameplay event markers.

Review GIF shows all8directions, separate fixed ground marker, pose counter and actual-seconds timer. Default0.5x=12poses/sec,2seconds. No approved idle/walk/run/sprint sprites changed.

## Files changed
Local source assets, rejected originals, receipts, build/stage/capture scripts and contacts under assets/characters/player/source/jump-review-v1/. PNGs/sheets/manifest under assets/characters/player/sprites/jump-review-v1/. Order01 locally records sprint approval/jump authorization. Mobile review branch publishes3GIFs, README and this report only; full accepted production asset handoff remains outstanding.

## Tests performed BEFORE commit
- Reviewed initial and replacement raw contact sheets; rejected visible facing turns/double bounce before publishing. Inspected final all-direction contact plus full24-pose contacts, including recovery and airborne view.
- Bundled Python build_review.py: PASS192unique128x128RGBA frames, binaryalpha, no clipping; uniform scale and common root retained. Final recovered standing heights approximately101-104px. No mirrored directions or procedural/filler poses.
- GIF decoding via Pillow: PASS24frames each,800x1880; normal1000ms, half2000ms, quarter4000ms, infinite loop. Timer derives from authored24fps and selected speed.
- Bundled Python stage_godot.py and PowerShell run_review.ps1: PASS all8directions,24captures each, Godot4.5.1 OpenGL compatibility, zero runtime stderr. After timing alignment, run_aligned_review.ps1 retested changed S/NE/N; all PASS. Capture count/error-log audit PASS final8directions. Inspected north and south-east airborne engine captures; character lifts above separate grounded shadow.
- Order validator and staged diff --check executed immediately before implementation commit.

## Issues encountered / limitations
Initial AI facing turns and extra bounce rejected and regenerated. NE landing toe extent reaches5px below nominal root in a few transitional poses; no per-frame stabilization applied, preserving natural leg/torso motion. Slight direction timing differences remain for owner review. These previews do not define final collision/airborne gameplay event timing, transition tuning or Web performance. Broad north plate follows crouch/airborne torso; owner armor-fit assessment remains pending.

## Questions for project owner
None. Review supplied for visual feedback.

## Outstanding work / next steps
Owner jump acceptance/revisions, then dodge and remaining Order01 actions/equipment/VFX/integration. Full Order01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay code changed or live-game smoke test claimed.
