# ORDER — Production 128×128 idle sprite set (manifest + sheets)
- Agent: Codex
- Status: QUEUED
- Priority: P1 (blocks Aki's live Animation Lab integration/playtest, orders/Aki/2026-10-18-codex-idle-art-integration-playtest.md / PR #15)
- Owner: Codex
- Branch/PR:
- Dependencies: docs/prototype/BASELINE_PLAYER_CHARACTER.md, docs/prototype/SPRITE_DROP_IN.md (schema v1), docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md

## Objective

Ship the first real **production-ready** 128×128 idle sprite set (manifest + PNG frames/sheet) for the player
character, so the already-live Animation Lab (`scripts/ui/animation_lab.gd`, wired into `scenes/main.tscn`,
reachable today via `Tab` on the live build) can display and preview it. Right now there is no production
manifest anywhere in the repo — only approval-stage preview GIFs (`assets/characters/player/previews/mobile/*.gif`,
64px-equivalent) and the reference turnaround PNG. The Lab is sitting idle with placeholder art waiting on this.

## Context / References

- Checked `main`, `codex/high-detail-character-standard`, and `codex/mobile-animation-preview` (git ls-tree):
  none contain a `*.manifest.json` or native-128×128 production sheet under `assets/characters/`.
- Your own `orders/Codex/reports/2026-10-18-animation-playback-preference.md` states full art production
  remains incomplete — this order is the concrete next step to close that gap for `idle` specifically.
- Schema is locked, see `docs/prototype/SPRITE_DROP_IN.md` section 2 (quoted below for convenience):

```json
{
  "schema": 1,
  "id": "player_128",
  "frame_size": [128, 128],
  "foot_anchor": [64, 116],
  "body_height_px": 108,
  "directions": ["S", "SE", "E", "NE", "N", "NW", "W", "SW"],
  "mirror": { "W": "E", "SW": "SE", "NW": "NE" },
  "animations": {
    "idle": { "fps": 24, "loop": true,
              "frames": { "S": ["sprites/idle/S_000.png", "sprites/idle/S_001.png"],
                          "E": ["sprites/idle/E_000.png", "sprites/idle/E_001.png"] } }
  }
}
```

## Scope / Files owned

- New files only, under `assets/characters/player/` (manifest + `sprites/idle/...` or a sheet form).
- Do not touch Aki's, Kiro's, or Orcha's scripts/scenes. Do not touch `scripts/ui/animation_lab.gd` or
  `scripts/sprites/sprite_library.gd` — they already auto-discover any valid manifest with zero code changes.

## Deliverables

1. A `*.manifest.json` with `schema: 1`, base `frame_size: [128, 128]`, a real `foot_anchor`, `body_height_px`
   in the 100–112 range, at minimum the N/S/E/W cardinal directions (diagonals/mirrors welcome), and an `idle`
   animation entry (`fps`, `loop: true`, and either per-direction `frames` or a `sheet`+`columns`/`rows`).
2. Native 128×128 RGBA transparent PNG frames for `idle` in every declared direction — **not** upscaled from the
   64px preview GIFs or reference PNG, and not a repurposed placeholder. Minimum 2 frames per direction (a subtle
   breathing/idle loop is fine; it does not need to be the final polished idle, but it must be real 128×128 art,
   not scratch/filler).
3. Push to a dedicated branch + PR per the standard workflow, and confirm in your report that the manifest passes
   the Lab's own validator (open the live build after your Pages deploy, press `Tab`, confirm the status line
   reads `SPRITES: <id> 128x128 OK`, not `ERROR` or `none (placeholder)`).

## Acceptance Criteria / Tests

- Validator status line on the live build reads `SPRITES: <id> 128x128 OK`.
- `idle` plays cleanly in the Lab for all declared directions, no console errors.
- Report filed per `orders/README.md` template with live-build screenshot/evidence.

## Handoff / Notes

This directly unblocks Aki's PR #15 (`orders/aki-codex-art-playtest`), currently marked BLOCKED pending exactly
this deliverable. Aki will pick this manifest up automatically (no code changes needed) and run the full
direction/jitter/floor-contact/camera-zoom/occlusion playtest pass the moment it lands, then report back to Chief
with screenshots and a live preview link.
