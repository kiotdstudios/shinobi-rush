# Testing the prototype (stage 2A, PLACEHOLDER art)

All commands run from the repository root with the pinned Godot (see `scripts/ci/godot-version.env`).
`godot` below means that binary (`Godot_v4.7.2-stable_*`).

## Unit tests (dependency-free)

```
godot --headless --path . --import          # once on a fresh clone (builds the class_name cache)
godot --headless --path . --script res://tests/run_tests.gd
```

Prints one `PASS`/`FAIL` line per check and `SUMMARY: N passed, M failed`; exit code is non-zero on any failure.
The suite does not depend on what is committed under `assets/characters/`: committing real sprite sets does not
break it. Parser fixtures are written to `user://shinobi_tests` and removed afterwards. It also drives the real
lab (speed, direction mode, wheel zoom, button/key parity) and the pause action.

## Sprite manifest validator (stdlib Python)

```
python scripts/ci/validate_sprite_manifests.py
python -m unittest scripts/ci/test_validate_sprite_manifests.py
```

With no manifests the validator exits 0 ("nothing to validate"). Failures print `::error file=<path>::<message>`.

## Run, export and serve

```
godot --path .                                                    # run in an editor-less window (needs a display)
godot --headless --path . --export-debug Web exports/web/index.html   # single-threaded Compatibility Web export
python -m http.server 0 --bind 127.0.0.1 --directory exports/web  # prints the ephemeral port; open http://127.0.0.1:<port>/
```

`exports/` is ignored by Godot (`exports/.gdignore`) and by git. The export needs the matching Web export
templates installed. CI uses `scripts/ci/godot_ci.py export`, then `finalize-export` and `check-export`.

## Manual checklist (about 3 minutes)

- [ ] The title, `BOOTSTRAP BUILD - PLACEHOLDER ART` and `SPRITES: none (placeholder)` (or the set status) are readable.
- [ ] `WASD` moves the player; `Shift` sprints (leaning pose, visibly different from walk); diagonals are not faster.
- [ ] World scale (D4): the PLACEHOLDER figure is about 108 px tall (the ruler `5` agrees), the footprint ellipse is about
      50x27, tiles are 144x72 (`1` iso grid) and blocks tower over the figure like real props. All of these come from
      `scripts/world_scale.gd` (one factor, 108/48 = 2.25 applied to the old 64-era values). They are PROVISIONAL
      prototype values for Aki/Orcha to re-tune (speeds, acceleration, friction, bounds, blocks), not balance.
      `tests/run_tests.gd` derives its expectations from those constants, so re-tuning them needs no test edits.
- [ ] Walking into a block or the arena edge stops the player; the player passes in front of and behind blocks.
- [ ] `Esc` shows PAUSED and freezes movement; `Esc` again resumes.
- [ ] With a sprite set: `Tab` opens the lab; set, animation, direction, speed, pause/step, compare (any two sets), zoom and the
      six overlays work both by key and by clicking the panel buttons.
- [ ] Sprite sets are 128x128 base frames (overflow canvases >= 128), the ruler (`5`) reads 108 px by default and
      the placeholder/fallback frame box is 128x128. 64x64 art is legacy reference only (not in a shipped folder).
- [ ] Switching run and sprint does not move the feet (anchor crosshair stays on the footprint ellipse).

## Browser console checklist (Web build, DevTools console)

- [ ] No red errors at startup or while playing.
- [ ] No `SpriteLibrary:` or `SpriteSet:` warnings. They name the manifest and the problem (bad schema, missing file,
      wrong PNG or sheet size). The same text is shown on the HUD status line.
- [ ] Benign and ignorable: Chromium `GPU stall due to ReadPixels` (software rendering / screenshot pixel reads).
- [ ] The page publishes `window.__SHINOBI_READY__ === true` and `window.__SHINOBI_STATE__`
      `{frame, x, y, state, sprinting, fps}` (about 10 Hz). A browser test can hold `KeyD` and watch `x` grow, or hold
      `Shift+KeyD` and see `sprinting === true`.

## Reserved actions (InputMap only, NO behavior yet)

They exist so later work can bind them without remapping. Pressing them does nothing.

| action | keyboard | gamepad |
|---|---|---|
| `aim_left/right/up/down` | arrow keys | right stick |
| `attack_light` | `J` | Square (X) |
| `attack_heavy` | `K` | Triangle (Y) |
| `dodge` | `Space` | Circle (B) |
| `jump` | `F` | Cross (A) |
| `heal` | `E` | L1 |
| `substitution` | `Q` | L2 |
| `jutsu_modifier` | none | R2 |

Implemented: `move_*` (WASD, left stick, D-pad), `sprint` (`Shift`, R1), `pause` (`Esc`, Options).

## Not covered

Gamepad input is configured in the InputMap but cannot be verified in CI. Software-rendered browsers run the game
at a few FPS, so the 60 FPS target is not measured in CI.
