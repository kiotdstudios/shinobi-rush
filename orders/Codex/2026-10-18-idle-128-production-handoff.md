# ORDER — Push existing approved 128×128 art (idle/walk/run) + sprint candidate to git
- Agent: Codex
- Status: QUEUED
- Priority: P1 (blocks Aki's live Animation Lab integration/playtest, orders/Aki/2026-10-18-codex-idle-art-integration-playtest.md / PR #15)
- Owner: Codex
- Branch/PR: dedicated new branch, isolated from `codex/mobile-animation-preview` and `codex/high-detail-character-standard`
- Dependencies: docs/prototype/SPRITE_DROP_IN.md (schema v1)

## Objective

**This is a push request, not a production request.** Per your own job reports, the real native 128×128 RGBA
sprite frames, spritesheets, and manifests for idle, walk, run, and ninja sprint already exist, already passed
your own QA (frame-integrity/alpha/scale/Godot-capture checks), and the owner has already approved idle v5,
walk v1, and run v4. They were deliberately left unpublished — only review GIFs were committed. Do not
regenerate, re-pose, or produce any new art for this order. Just commit and push what you already built.

## Context / References

Confirmed by reading your own reports on `codex/mobile-animation-preview` — each one states the real assets were
built and tested but kept out of the published branch:

- `orders/Codex/reports/2026-10-18-idle-shoulders-v5-report.md`: *"Normalized frames and manifest:
  `assets/characters/player/sprites/idle-review-v5/`. Mobile review GIFs/README and this report only are
  published on the existing preview branch. Full art implementation remains separate."* — **idle v5, owner-approved.**
- `orders/Codex/reports/2026-10-18-south-run-cadence-v4-report.md`: *"Normalized frames/manifest:
  `assets/characters/player/sprites/run-review-v4/`. Published branch limited to review GIFs/docs/report."*
  — **run v4, owner-approved** (south cadence fix).
- Walk v1 is referenced as approved ("Idle v5 approved by the owner... accepted idle v5, walk v1 and run v3 are
  preserved") in the same pipeline; locate and push its corresponding `sprites/walk-review-v1/`-style output
  alongside idle/run.
- `orders/Codex/reports/2026-10-18-ninja-sprint-v1-report.md` (and the later v2-v5 revision reports):
  *"Normalized PNG exports/sheets/manifest: `assets/characters/player/sprites/sprint-review-v1/`. Published
  branch limited to GIF review artifacts, documentation and this report."* — **ninja sprint, status
  "owner assessment pending," not yet final-approved.** Push the latest accepted revision (v5, north-west
  cadence fix) as a review candidate; the owner will give final sprint approval after seeing it in the Lab.
- Confirmed via `git log --all --diff-filter=A` across every branch and all of history: zero `*.manifest.json`
  and zero `assets/characters/player/sprites/*` paths have ever been committed to this repo. This is a push
  gap, not a missing-art gap.

## Scope / Files owned

- New files only, under `assets/characters/player/sprites/` (or wherever your existing local output already
  lives) plus the manifest(s). Use a **new, isolated branch** — do not reuse or modify
  `codex/mobile-animation-preview` or `codex/high-detail-character-standard` in place, and do not touch any
  file owned by Aki, Kiro, or Orcha. This keeps the push independent of Kiro's ongoing wall-occlusion work.

## Deliverables

1. Commit and push the **actual existing, already-QA'd** native 128×128 RGBA frames/spritesheets for:
   - **Idle v5** (approved)
   - **Walk v1** (approved)
   - **Run v4** (approved)
   - **Ninja Sprint v5** (review candidate — label clearly as pending final owner approval, do not mark it
     "approved" in the manifest or report)
2. A `*.manifest.json` per `docs/prototype/SPRITE_DROP_IN.md` schema v1 (`schema: 1`, `frame_size: [128,128]`,
   real `foot_anchor`, `body_height_px`, at least N/S/E/W, `mirror` where applicable) covering these four
   animations — one manifest with multiple `animations` entries, or multiple manifests, whichever matches how
   your local output is already structured. Do not restructure or re-export anything that already passed QA;
   just verify the paths are correct and shippable (i.e. under `sprites/` or `animations/`, not `source/`,
   per the drop-in contract's "not shipped in the Web build" rule).
3. **Verify the actual file paths before pushing** — confirm every path the manifest references resolves to a
   real committed file, confirm frame_size is genuinely 128×128 on disk (not inherited from an older 64px
   source), and confirm nothing under `source/`/`references/`/`previews/`/`study/` is required at runtime.
4. In your report: state the **exact branch name and commit SHA** you pushed, and open a PR to `main` (or leave
   it open for Aki/the owner to review — state which).

## Acceptance Criteria / Tests

- Branch pushed, exact branch name + commit SHA stated in your report.
- Manifest(s) validate against the schema (run `scripts/ci/validate_sprite_manifests.py` if present, or
  describe the equivalent manual check) — base `frame_size` must be `[128, 128]`, never a 64px legacy value.
- Open the live build after deploy (or confirm Aki will), press `Tab` in the Animation Lab, confirm the status
  line reads `SPRITES: <id> 128x128 OK` for the idle/walk/run/sprint sets, not `ERROR` or `none (placeholder)`.
- Ninja sprint must be clearly distinguishable in the manifest/report as a review candidate pending the
  owner's final approval, not shipped as final.

## Handoff / Notes

This directly unblocks Aki's PR #15 (`orders/aki-codex-art-playtest`), currently BLOCKED pending exactly this
push. The moment this lands, Aki will drop-in test it through the already-live Animation Lab (no code changes
expected — `SpriteLibrary` auto-discovers any manifest under `assets/characters/`), run the full
direction/jitter/floor-contact/camera-zoom/occlusion playtest pass (flagging any occlusion findings for Kiro
without touching his files), and hand the owner a live browser preview link covering idle, walk, run, and
ninja sprint. Sprint remains subject to the owner's final approval after they see it live.
