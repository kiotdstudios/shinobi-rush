# Job Report - North sprint moving-torso vest correction v3
- Agent: Codex
- Order: Order 01
- Date: 2026-10-18
- Final status: REVIEW - owner motion/armor assessment pending
- Commit / PR: Not committed; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Owner rejected sprint-v2 because a copied torso rectangle froze its movement. V2 is rejected. V3 restores the ORIGINAL sprint-v1 moving poses and repaints the armor separately for each pose. No static torso cel or repeated frame is used.

PixelLab transfer_outfit processes original retained poses 4-23 in two batches (15+5), with a native 64px upper-body crop and the fitted north normal-run vest as reference. Same seed 87321 and original eleven-color palette across batches. Jobs 72f6d12b-e2da-4280-aecf-349fb7edd1a8 and b5b61199-dff7-4fdf-b46d-e0fe1f1080d4, charged 10 generations each, total 20. This edits existing poses rather than generating a replacement gait.

Per-pose edited colors are recombined only into the original torso garment neighborhood: original olive-mask dilation clipped to x55-97/y47-73, original cloth colors only. Original alpha and every pixel outside the garment neighborhood stay byte-identical. Original skin, shoulder skin, wrap and buckle/gray landmark pixels are explicitly protected even within the neighborhood. Head, neck, waist, arms and lower-body motion remain from v1. Seven other directions compare byte-identical to v1. Retain 128x128 canvas, anatomical scale 104/108, origin [64,116], 20 unique sprint poses and half-speed timed review.

## Files changed
Local source crops/reference, receipts, edited crops, per-pose composition/export/check tooling and evidence: assets/characters/player/source/sprint-review-v3/. Normalized output: assets/characters/player/sprites/sprint-review-v3/. Review branch contains GIFs, README, this report and rejection annotation on the v2 report only.

## Tests performed before commit
- Native source/reference crop preparation inspected. Enlarged original-vs-edited five-pose batch inspected; unwanted skin/limb repaint in raw AI outputs is excluded by protected recombination masks.
- Python assets/characters/player/source/sprint-review-v3/compose_vest.py: PASS all 20 per-pose garment edits, original alpha unchanged, pixels outside garment mask unchanged, original skin/wrap landmarks unchanged, 20 distinct torso poses. No copied torso snapshot. Audit in garment-preservation.json.
- Inspected all 20 final original-vs-corrected poses in garment-contact.png, including the batch boundary. Torso pose and shoulder/waist movement remain visible. The plate is repainted to sit against those distinct moving poses; subjective acceptance is pending.
- Python assets/characters/player/source/sprint-review-v3/build_review.py: PASS 160 unique 128px RGBA poses, binary alpha, no clipping; seven other directions (140 PNGs) byte-identical to sprint-v1. North silhouette remains 94-105px through stride, unchanged.
- Python assets/characters/player/source/sprint-review-v3/compare_north.py: PASS synchronized 20-frame comparison, PREVIOUS V2 (rejected frozen torso) against REVISED V3 (moving torso).
- Python assets/characters/player/source/sprint-review-v3/stage_godot.py and assets/characters/player/source/sprint-review-v3/run_review.ps1: PASS north, east and south-west, 20 captures each, Godot 4.5.1 OpenGL compatibility with no runtime stderr. Other directions previously passed and remain byte-identical. Evidence in source/sprint-review-v3/evidence/.
- Decoded GIF checks: 20 frames, normal 830ms, half 1670ms, quarter 3330ms, north comparison 1670ms. Order validator and staged diff check run immediately before commit.

## Issues encountered
The previous static-region method removed desired torso animation and failed owner review. It is not reused. AI outfit edits also touched skin/limb colors in their raw crop outputs; these changes are excluded from final frames. Recombination deliberately retains original body geometry and protected source pixels. This method aims to correct armor appearance while retaining animation; engine checks and distinct hashes do not substitute for owner judgment of fit and motion.

## Questions for project owner
None. Updated moving-torso comparison supplied for review.

## Outstanding work / next steps
Owner review of north sprint torso/vest motion. Full Order 01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay code changed or live-game smoke test claimed.
