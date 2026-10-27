# PR 224 — traversal transitions

Execution reassigned to Codex by the owner on October 26. Both character visual drivers share a presentation-only transition clock. Gameplay state, acceleration, friction, speed, collisions, action buffers, AI decisions, camera, attack timing and tap-L2/hold-L2 remain authoritative.

## Asset audit and reuse

Player: idle/walk 16 frames, run/sprint 20 frames per heading, 12 FPS playback. Bandit: idle 4 frames at 4 FPS; run/sprint 8 frames at 12 FPS. Bandit walking uses the existing velocity-scaled run cadence; no separate walk rig is assumed. Both use native 128×128 RGBA, feet `(64,116)`, standing scale 104 px, literal `S SE E NE N NW W SW` exports. No added mirroring or rotation.

The brief allows suitable existing art to be reused. These clips curate the approved contact, weight-transfer, push-off and neutral poses, without generating a replacement character design. Existing PNGs are referenced directly by the new manifest clips. `pose-inventory.json` records each source path and SHA256. Every three-pose clip has distinct source frames, fixed canvas/origin and unchanged pixels. No duplicate texture payloads are shipped.

| Manifest name | Duration | Frames | Handoff |
| --- | --- | --- | --- |
| move_start / move_start_sprint | 100 ms | 3 | run/sprint after push-off |
| move_stop / move_stop_sprint | 130 ms | 3 | exact idle origin |
| move_pivot / move_pivot_sprint | 120 ms | 3 | run/sprint after turn |

All six names exist for both actors, each with all eight headings. Pivot samples source, intermediate and target directional silhouettes; the sprite transform is never rotated. Run launch reuses idle 0, run 1 and run 2. Sprint launch uses run 1, sprint 2 and sprint 3. Brake reverses weight transfer from gait 2 through run 1 to idle 0. Pivot uses gait 0/1/2 with the heading change. Sheets show the literal source poses; the runtime comparison shows the direction-changing pivot.

## Integration

`LocomotionTransition` only selects presentation frames. Player traversal calls it once per physics tick with actual movement intent; movement has already been integrated before selection. Bandit uses its existing state, velocity and facing, with no new AI state. Transitions cannot move bodies or spawn footsteps, dust or hitboxes. Existing audio/contact clocks remain the only emitters.

Death/hit/action playback interrupts and clears the transition. New movement immediately cancels braking. Sharp turns use dot ≤ 0.20 (~78.5°), so 90° and 180° changes trigger while small steering does not. A 120 ms stable-heading window recognizes quick keyboard corners through a diagonal intermediary; a 220 ms cooldown prevents restarts under alternating input. All clips are non-looping. Missing transition art returns to existing run/sprint/idle resolution without blank frames or errors. The default lab `set_pose` API remains explicit loop playback.

## Review

`?movement=review` runs the actual player controller and bandit patrol in a traversal fixture. WASD moves, Shift/R1 sprints, normal combat controls remain available. Normal and Half speed buttons affect only this isolated review scene. `&before=1` disables the new visual layer for comparison while preserving identical controllers and physics. Read-only `window.__MOVEMENT_REVIEW__` reports animation names, frames, positions and observed transition counts. This route is not the normal game state.

`scripts/ci/smoke/movement-transitions-probe.mjs` records before/after browser clips, screenshots and assertions using real keyboard events. See the Codex job report for test/deployment results; no live completion is implied by this document alone.
