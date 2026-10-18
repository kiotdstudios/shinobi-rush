# Job Report - Idle correction v3
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW, revised mobile preview tested
- Commit / PR: Not committed; mobile review PR https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
North replacement reduces head centroid span from 3.403px to 0.179px and torso from 3.265px to 0.395px. Six other directions preserved byte-for-byte from v2, including south-east reference. Half-speed default remains 12 ticks/sec and 1.333s per breath. Review timer displays actual playback seconds.

## Files changed
Source: assets/characters/player/source/idle-review-v3/; exports: assets/characters/player/sprites/idle-review-v3/. Candidate-only assets; no gameplay integration.

## Tests run before commit
Python refine_idle.py: PASS 16-frame RGBA 128px normalization without clipping; six unchanged-direction byte comparisons; 16-tick looping GIF checks. Final commands: Python source/idle-review-v3/stage_godot.py and source/idle-review-v3/run_review.ps1: PASS east, north, south-east under Godot 4.5.1 OpenGL compatibility; zero runtime stderr; 16-frame captures each. Visual contact sheet rejected the second east attempt for head turning.

## Issues encountered
First east PixelLab PixMiniMax candidate increased head/torso sway and was rejected. Second v3 candidate planted feet but turned head; rejected. Preserved both in rejected/ source subdirectories. Third candidate accepted for review (group 9dcbaba6-5180-45d9-9670-67e24e35ea4e, job 0a355398-0223-4075-ad7f-a8df6459f52a). North group a7375e71-d5c4-464e-a1b2-e75968497e3a.

## Questions for project owner
None.

## Outstanding work / next steps
Publish tested mobile review and obtain owner visual feedback. Full Order 01 remains incomplete. Live deployment: not applicable to this GIF review job; gameplay integration remains outstanding.

East final head span 0.061px (was 2.967px), torso 1.285px (was 2.083px), feet 0px. Stable head orientation inspected on contact sheet. Third east source includes one reference plus 16 animated frames; excluded reference index 0 and used indices 1-16. All original source art retained. No procedural frame interpolation.
