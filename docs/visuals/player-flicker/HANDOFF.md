# Southeast kunai / Body Flicker proof

Order: `orders/Codex/2026-10-21-player-kunai-flicker-combat-rework.md`.

Open `?kunai=proof` (or `?flicker=proof`). Use the on-screen hit button twice, then choose Double back. Re-engage starts another strike. Single flicker works independently. Half speed and 2x zoom support art inspection. Keyboard: WASD, J, Space, Tab. The historical automatic sequence is available at `?kunai=legacy`.

## Ownership and scope

This is an interactive SE art harness in the existing training courtyard. It does not implement damage, targeting, enemy responses, invulnerability, final input mapping, or production combat states. The bandit is a stationary reference in this harness. Normal game startup remains unchanged. No player, AI, camera, or arena source files were edited.

Aki owns the real combo controller, movement and collision balance. There was no Aki implementation branch at the dependency audit. Double retreat has an explicit preview button; final binding is awaiting owner/Aki. It never automatically follows every combo. Additional facing directions await owner approval.

## Assets and integration API

- Four compact 128×128 RGBA SE body poses in `assets/characters/player/sprites/production/body_flicker/`; fixed foot anchor `[64,116]`, approved 104 px standing scale, no baked weapon or floor shadow. Knee compression deliberately changes visible height.
- Frame sockets, orientation, hash and timing: `assets/characters/player/animations/body_flicker_SE.art.json`. Nonuniform event timing, not an evenly sampled walk cycle.
- Separate existing black kunai: grip `[25,31]`; angles 140°,130°,135°,140°, foreground for all four flicker poses. `KunaiPoseActor` applies the hand occlusion patch.
- Existing two kunai strikes reused. First strike contact at 83.333 ms; second at 100 ms. A buffered second strike starts at first-strike 150 ms without a neutral gap. First contact uses reverse-grip angle 140°. Second-strike escape recommendation: 233.333 ms. These are visual proposals, not damage windows.
- One vanish beat: brace 0 ms, hide/request traverse 12 ms, reappear 84 ms, recovery complete 120 ms. Optional second beat starts 160 ms; hide 172 ms, reappear 244 ms, complete 280 ms. Half speed doubles wall time.
- `PlayerFlickerVisual.begin(direction, beats)` emits `traverse_requested(direction,distance)`, `event_marker`, `finished`. It does not move a collider. `cancel()` restores visibility and clears effects. Large render deltas process both beats. The isolated harness uses swept `move_and_collide` with the collider always enabled; blocked endpoints are respected. Production collision policy remains Aki's responsibility.
- One reusable sharp afterimage node captures the exact body and independent weapon, fading over 100 ms. Completion/cancellation removes it. No accumulating ghost nodes.
- Orcha baseline assets are byte-identical to PR #61 head `43c316a9c2309f1cafa2918c6ecd8d0ff08a5a97`, imported only at `assets/vfx/body_flicker/`. His demo script and integration changes were not imported. The proof samples these textures over 120 ms with a neutral tint; source files and timing metadata remain unchanged. SE-authored streaks are not claimed to cover eight facing directions.
- Codex kunai contact textures moved from the older player proof folder into `assets/vfx/kunai_contact/`; old metadata/exporter references updated, no duplicate VFX library.

## QA and next handoff

Godot tests cover hit buffering, optional escape, both vanish/reappear beats, repeated recovery, cleanup on subsequent ticks, inspection and movement interruption, re-engagement buffering, collision and slow-frame catchup. Browser probe drives real keyboard/mouse input without mutating game state. The proof's inspection toggle is distinct from the normal game's Animation Lab; the normal Lab and camera/control regression probe are tested separately. Aki must retest Animation Lab transitions with the eventual production controller.

Owner review: compact stance, kunai grip, flicker speed and stagger at normal/half speed. Then Aki can consume the signal/timing contract; expand directions only after approval. Source art and deterministic nearest/palette/alpha exporter are preserved for revision. No paid PixelLab used.
