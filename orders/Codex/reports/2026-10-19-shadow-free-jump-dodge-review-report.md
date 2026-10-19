# Job report - Shadow-free jump correction and dodge review
- Agent: Codex
- Order: Order01 / owner shadow and NE-leg feedback
- Date: 2026-10-19
- Status: REVIEW - final jump/dodge previews technically checked; owner acceptance pending
- Commit / PR: follow-up to https://github.com/kiotdstudios/shinobi-rush/pull/23

## Work completed
Removed drawn ground ellipse from the shared Godot art harness and jump/dodge GIF builders. Approved locomotion/sprint PNGs never had baked shadows; their pixel data remains unchanged. Prior review files are historical; updated jump/dodge previews are shadow-free.

North-east jump regenerated with both knees/feet together, no forward leg extension, same back-facing view. PixelLab job580f7aab-eada-4a70-803f-22688fa5cf8b, groupd6c2fdef-4c26-4528-bc1b-1d44a7c45c2d,1generation. New jump-review-v2 retains seven other jump directions byte-identical,24poses per direction,128RGBA, origin[64,116], half-speed2seconds. The NE hop is compact and has a lower foot lift than other directions; owner motion acceptance pending.

Dodge first batch (group7f418c22-c712-4309-a688-51111e1187da,8generations) repeated running/turning and was rejected. Replaced with12-pose single ducking-lunge groupde22a8e4-94e2-4b87-a130-8fd8c305c695,8generations. North still turned diagonally, so north-only final retry job5646b8a8-a86c-40de-b5da-afc9b3761a11/group5c748f5e-f4ff-4bfd-811e-a6e13268548a costs1generation. Dodge total17. No painted shadows, afterimages or dust added. Ground movement remains gameplay-owned.

## Tests before review publication
- Terminal socket access blocked downloads. PixelLab native inspect at1x returns exact palette raster with a labeled preview header; exported RGBA by removing header and nonpalette preview background. Verified the recovery method against existing NE raw source0: exact RGBA pixel match. This is data export, not redrawing/inventing source frames.
- Jumpv2 build: PASS192unique128RGBA poses,binaryalpha,no clipping. All168PNGs outsideNE byte-identical to v1. Full NE contact inspected: knees stay bent together; no kick extension.
- Jumpv2 Godot4.5.1 compatibility NE/S/E:24captures each PASS, only environmental certificate-store warning. Inspected NE airborne capture with no ellipse under sprite.
- Dodge initial second-batch build:96unique128RGBA poses,binaryalpha,no clipping; all8engine captures passed technically. Visual review caught north facing drift despite technical checks; final north retry preserves back-facing view. Final result recorded below before publishing.
- Removed only detached thin generated floor strokes from dodge via connected components <=80pixels,width>=9,height<=3, below60%canvas; character components retained. Original source pixels kept locally.
- GIFs decoded for frame count and timing before upload; final values recorded below.

## Files
Local source/jump-review-v2/, sprites/jump-review-v2/, source/dodge-review-v1/, sprites/dodge-review-v1/. Published review media and report only; jump/dodge not in accepted runtime manifest.

## Issues / limits
Native inspect export avoids blocked terminal downloads and was checked byte-exact against known source. Session Godot certificate warning is environmental. Grounded toe extents vary through evasive poses; no per-frame stabilization/scale change applied. Owner review is required for dodge style and compact NE jump height.

## Questions
None.

## Outstanding
Owner visual review; full Order01 incomplete. Live deployment: not applicable to review-only GIFs; this does not claim game integration or deployed Web testing.

Final pre-publication checks: north final12-pose contact inspected (back view retained), normalization96unique128RGBA/binaryalpha/no clipping PASS. Seven other dodge directions unchanged from tested second batch. Final north Godot capture12poses PASS, no runtime errors other than session certificate warning. Jump half-speed GIF24frames2000ms; dodge12frames1000ms, both800x1880 and infinite review loop, no ellipse shadows. New review files are linked from current-production-review.md.

Final publication: asset commit55dc1825e2f4ec9962418cccf3455088447848fb; preview/report follow-up3bb4013c413ff347ef0cdd6261a51051197cc87b; https://github.com/kiotdstudios/shinobi-rush/pull/23. Both published preview blobs fetched via GitHub connector and their Git blob hashes match local decoded/verified GIF bytes. No new live build claimed.
