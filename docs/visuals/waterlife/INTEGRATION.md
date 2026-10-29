# Waterlife art and integration

Original raw art: built-in image_gen, five separate calls (splash sequence, floating plant pack, purple frog sequence, foot chakra sequence, fly). PixelLab documentation/credentials reviewed; active balance 205.80 generations, no paid job submitted. The deterministic `scripts/art/build_waterlife.py` only removes magenta, extracts/aligns, uses shared nearest-neighbor scaling, exports sheets and checks uniqueness/edge contact. Raw art is preserved under `source/.gdignore`.

| Layer | Sheet | Cells | Timing | Origin |
|---|---|---|---|---|
| Water crown / expanding ripples | splash.png | 4×4, 128px | 16 frames over 0.72s footsteps / 1s frog dive | 64,96 |
| Concentrated blue foot chakra | feet-chakra.png | 4×4, 128px | 24 FPS loop, second foot offset 7 frames | 64,96 |
| Floating pad / lotus variants | plants.png | 3×2, 72px | independent bob/heave/roll phase per plant | 36,36 |
| Frog body + tongue | frog.png | 4×4, 128px | 0–0.55s arrival, to1.7s settle, to2.35s tongue, to3.1s recover, to3.65s dive | 64,104, rendered0.5× |
| Fly | fly.png | 9×7px | separate position and wing flutter | center |

All exported sprites are RGBA with nearest filtering; no baked ground rectangle, floor shadow, or background. Water is separate from the frog, fly and plant. Frog tongue stays anatomically attached in body poses, independent fly disappears at the catch beat. These assets do not replace character animation frames or reintroduce rejected full-body chakra art.

`Waterlife` observes the real player's water state and actual displacement, places each contact once in a fixed32-slot stationary world-space pool, and fades old rings after travel. No extrapolated trail points, movement mutations or RNG per frame. No running spray when standing, dry, airborne, dying, on a bridge or after a teleport-sized jump. Foot chakra remains faintly visible for stationary water stance. Fixed two-foot offsets are presentation estimates; no new player anatomy/foot socket data is invented.

`Main/TrainingArena/Waterlife` is a presentation node. Changes to `DustPuff.play` suppress existing dry-land dust over water. Existing water-chakra drain and bridge exclusions stay owned by the original gameplay controller. Aki integration handoff: this feature reads those rules; further foot socket authoring can refine exact toe contact without changing this art pack or gameplay timers.

Review: `?waterlife=review`, Normal/Half/Pause/Step/Frog again. The running loop is clearly labeled staged art; forced frog is preview-only. Production probability and eligibility are documented in [Chief's note](CHIEF-NOTE.md).

## 2026-10-29 contact/recovery revision

Lilies and lotuses react to actual wet crossings with a bounded dip/drift/tilt and recover at deterministic individual rates (2.6–5.4/s), including after the player stops or exits. Actual water elevation controls their resting draw position; ground anchors never move. No movement/chakra or rare-frog rules change. [Integration and evidence](../purple-lilies/README.md).
