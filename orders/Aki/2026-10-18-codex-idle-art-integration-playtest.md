# ORDER — Aki: integrate and playtest Codex-approved idle artwork

- **Agent:** Aki
- **Status:** BLOCKED (corrected 2026-10-18) — Animation Lab confirmed already live in the deployed build (`scenes/main.tscn` -> `scripts/ui/animation_lab.gd`, reachable via Tab) with every control requested (anim/direction/speed/zoom) already built. Correction to the earlier BLOCKED note: the 128x128 art is NOT missing — per Codex's own reports (idle-shoulders-v5, south-run-cadence-v4, ninja-sprint-v1..v5), real native 128x128 QA-passed frames/manifests already exist for idle v5 (approved), walk v1 (approved), run v4 (approved), and ninja sprint v5 (review candidate, pending owner's final approval) -- they were simply never committed/pushed to git (confirmed via `git log --all --diff-filter=A` for `*.manifest.json` and `assets/characters/player/sprites/*`: zero hits across all branches/history). Re-filed handoff request at `orders/Codex/2026-10-18-idle-128-production-handoff.md` asking Codex to PUSH the existing assets, not produce new ones. See `orders/Aki/reports/2026-10-18-codex-art-integration-playtest-report.md` for full detail. Resume the moment Codex pushes the branch + commit SHA.
- **Priority:** P1
- **Owner:** Aki (runtime integration and test); **Codex retains ownership of art assets**; Kiro retains deployment/camera fixes
- **Scope:** Temporary, reversible Godot art integration / browser playtest; dedicated branch and PR
- **Owner decision:** Codex's current idle character artwork is approved; production character frames **MUST be 128×128 transparent RGBA**.

## Objective
Take Codex's existing owner-approved character idle assets, if they are actually available in the repository or provided by Codex, load them using the existing sprite manifest/drop-in pipeline, and validate their appearance and behavior in the playable Shinobi Rush training arena.

## Instructions
1. First locate and inspect Codex's actual committed art files and metadata (including PR #3 and Codex branches). **Do not assume preview GIFs, concept images, or 64×64 samples are valid shippable 128×128 animation sheets.** If the approved production-ready 128×128 assets are missing, request an exact handoff from Codex; mark BLOCKED and do not fabricate or upscale art.
2. Confirm every standard production frame is native **128×128 RGBA**, proper transparent background, correct frames/direction naming, feet/ground anchor, proportions and animation cadence. Use existing `docs/prototype/SPRITE_DROP_IN.md` and asset validator.
3. Load into the game's actual player via the existing sprite library/manifest, without overwriting Codex's sources. If not ready for player integration, use a separate art-lab/test scene and report why.
4. Test idle animation in at least south, north, east/west and diagonals where supplied; check jitter, frame alignment, layering, floor contact, camera zoom at owner's preferred **earlier wide framing** (PR #12), walls/Y-sort occlusion (PR #9), collisions and clipping. Do not fix Kiro's camera/wall code concurrently; document findings for Kiro.
5. Test movement and sprint using the current available art states; do not fake missing animations or silently reuse idle as completed run animation. Flag gaps clearly for Codex.
6. Validate import, tests, Web export, Chromium smoke and any telemetry output that exists. Measure approximate FPS/texture usage and note actual browser/hardware limitations. Supply screenshots/video evidence for owner approval.
7. Coordinate with Codex on approved artwork and animation readiness; Kiro on PR #12 camera and PR #9 occlusion. Do not merge conflicting code or deploy without CI/review.

## Acceptance / report
- Either an actual working, reversible in-engine preview using approved native 128×128 art with before/after screenshots and test results; OR a precise BLOCKED report naming missing art files and requested Codex deliverables.
- No claims of finished gameplay or new art if only previews exist.
- Write `orders/Aki/reports/YYYY-MM-DD-codex-art-integration-playtest-report.md` with branch/PR, assets and SHA, frame sizes, manifest, test evidence, FPS, problems and handoff requests.
