# Idle correction review v2
- Agent: Codex
- Related order: orders/Codex/order_01.md
- Date: 2026-10-18
- Status: REVIEW — revised mobile previews ready; full Order 01 remains incomplete
- Branch: codex/mobile-animation-preview

## Owner feedback and reference
South-east is the preferred idle: planted feet and smooth breathing.
South and north-east swayed sideways. South-west breathing was good but cycled
faster than south-east. The original source sets and earlier previews are preserved.

## Work completed
Generated new south and north-east candidates with PixelLab PixMiniMax (16 poses
each), pinned start/end poses and explicit one-breath/no-sway instructions.
Normalized with one common body scale and a per-clip fixed root; no per-frame
scale normalization, body warping or procedural character drawing.

South-west retains the first complete 8-pose breath from its original 16-pose
two-breath clip. It now displays each pose for two 24fps timeline ticks, giving
one breath per 16-tick/0.667s cycle. No interpolated or padded pose files were added.
This reduces temporal sampling to 8 unique poses; owner smoothness review remains
open. The timing manifest explicitly stores ticks_per_pose=2 for this direction.

South-east's 16 PNGs are byte-identical to the preferred version. East, north,
north-west and west were also copied byte-identically and were not redrawn.

## Generation receipts
- South group ca4d8e78-16de-412f-a1cc-0a33ca9be033, job f0a46f99-4082-4fd4-b244-5adcb77a304f.
- North-east group b0a12c16-bdbf-4800-a89d-05182920158d, job 62de0686-78be-42ef-8662-39a3190b44cf.
- Character 2b5a8809-cf01-46a4-8e85-0602dda701a2.
- Original source PNGs, request receipts and exact prompts kept locally under
  assets/characters/player/source/idle-review-v2/.

## Tests before commit
| Check | Actual result |
| --- | --- |
| refine_idle.py output containment and nonempty exports | PASS |
| South-east and four unmentioned directions byte identity | PASS |
| Source south-east first-frame SHA256 | 6cada12ce56d34132ae5d5942cd2b71c0b282d58c06850f65bd82d1bc05fb80b |
| New south and north-east unique poses | PASS; 16/16 each |
| Alpha-centroid horizontal drift measurement | See below; substantial reduction |
| Godot 4.5.1 Compatibility import and frame rendering | PASS; south, north-east, south-west, south-east; no runtime stderr |
| Review GIF decode | PASS; 16 synchronized display ticks, 600x1240, infinite looping |
| Normal / half / quarter GIF playback length | 670 / 1330 / 2670ms, within GIF centisecond precision |
| Visual inspection of full eight-panel review GIF | PASS for layout, identity, visibility and clipping; final motion preference is owner-reviewed |
| Order validator and staged diff checks | Run before preview commit |

Horizontal alpha-centroid span in output pixels:
| Direction / region | Earlier | V2 |
| --- | ---: | ---: |
| South head | 2.02 | 0.17 |
| South torso | 1.83 | 0.43 |
| South feet | 1.98 | 0.12 |
| North-east head | 4.12 | 0.22 |
| North-east torso | 4.61 | 1.04 |
| North-east feet | 0.12 | 0.00 |

These are region alpha-centroid measurements, not exact bone tracking. Chest
expansion changes silhouette centroid slightly; they substantiate reduced lateral
movement without claiming that every pixel is static.

## Files
Local tooling and sources: assets/characters/player/source/idle-review-v2/.
Local revised transparent frames/timing manifest: assets/characters/player/sprites/idle-review-v2/.
Published review media: assets/characters/player/previews/mobile/idle-v2-{normal,half-speed,quarter-speed}.gif.
This report.

## Issues encountered
Python urllib downloads were rejected with HTTP 403; the browser-compatible
PowerShell downloader fetched the exact returned URLs successfully.
No known render errors remain. This iteration is a review candidate, not final
all-state art acceptance or gameplay integration.

## Questions and next steps
Owner reviews whether south/north-east now have the desired restrained breathing
and whether south-west's retimed cycle feels right. Continue full Order 01 with
south-east as the idle motion standard. Source reference remains preserved.

## Deployment
No live game deployment applies to this art-preview-only change. Direct public
GIF links are verified after push. No main merge performed.
