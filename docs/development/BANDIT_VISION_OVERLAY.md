# Bandit vision debug overlay: what the Bandit's AI can see

Owner: Kiro (debug overlay). Order: `orders/Kiro/2026-10-22-bandit-vision-debug-overlay.md`. Job report: `orders/Kiro/reports/2026-10-22-bandit-vision-debug-overlay-report.md`.
Code: `scripts/debug/bandit_vision_region.gd` (`BanditVisionRegion`, the polygon), `scripts/debug/bandit_vision_overlay.gd` (`BanditVisionOverlay`, the drawing), `scripts/debug/bandit_vision_toggle.gd` (`BanditVisionToggle`, key, button, URL option, telemetry). Tests: `tests/test_bandit_vision_overlay.gd` (122 checks).

**Debug only, default OFF.** While it is OFF there is no overlay node, no `_process`, no ray and no draw call. It never touches input, camera, collision, physics or AI behaviour, and it changes no AI number. `scripts/enemy/**` is untouched by this feature.

## Turning it on and off

| How | Detail |
| --- | --- |
| Button | "Bandit vision: off" / "Bandit vision: ON" in the **Settings** panel: click the "Settings" tab at the bottom-right of the screen, then the row. It works with the lab closed, with the mouse or a finger. There are no hotkeys (owner 2026-10-22). |
| URL | `?vision=1` starts the page with the overlay ON (like `?debug=1`; only an explicit `vision=1` turns it on, `?vision=0` or nothing means OFF). |


The HUD legend (bottom left) carries one line about it. Switching ON creates the overlay as a child of the Bandit's parent (the arena); switching OFF frees it on the spot, so not even one frame of ghost geometry can remain. A page reload with `?vision=1` starts it again; the wish "ON" also survives a scene reload inside one page session (an arena restart keeps it on and attaches a fresh overlay to the new Bandit).

## What is drawn (legend)

Per live Bandit, in world space (so it shares the AI's coordinates and the camera automatically; nothing is re-projected):

- **Sight region**: translucent fill plus an outline with a black halo. The shape is the set of ground positions (a player's feet) in which `Bandit.can_see` would accept the player right now, so it is a cone (110 degrees, 700 px, plus a 150 px close-sense circle) while the Bandit is not chasing and a full circle (945 px) while it is chasing, in both cases cut by every wall, rock and other blocker.
- **Sample rays**: faint lines from the Bandit to each polygon vertex, so the clipping can be read as rays, not only as a shape.
- **Facing**: an arrow of 120 px from the Bandit's origin in the direction of `facing8` (the AI snaps its facing to 8 directions, so the cone turns in 45 degree steps) and a dot on the origin.
- **Label** below the Bandit: line 1 `L<level> <real State name>: <category text>` (plus ` N%` in NOTICE: the notice progress); line 2 `CONE 110 deg  range 700 px  close 150 px`, or `NO CONE (chasing)  range 945 px`, or `NO CONE (AI sight paused, next look is chasing)  range 945 px`; line 3 `AI sees player: YES/no` (the AI's own `sees_player`). An orange line `RAY BUDGET REACHED: some edges are approximate` and a red line `OVERLAY OUT OF SYNC WITH AI (see log)` appear only when they are true.
- **Last-seen cross** with the text "last seen", only while the AI is using that position (SEARCH, a chasing state without sight, NOTICE without sight).
- **Player marker**: a ring with "SEEN" on the player and a line from the Bandit to him, **only while the AI's `sees_player` is true**. No marker means the AI does not see him, whatever the shape looks like.

| Category (text) | Bandit States | Colour (Okabe-Ito) | Outline |
| --- | --- | --- | --- |
| not alert | PATROL, IDLE | bluish green `#009E73` | solid, thin |
| suspicious: acquiring | NOTICE | yellow `#F0E442` | long dashes |
| PLAYER DETECTED | APPROACH, THREATEN, ATTACK, REPOSITION, RETREAT, EVADE, HIT_REACT while `sees_player` | vermillion `#D55E00` | solid, thick |
| lost sight | the same states while `sees_player` is false | reddish purple `#CC79A7` | dash, dot |
| lost target: searching | SEARCH | reddish purple `#CC79A7` | dotted |
| returning to patrol | RETURN | blue `#0072B2` | long dash, short gap |
| (nothing) | DEAD | | not drawn |

Colour is never the only signal: the text, the outline style and the "SEEN" marker carry the same information. Widths and fonts are sized in screen pixels, so the overlay reads the same at the wide camera and at `?camera=close`.

**EVADE and HIT_REACT** (design choice, flagged for review): the AI does not evaluate sight in these two states (`_physics_process` returns before `_update_perception`: hitstop 151, DEAD 164, EVADE 166, HIT_REACT 178-190, perception at 192-193 in `scripts/enemy/bandit.gd`) and both always continue to APPROACH, a chasing state. The overlay draws the chasing region (what the next evaluation uses; a 0.2 s cone flicker would be noise) and says "AI sight paused". The `AI sees player` line there shows the last flag the AI computed.

## How it stays in sync with the AI

The region is not an approximation drawn next to the AI. It is built from the same numbers with the same collision query as `Bandit.can_see`:

| AI code (`scripts/enemy/bandit.gd`) | Overlay |
| --- | --- |
| `_update_perception()` 224-231: `chasing := state in [NOTICE, APPROACH, THREATEN, ATTACK, REPOSITION, RETREAT]` (228), `sees_player = can_see(player, not chasing)` (229) | `BanditVisionRegion.CHASING_STATES` (mirror) and `uses_cone()` |
| `can_see` 236-246: `reach = sight_range * (1.0 if use_cone else 1.35)` (239), `d > reach` rejects (240) | `profile.sight_range`, and `CHASE_REACH_MULT = 1.35` (**mirror of a literal**, the AI does not expose it) |
| 242-245: with the cone and `d > close_sense`, `abs(facing8.angle_to(to)) > fov_deg / 2` rejects | wedge of +-`fov_deg / 2` around `facing8` with exact seams, radius `close_sense` outside it |
| `line_clear_to` 250-259: ray from `global_position + EYE_OFFSET` (const, line 28) to `target + EYE_OFFSET`, own RID and the player's RID excluded, default mask, bodies only | the same `PhysicsRayQueryParameters2D` for every sample ray, same exclusions (the player is the first node of group `player`, like `_find_player`, line 778) |
| sight is decided once per physics tick, after `_find_player()` (192-193), not in hitstop, DEAD, EVADE or HIT_REACT | read live every frame; EVADE / HIT_REACT labelled "paused"; DEAD hidden |

The accepted set is star-shaped around the Bandit (anything between the Bandit and an accepted point is accepted too), so it is exactly "radius per direction = min(range limit, first collider)". The polygon samples that radius: a base fan every 3 degrees (6 degrees inside the short 150 px circle), exact samples on both cone edges, then bisection (at most 8 levels, 0.012 degrees = 0.14 px at 700 px) wherever a wall silhouette or corner sits, so the edge follows the true boundary to a fraction of a pixel. Flat faces are accepted without refinement. A rebuild casts 110 to 300 rays (never more than `MAX_TOTAL_RAYS` = 652: 512 for refinement plus the base fan).

What guards the equality:

1. **Oracle test** (in the real arena with the walls, rocks and bounds): 204 configurations (9 spots x 1 to 8 facings x PATROL / APPROACH / NOTICE / SEARCH / RETURN / EVADE) and **136,044 sampled player positions** (random in and out of range, the max-range edge at -3 / -0.5 / +0.5 / +3 px, the close-sense edge, the cone edges at +-0.2 / +-1 degree, behind the facing, and points on and 0.4 / 3 / 40 px around the shadow edges through every corner of every blocker). `overlay.region_contains(p) == bandit.can_see(p, use_cone)` for all but **1** sample, which lies 0.05 px from the AI's own decision boundary (the stated band is 1 px, checked with `can_see` itself); 0 disagreements outside the band.
2. **Source guards**: a unit test parses `bandit.gd` for the `1.35` literal, the chasing list and the `EYE_OFFSET` value and compares them with the mirrors.
3. **Runtime probe**: every rebuild asks the AI's own `can_see` about two points on the facing ray (4 px inside and 4 px outside the edge the polygon claims) and about the player. A disagreement beyond the band is counted (`vision_mismatch`), shown in red ("OVERLAY OUT OF SYNC WITH AI") and logged once per kind with the exact numbers: `[BanditVisionOverlay] OUT OF SYNC with Bandit.can_see (bandit.gd:236): ...`.

If Aki changes `can_see`, the chasing list, the 1.35 or the eye offset, the unit guards go red and a running overlay says "OUT OF SYNC". Nothing is hidden by art. Suggested change on the AI side (not applied): expose `CHASE_SIGHT_MULT` and the chasing list (a const or a profile field) so the overlay can read them instead of mirroring them.

## What it does NOT show

The overlay draws the geometry `can_see` accepts plus the AI's state. It does not capture what the state machine does with that answer:

- Timers and hysteresis: `notice_delay` 0.65 s (x1.6 after a lost player), the 0.5 s blind grace in NOTICE, `lose_sight_time` 2.2 s, `search_duration` 3.2 s, the 1500 px `chase_leash` (which ends a chase with RETURN even while the Bandit still sees the player), `_has_lost_player`.
- `sees_player` is sampled once per physics tick from the positions before that tick's move, and not at all in EVADE, HIT_REACT, DEAD and hitstop. The polygon is read at render time, so on a frame in which a state change flips the cone mode (for example APPROACH to RETURN) or the player crosses the boundary during the last tick, the AI flag can disagree with the drawing for that one frame (about 8 to 10 px of movement). The `AI sees player` line and the marker show the AI's flag, the shape shows the geometry; a longer disagreement is a bug.
- `last_seen` is only updated while the player is seen (initialised to the Bandit's home), so the cross is only meaningful in the states listed above.
- The attack hit check uses `line_clear_to`, not `can_see` (no cone, no range limit); it is not drawn.
- Polygon edges follow the blockers' **footprints on the ground plane**, which is what the physics rays hit. In the faux-isometric view a tall wall rises above its edge, so the shape appears to end "in front of" the drawn wall top. That is the truth of the collision, not an error.

## Owner test steps for the live game

Controls: WASD move, Shift sprint. The HUD at the top left shows `Pos: (x, y)`; the Bandit lives on the east side (x 1250 to 1650, y -200 to 60), behind two long walls with a 280 px gap between them (y -80 to 200).

1. Open the live game. Click "Settings" (bottom-right), then "Bandit vision: off" (or open the page with `?vision=1`). The row reads "ON". Walk east with Shift until the Bandit is on screen: a bluish-green region with an arrow on the Bandit, label "L1 PATROL: not alert".
2. Watch it follow: the wedge swings as the Bandit walks its loop and turns in 45 degree steps; it is a circle of 150 px around the Bandit plus a 110 degree wedge to 700 px.
3. Walls clip it: stand at about `Pos (780, -300)` (west of the north wall). When the wedge points your way the wall cuts it, even though you are inside the wedge's angle: "AI sees player: no", no marker.
4. Behind the facing: with the Bandit walking away from you (its arrow points away), you stay unseen until you are inside the 150 px circle around it.
5. Get seen: stand in the lane at about `Pos (780, 135)` until the Bandit faces west. At about 700 px the outline turns yellow and dashed ("suspicious: acquiring N%"), then vermillion ("PLAYER DETECTED") with a ring and "SEEN" on you; the shape becomes a full circle of 945 px, cut into slices by the walls ("NO CONE (chasing)").
6. Lose it: sprint west along the lane (Shift + A) as soon as the outline turns yellow, while it is still "suspicious". You are past 945 px when it commits to the chase, so the label says "lost sight" with a "last seen" cross; a few seconds later "lost target: searching" (dotted, the cone is back and the Bandit looks around in 45 degree steps), then "returning to patrol" (blue), then green again. If you wait until it is already chasing you, it runs you down to its leash (1500 px from its home) and goes straight to "returning" while it still sees you; that is the AI's rule, not an overlay error.
7. Toggle repeatedly (Settings > Bandit vision), open the lab (Tab) and Settings > Diagnostics with the overlay ON: it must appear and vanish at once, keep drawing under the panels, and leave nothing coloured behind when OFF. Hit `Esc` to pause: the picture freezes with the world.
8. Report anything where the picture and the Bandit disagree: its `AI sees player` line is the AI's own flag. Note the `Pos`, the Bandit's label line and a screenshot. A red "OVERLAY OUT OF SYNC WITH AI" line or the console warning `[BanditVisionOverlay] OUT OF SYNC` means the overlay itself detected the disagreement.

## Telemetry (`window.__SHINOBI_STATE__`, additive)

Published by `WebBridge` about 10 Hz next to the existing fields (existing names are unchanged). All keys are always present; numbers are 0 and strings empty while the overlay is OFF or no Bandit is drawn, except `vision_nodes`. The Bandit fields describe the first drawn Bandit and come from the same rebuild as the polygon.

| Field | Meaning |
| --- | --- |
| `vision_on` | the switch |
| `vision_bandits`, `vision_points`, `vision_rays`, `vision_ms` | Bandits drawn, polygon vertices, ray queries and wall time (ms) of the last rebuild |
| `vision_state` | overlay category: `not_alert`, `suspicious`, `detected`, `lost_sight`, `searching`, `returning` |
| `vision_ai_state`, `vision_sees` | the AI's own State name and `sees_player` |
| `vision_can_see`, `vision_player_in` | the AI's `can_see(player, vision_cone)` at that instant, and whether the drawn polygon contains the player |
| `vision_cone`, `vision_range`, `vision_close`, `vision_fov_deg` | mode in use and the numbers read from the profile |
| `vision_facing_x`, `vision_facing_y`, `vision_origin_x`, `vision_origin_y` | the Bandit's `facing8` and the polygon apex (equals `bandit_x/y` of the same publish: the overlay is not a frame behind) |
| `vision_mismatch`, `vision_capped` | runtime sync probe count; the refinement budget was exhausted |
| `vision_nodes` | node count of the scene tree (always live): ON adds exactly one node, OFF takes it away |

## Tests

- `tests/test_bandit_vision_overlay.gd` (one `await load(...)` line in `tests/run_tests.gd`), 122 checks: the oracle above, an AI-flag oracle (the AI's own `_update_perception` result in each of 12 States at 6 places equals "polygon contains the player"), the State mapping for every `Bandit.State`, hidden on DEAD, no ghost after a freed Bandit, an arena restart, a freed scene, 100 rapid ON/OFF toggles (node count and draw items stable), other panels opened and closed, OFF = zero nodes and zero rebuilds, input untouched (the player walks the same distance ON and OFF, no input callbacks, the key is not consumed), the toggle action reuses no physical key, a per-frame cost bound, a moving test on real frames (the polygon is on the Bandit's current position and facing at the last `_process` of every frame, camera following).
- Red proof (five temporary mutations of production code, each shown red and restored byte-identically): the polygon ignores walls (13 red), wrong half-angle (3 red, 1286 of 136,044 oracle samples disagree), a dead Bandit keeps its polygon (4 red), the mirrored chase multiplier 1.0 instead of 1.35 (9 red), OFF only hides instead of freeing (8 red). Re-run on the final code: 122 checks, 109 / 119 / 118 / 113 / 114 passed, no marker left.
- Browser: `scripts/ci/smoke/controls-probe.mjs` has 7 new checks (default OFF with all 21 fields, hotkeys do nothing, Settings button on/off, the overlay following the patrolling Bandit with the AI's numbers of the same publish, 12 button cycles, `?vision=1`, `?vision=1` then F2 leaves no node behind).
- Scenario with real keys on a local Web export (scratch scripts, not in the repo): see the job report. Summary: 746 published frames (655 with the overlay ON); the overlay, the AI's `sees_player` flag, the AI's `can_see` and an independent model of the rules agreed on every frame, including a detection from behind at 91.6 px (unseen at 171.9 px), the 700 px cone edge, the 945 px chase edge, the flee through lost sight, SEARCH, RETURN and back to PATROL, 41 toggles by key and button, the lab and diagnostics panels open, and a Bandit killed with real key presses (nothing left drawn or published).

## How to extend it

- **Another intelligence level**: nothing to do. The region reads `bandit.profile` (`sight_range`, `fov_deg`, `close_sense`) every rebuild and the label shows `L<level>`. A Level 2 row in `enemy_intelligence.gd` shows up by itself.
- **Another enemy class**: the overlay iterates the `enemy` group and casts to `Bandit`. For a class with its own `can_see(target, use_cone)` and a `profile`, generalise `_view_for` (the mapping of States to categories lives in `STATE_MAP`; a test fails if `Bandit.State` gets a state that is not listed). A class that decides sight differently needs its own region builder plus an oracle test; the oracle test here is the template.
- **A new `Bandit.State`**: add it to `BanditVisionOverlay.STATE_MAP` (and to `CHASING_STATES` if the AI treats it as chasing).
- **Two or more Bandits**: each gets its own view; labels can overlap. Another Bandit in the line of sight blocks rays like it blocks the AI.

## Limits

- Sampled rays: base spacing 3 degrees, so 16 px at 300 px and 47 px at 900 px. An obstacle narrower than the spacing could slip between two rays; the arena's blockers are at least 90 px wide, and another Bandit (50 px) is caught up to about 950 px. Bisection refines silhouettes, but if the budget of 512 refinement rays runs out the label turns orange ("RAY BUDGET REACHED") and `vision_capped` is published. Never seen in the arena (largest rebuild 291 rays in the browser).
- Cost when ON: a rebuild of 110 to 300 rays takes about 0.5 to 1.5 ms natively and 1.8 ms median / 3.9 ms at the 95th percentile in the software-rendered WebAssembly build (n=636, one 18 ms outlier). Nothing runs when OFF.
- Browser: F6 is reserved (above). Software-GL browsers run the game at 4 to 9 FPS, so fast effects cannot be sampled live; tests wait on published state.
- Not verified: real GPU rendering, a headed browser, the owner's own play session.

## Second detection channel: proximity sense (named limit)

Orcha's PR #76 added a second way for a Bandit to notice the player: while the Bandit is sprinting (`is_sprinting`, "naruto running"), it senses the player within `sense_radius()` (300 px at intelligence 5). It is distance only: no cone, no line of sight, walls do not block it. If it fires in PATROL, IDLE, SEARCH or RETURN the Bandit goes to NOTICE.

- **This overlay does not draw it.** The Bandit vision region is exactly the set of positions where `Bandit.can_see` accepts the player; the sense ring is a different rule.
- **It is reachable.** Since the 2026-10-22 owner change, patrolling Bandits sprint between waypoints (`bandit.gd`, patrol branch), so the sense fires in PATROL, not only in APPROACH and EVADE.
- **Where to see it:** the Sense vision switch in the Settings panel (`SenseVisionOverlay`) draws the ring. Turn on both to see the full truth of what can trigger a Bandit.
- `can_see` and the oracle tests are unchanged by this channel.

## Findings handed to Aki (none is an overlay defect)

1. `Bandit.can_see` holds the chase reach multiplier as the literal `1.35` (`bandit.gd:239`) and `_update_perception` holds the chasing list inline (`bandit.gd:228`). The overlay mirrors both and guards them (above); exposing them would remove the copy.
2. The chase leash (`bandit.gd:365-366`) sends a long chase to RETURN while the Bandit still sees the player (measured: 748 px behind a sprinting player at x -188). SEARCH after a flee only happens when sight is lost first (distance over 945 px or a wall) and the leash is not hit first.
3. EVADE and HIT_REACT skip the sight evaluation entirely (the flag goes stale for up to the duration of the state).
