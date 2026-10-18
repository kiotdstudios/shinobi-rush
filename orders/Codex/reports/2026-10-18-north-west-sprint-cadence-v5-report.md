# Job Report - North-west sprint cadence v5
- Agent: Codex
- Order: Order01
- Date: 2026-10-18
- Final status: REVIEW - owner assessment pending
- Commit / PR: adf264b; https://github.com/kiotdstudios/shinobi-rush/pull/3

## Work completed
Audited owner-reported repeated-looking north-west sprint. Previous20 PNGs are distinct, GIF holds80/90ms; no doubled hold. Similar gait poses recur about9frames apart inside20frames, leaving an incomplete gait phase at the boundary. This is a motion-cadence diagnosis, not proof of duplicate images.

PixelLab PixMiniMax generated a north-west-only candidate from the existing leaning sprint reference: job6ec5b199-796e-4bd8-a840-ad88f0cd944b, group75005980-e249-4d20-abd7-ecd9b565dfec, cost1generation,20source frames. Source11 returns close to source0 (637 changed pixels) and starts a second partial recurrence. Retain source0-10 as one complete11-pose cycle; discard the trailing incomplete recurrence. No copied/warped filler frames. All11 remain unique. Authored24fps/default0.5x means12poses/sec and about0.917seconds per complete cycle. The actual GIF rounds to920ms. This cycle length differs from the previous20-frame review container; the reviewed gait itself previously recurred sooner than20frames.

Seven other directions retain exact v4 PNG bytes, including straight-south and moving-north revisions. Focused NW preview plus independent before/after playback avoids padding the11-pose cycle to20. Comparison runs220ticks, the common boundary of20 and11, at12ticks/sec; each side loops independently at the same pose rate.

## Files changed
Local source/art/scripts/manifest/evidence: assets/characters/player/source/sprint-review-v5/ and assets/characters/player/sprites/sprint-review-v5/. Source indices and per-direction loop lengths recorded in manifest. Review branch publishes4 focused GIFs, README and this report. Full production source handoff remains pending accepted set.

## Tests performed before commit
- Bundled Python frame audit: previous20 unique, no GIF hold above90ms; measured recurring similar poses. Audit JSON retained.
- build_review.py: PASS151 unique128x128 RGBA frames, binaryalpha, no clipping; NW11poses, seven other directions20 each. Seven directions/140 PNGs byte-identical to v4. NW silhouette88-100px; uniform104/108scale and clip-level root preserved.
- Inspected generated20-pose contact and final loop seam10,11,1,2: continuous alternating stride, forward lean, both arms swept back. No copied torso or duplicate poses.
- render_review.py: PASS11-frame focused loops normal460ms/half920ms/quarter1830ms; comparison220frames18330ms. Independent playback avoids incomplete resets caused by a shared20-frame container.
- stage_godot.py and run_review.ps1: PASS north-west11captures, south20 and north20, Godot4.5.1 OpenGL compatibility, zero runtime stderr. Inspected NW engine capture.
- Order validator and staged diff check executed before implementation commit.

## Issues encountered
AI generation again supplied an incomplete trailing recurrence, removed by retaining the complete first cycle. Eleven purposeful poses replace the20-frame candidate; animation frame targets are not compulsory filler. Visual owner acceptance remains pending, including cadence and facing.

## Questions for project owner
None. Focused preview supplied.

## Outstanding work / next steps
Owner review. Order01 remains incomplete. Live deployment: not applicable to review-only GIFs; no gameplay code changed or live-game validation claimed.

Public verification after push: focused half-speed GIF HTTP200,11frames,920ms; before/after HTTP200,220frames,18330ms.
