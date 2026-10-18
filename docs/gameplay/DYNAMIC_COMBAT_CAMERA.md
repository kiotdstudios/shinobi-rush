# Shinobi Rush — Dynamic Combat Camera (P0 Design / P1 Implementation)

## Vision
Premium, cinematic, **responsive 2D Camera2D movement** for attacks, jutsu, perfect dodges, finishers and bosses. Preserve the locked **three-quarter overhead faux-isometric** view, Y sorting and spatial readability. No true 3D camera rotation or perspective switch.

## Event-driven camera director
Implement one camera director coordinating prioritized events, blends, bounds, target framing and recovery. Baseline exploration camera follows the player smoothly; combat effects must never permanently offset camera or interfere with controls.

| Trigger | Treatment | Initial tunable prototype values, NOT locked |
|---|---|---|
| Light attack hit | Small forward lead + micro-shake | 2–4 px, 40–80 ms |
| Heavy attack impact | Brief zoom punch, directional impulse, hit stop coordination | 1.05–1.10× zoom, 100–200 ms |
| Perfect dodge | Slight tracking offset + brief emphasis | 80–180 ms; time scale only if gameplay owner approves |
| Jutsu | Bias framing to effect target and player; ease zoom | 1.05–1.15×, bounded |
| Standard finisher | Temporarily frame attacker + victim, short punch-in, distinct impact, smooth reset | 0.35–0.9 s total, adjustable |
| Boss finisher | Elevated intensity but readable, skip/reduced-motion support | Per-animation choreography |
| Taking damage | Controlled directional shake, no disorienting snap | Low amplitude, bounded |

## Requirements
- Build camera priority stack: boss finisher > finisher > special jutsu > heavy hit > light hit > exploration. Repeated triggers must not stack zoom/shake without bounds; interrupt and restore correctly.
- Zoom about relevant combat focal point, include both player and enemy during finishers; respect screen edges and world camera limits.
- Coordinate animation event markers, hit confirmation, sound, VFX and optional hit stop. Trigger strong effects on confirmed impact, not every button press.
- Support camera easing, anticipation, impact, recovery, optional lateral lead and focus shifts. Smooth blend back to baseline without snapping.
- Camera shake uses a bounded trauma/impulse model with intensity caps, falloff and per-effect cooldown; avoid continuous vibration.
- Camera movement must not shift input aim/attack targeting or break Y-sort, UI, collisions, map boundaries or interaction prompts.
- Respect game pause, cutscenes, death, scene transitions and camera resets.
- Accessibility settings: camera shake 0–100%, zoom effects 0–100%, **reduced motion** preset; do not force slow motion for accessibility. Expose settings in test build.
- Performance: Godot 4 Web export and controller gameplay, 60 fps target where feasible; profile spikes and stutter, no excessive tween allocations.
- Instrument camera events in the debug telemetry system: trigger, source, target, intensity, zoom, priority, interruption, restore, error. Include camera state in bug reports.

## Test cases
1. Light combo and heavy hit with varied attack direction, ensuring focus/return.
2. Multiple simultaneous hits and jutsu: priority/interrupt/zoom caps.
3. Perfect dodge while sprinting; input stays responsive.
4. Finisher near map edge, against large boss, and with multiple enemies.
5. Mid-effect player death, scene change, pause and target disappearance.
6. Reduced motion and zero shake settings.
7. Keyboard and gamepad testing in actual browser build; capture frame-time and debug trace.
8. Verify camera never reveals off-map void or loses player.
