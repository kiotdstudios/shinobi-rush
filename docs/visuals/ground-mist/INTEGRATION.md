# Blightwood ground-level mist

`GroundMist` is an independent presentation node under the y-sorted arena. It discovers current BlossomTree, DynamicShrine and existing Ancient Shrine shelter anchors every two seconds, including builder-created objects. Moving, hiding or deleting a source updates its wisps. Up to 24 nearby sources use a fixed pool of 48 ribbons; no per-frame spawning, collisions or gameplay writes.

Sixteen original generated silhouettes occupy 128×128 transparent atlas cells. They are **shape variants, not a sixteen-frame flipbook**. Each drifts continuously for 23–34.4 seconds, fades to zero at wrap, and curls by roughly two native pixels. Desynchronized phases and distinct shapes avoid marching clouds. Native nearest sampling preserves deliberate pixel clusters. Raw source is retained with `.gdignore`; the processor only keys, uniformly scales, registers, checks and exports.

Ground bands lie around the tree bases and the shrine's lower sides/stair mouth. They share actor Y sorting and never form a screen-space fog overlay. Peak alpha is 20%, reduced to 8% of that value in the player clearing ellipse. No player, enemy, combat, movement or camera controller is edited.

Review: `?mist=review` or `--mist-review`, with Normal, Half, Pause, Mist on/off and the unchanged player's WASD movement. Half speed changes environmental presentation only. `?mist=inspect` plays the actual map with read-only `__GROUND_MIST__` counters. Normal gameplay adds no browser telemetry.

Generation: built-in image_gen, after reviewing PixelLab's official MCP API and confirming configured access. PixelLab was not used for generation; an original thin-wisp atlas was more direct than a character animation job.

Kiro handoff: main `816f05a6` already failed its controls probe before this mist change (workflow 40361150485, job 121709646372: wall test began at y195.4 and stopped at y195.0, failing the required approach distance). The probe now first uses real S input to establish >50px approach clearance, then performs the original W movement/collision/stability assertions unchanged. This is test setup only; please retain it when changing the authored starting map. No controller or collision changes are included.

The small shelter is discovered by its existing texture resource path; the mist only reads its live Sprite2D anchor, so moving, hiding and deleting it works without changing editor-owned code.
