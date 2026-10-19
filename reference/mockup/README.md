# Reference mockups (framing and scale references only)

Owner-supplied images used as VISUAL REFERENCES. They are not game assets. This folder has an empty `.gdignore`, so Godot does not import or export anything here, and no game code may load these files.

| File | What it is | Added |
| --- | --- | --- |
| `owner-close-combat-reference.png` | The owner's close-up faux-isometric shrine combat screenshot (1536x1024). The framing reference named in [Camera and Art Direction](../../docs/visuals/CAMERA_AND_ART_DIRECTION.md) ("OWNER-APPROVED GAMEPLAY CAMERA FRAMING - 2026-10-19") and in the GDD section "Owner-approved gameplay camera and scale". | 2026-10-19, with the owner's permission to keep it in git |

## How to use it
- It is the target for camera distance, how prominent the player and enemies are, relative architectural scale and visual density.
- It is NOT permission to copy its shrine map, characters, insignia, HUD or effects. Kosen keeps its own identity and Codex's approved player design.
- Compare against our own 1280x720 gameplay screenshots by viewport-height fraction, not by pixels: this image is 3:2 and our viewport is 16:9.

## Measured numbers (head to boot, read off a pixel ruler, accuracy about +/-5 px; 2026-10-19)
| Figure | Height | Share of the 1024 px image height |
| --- | --- | --- |
| Enemy, top left | 164 px | 16.0% |
| Enemy, lower left | 159 px | 15.5% |
| Enemy, top right | 166 px | 16.2% |
| Enemy, lower right | 171 px | 16.7% |
| Player (deep lunge) | about 170 px | 16.6% |

- Mean 166 px = 16.2% (about 117 px at 720p). All of these are crouched combat stances. A figure standing upright is probably 15-25% taller (an assumption, not measured), which would be about 18.5-20%.
- The current provisional camera target is 17.5% of viewport height (`CameraPreset.CLOSE_FIGURE_FRACTION`), inside the 16-19% band. It stays until Codex's real sprite can be seen at that scale.
- The floor in the image is paved with slabs roughly 0.4-0.6 of a figure's height wide (by eye, uncertain), much finer than the arena's 144x72 world-unit ground diamonds. The tile size is not decided.
