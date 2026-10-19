# Sprite drop-in contract (Codex -> Shinobi Rush prototype)

Drop art in, push, open the live build, judge animation and size. **No code edits needed.**
Until a valid set exists the game shows the labeled PLACEHOLDER figure and
`SPRITES: none (placeholder)`.

## 0. Production standard (owner-approved 2026-10-18)

**Every production character frame is 128x128 RGBA (base `frame_size` [128, 128]).** This is locked and overrides
any earlier 64 vs 128 evaluation. Standing height is about 100-112 px (default 108), with a consistent foot anchor
and unchanged body scale in every animation. Overflow canvases (192/256, at least 128 in both dimensions) are
allowed per animation for attacks/VFX that extend outside the base frame, with the same body scale and foot anchor.
64x64 art is legacy REFERENCE only, never a production set. Keep it under `references/`, `previews/`, `source/` or
`study/` (not shipped). The validator rejects a production manifest whose base `frame_size` is not [128, 128].

## 1. Folder layout

```
assets/characters/player/
  <anything>.manifest.json        <- every *.manifest.json under assets/characters/ is one SPRITE SET
  sprites/idle/S_000.png ...      <- per-frame form
  sprites/run.png                 <- sheet form
  animations/                     <- also fine; paths in the manifest are relative to the manifest file
  source/                         <- NOT shipped in the Web build (excluded from the PCK); keep big masters here
  references/  previews/  study/  <- NOT shipped (excluded from the PCK); legacy 64x64 reference art lives here.
                                     Put an empty .gdignore in each so Godot does not import the PNGs.
```

**Runtime files (anything a manifest points to) must live under sprites/ or animations/, not source/.**
Everything else under assets/characters/ that Godot imports is shipped and counts toward load size.

Revisions or overflow-canvas variants can be kept as **separate manifests with different `id`s** (e.g. `player_v1`,
`player_v2`); the lab compares the first two sets (sorted by id). Compare is for any two sets, not a scale decision.

## 2. Manifest schema v1 (parsed tolerantly: unknown keys are ignored)

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
                          "E": ["sprites/idle/E_000.png", "sprites/idle/E_001.png"] } },
    "run":  { "fps": 24, "loop": true, "sheet": "sprites/run.png", "columns": 20,
              "rows": ["S", "SE", "E", "NE", "N", "NW", "W", "SW"] },
    "dodge": { "fps": 24, "loop": false, "frame_size": [192, 192], "foot_anchor": [96, 180],
               "sheet": "sprites/dodge.png", "columns": 16, "rows": ["S", "E", "N", "W"] }
  }
}
```

- `frame_size`: 128x128 RGBA (required for the base). Overflow canvases (192/256, >= 128 in both dimensions) for wide
  attacks: set `frame_size` (and usually `foot_anchor`) on that animation only.
- `foot_anchor`: pixel inside the frame that sits on the ground-contact point (the player origin).
  Collision footprint and shadow never move. Mirroring flips around this anchor.
- `body_height_px` (optional, default 108): drives the height ruler. Target 100-112 on the 128 frame (the validator warns outside it).
- **Per-frame form**: `frames` = direction -> list of PNG paths, in play order.
- **Sheet form**: `sheet` PNG, `columns` frames per row, `rows` = one direction name per row, cell size =
  `frame_size`. Sheet size must be `columns*frame_w` x `rows*frame_h`. Optional `frame_count` (<= columns)
  when a row is not full.
- `fps` > 0 (author at 24), `loop` true/false.

## 3. Directions and fallback

Names: `N NE E SE S SW W NW` (screen space, S = toward the camera). N/S/E/W is the minimum.
For a missing direction the game uses, in order: (1) its own frames, (2) the `mirror` source flipped
horizontally, (3) for a diagonal: the vertical cardinal, then the horizontal one (own or mirrored),
(4) the nearest available heading. A missing cardinal with no mirror is a manifest error.

## 4. Animation ids and gameplay use

| id | used by gameplay |
|----|------------------|
| `idle` | no input (falls back to frame 0 of run/walk) |
| `run` | moving without sprint (falls back to `walk`) |
| `walk` | only as the fallback for `run` |
| `sprint` | moving with Shift / R1 (falls back to `run`). Must look distinct from `run` |
| `dodge`, `jump`, `light`, `heavy`, `hit` | no gameplay yet; preview them in the lab |

Any other id in the manifest is previewable too. The player uses the first valid set, or the set picked in the lab.

## 5. Preview in the lab

`Tab` (or the Lab button) toggles the panel, the turntable stand beside the spawn point and overlays.
Every function has a key and a clickable button. The status line is always on screen:
`SPRITES: none (placeholder)` | `SPRITES: <id> <WxH> OK` | `SPRITES: <id> ERROR: <first problem>`.

| key | action | key | action |
|-----|--------|-----|--------|
| `[` `]` | set prev/next (incl. placeholder) | `P` / `O` | pause / single-step |
| `,` `.` | animation prev/next | `C` | compare any two sets side by side |
| `;` `'` | direction prev/next | `Z` or wheel | zoom: wide, 1x-4x |
| `V` | direction mode follow / fixed / spin | `1`-`6` | iso grid, square grid, anchor, footprint, height ruler, frame box |
| `-` `=` | speed 0.25x-2x | gamepad | Back = lab, R-stick click = compare, L-stick click = zoom |

Zoom steps are `wide` (the gameplay baseline, `WorldScale.CAMERA_BASE_ZOOM` = 1/2.25, panel label "wide 0.44x"),
then `1x` (native 1:1 pixels: a 128x128 frame is 128 screen px), `2x`, `3x`, `4x`. The lab opens at the baseline without
moving the camera, `Z` wraps from `4x` back to the baseline, and closing the lab with `Tab` restores the baseline.
At the baseline a 128x128 production frame is drawn at about 0.44 scale (the 108 px figure is about 48 screen px, shown
by the nearest-neighbour filter), so check fine detail at `1x` and also at the baseline. (64x64 art is a legacy
non-production reference only.)

The metrics line shows set id, frame size, animations/frames loaded, load ms and texture memory
(`RENDER_TEXTURE_MEM_USED`) so you can compare the cost of two sets or overflow canvases. Sets load lazily on first use.
Grids: the iso grid is 144x72 diamonds (`WorldScale.TILE_SIZE`, drawn 2:1); the square grid is plain 32 px.

## 6. Links and CI

- Live link (expected, not yet verified): https://kiotdstudios.github.io/shinobi-rush/ . It answers HTTP 404 until
  the first deployment from `main` has been verified.
- Deep link query (`?set=&anim=&dir=&zoom=&lab=1`) is **not implemented yet** (follow-up); use the keys.
- CI check: `scripts/ci/validate_sprite_manifests.py` (Python stdlib only) checks every `*.manifest.json` under
  `assets/characters/`: JSON parses, `schema` is 1, ids are unique, `frame_size`/`foot_anchor`/`fps` are valid,
  directions are known and the N/S/E/W cardinals exist (own frames or `mirror`), every referenced file exists,
  each PNG is exactly `frame_size` (read from the PNG header) and each sheet is `columns*frame_w` x `rows*frame_h`.
  Run it locally from the repo root: `python scripts/ci/validate_sprite_manifests.py` (exit 0 = fine, or
  nothing to validate). Problems print as `::error file=<path>::<message>`. In CI the `detect` job of `Godot CI` runs it on every
  pull request and push and annotates the offending manifest; its unit tests run in `Pipeline self-test`. The in-game
  status line plus the browser console warning remain your feedback while authoring.
- Web preset ships `*.json`, so manifests and PNGs are inside the PCK.
- Size budget: a full 128x128 set (1024 frames) costs about 85 MiB of GPU texture and 8 to 49 MiB of download (flat art to worst case) as sheets; use one
  sheet per animation, not loose frames. Measured numbers and recommendations:
  [GODOT_CI_AND_DEPLOYMENT.md](../development/GODOT_CI_AND_DEPLOYMENT.md#performance-budget-for-a-full-128x128-set-measured-2026-10-18).

## 7. Definition of ready

- [ ] manifest(s) under `assets/characters/`, `schema: 1`, unique `id`, status line says `OK`
- [ ] base frame 128x128 RGBA (overflow canvases >= 128 in both dimensions, same body scale and foot anchor); no 64x64 production frames
- [ ] `foot_anchor` set; feet sit on the crosshair in every animation (lab overlay `3`)
- [ ] standing height 100-112 px on 128, target 108 (ruler `5`, `body_height_px` filled in)
- [ ] 8 directions or N/S/E/W + `mirror` entries
- [ ] `idle`, `run`, `sprint` (distinct from run) present; others as available
- [ ] no jump when switching run <-> sprint (watch with `C`/`P`/`O`)
- [ ] integration note: frame sizes, ids, fps, anchor, collision recommendation, transitions
