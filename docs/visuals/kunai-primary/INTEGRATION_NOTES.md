# Aki handoff — kunai-first southeast proof

This is the first owner-review delivery of the P0 order, not eight-direction production or gameplay equipment integration. Proof URL after deployment: `?kunai=proof`. The isolated Godot scene uses original game floor art and close framing, with a half-speed default, source timer, pause/step, scrub, action selector and 2x inspection. Default gameplay does not take this path. No controller, hitbox, buffered-combat or combat-camera source is edited.

## Inventory / prior work audit
- PR48: reusable original black kunai,6 weaponless SE opening-thrust bodies, native right-hand sockets and reference frame study. Reused directly without repainting. Old input ambiguity does not block this **melee** order: new P0 makes kunai the default art direction; throw input mapping stays Aki/owner scope.
- PR33: modular bodies plus two swords; retained layered-coordinate contract. Katana-origin choreography and support-hand poses are unsuitable for this compact one-handed combo; no katana bodies/textures copied into the new attacks.
- PR42: timing/profile and layered rendering reference, but dash was hybrid existing dodge/sword art. New proof supplies original dedicated low dash bodies and kunai-specific light2/light3.
- Existing production SE dodge12 frames and run20 frames reused unchanged; new per-frame right-hand track, angle and occlusion rectangles added in proof metadata only. Other directions are untouched.

## Coordinates / layers
Manifest `assets/characters/player/kunai_primary_se/kunai-primary.art.json` is intentionally `.art.json`, not auto-discovered `.manifest.json`. All body references128x128 RGBA. Standing body104px; bent/low attacks naturally have a shorter visible extent. Foot/root[64,116], hand coordinates are native image top-left pixels. Attach at `right_hand_px - [64,116]`; kunai texture64x64, grip[25,31],36px total weapon length, blade axis+X, scale1. Positive angles clockwise in Godot's y-down coordinates.

Weapon behind=-1, body=0, weapon front=1, same-body5x5 hand occlusion patch=2, independent swipe=3. Light3 frame1 switches weapon behind during the loaded turn, frame2 restores front at contact. Weapon is the SAME texture/node throughout guard,combo,dodge,dash,run; no library conversion or per-frame weapon scaling. Native nearest filtering, no mipmaps, binary exported alpha, no floor shadows or baked trails.

## Timing contract — matches current AttackDef
| Action | Frames | Standalone ms | Contact index / ms | Recommended active indices | Recovery / transition |
|---|---:|---:|---|---|---|
| light1 |6 reused|300|2 /83.333|2–3|4–5|
| light2 |6 new|350|2 /100|2–3|4–5|
| light3 |6 new|483.333|2 /150|2–3|4–5|
| dash_attack |5 new|400|2 /100|2|3–4|

Variable frame durations are explicit, with24FPS authored-pose baseline rather than forcing fixed frame counts onto gameplay ticks. Existing approved run/dodge play at12FPS. The demonstration's nominal perfectly-buffered chain exits light1 at150ms (combo window150–266.667), light2 at200ms (166.667–300), plays light3 through recovery, and branches dodge at920ms (within final80ms of its1000ms source clip). Partial last-frame durations are trimmed. Total sequence4220ms normal /8440ms half; no idle action between attacks. Source contact windows remain authoritative. Existing dodge-cancel recommendations stay Aki's `dodge_cancel_from` fields:3,4,6,4 reference ticks into recovery, not newly chosen art balance.

Preview events are **not** actual hit events; no enemy/damage/hitstop simulation or gameplay root motion is claimed. Use facingSE=(1,1).normalized for gameplay hit direction; body fist angles are sprite-local weapon rotation, not a replacement hitbox vector. Fire contact once on entry/crossing; account for skipped render frames and cancellation. VFX is independent six-frame short steel swipe,30FPS suggested; renderer currently samples appropriate contact/decay poses. Aki may time it independently.

## Generation / QC
17 new bodies from built-in image_gen: light2(6),light3(6),dash(5). Shared fixed512-to128 nearest extraction and approved player palette; manually registered planted-sole translation preserves root. No per-frame fitting, morphing or blurred interpolation. First light3 candidate was rejected for scale drift; corrected generation uses same source scale. Dash source frame3 was rejected for clipped fingers; source4's disconnected neighboring-cell fragment removed. Kept source indices0,1,2,4,5 yield five purposeful dash poses with matching400ms timing. Source PNGs plus receipts in player/source/kunai-primary-se (excluded from game imports). Blade swipe exported separately from original generated six-cell sheet; glow removed by alpha180 and palette cleanup, one fixed cell scale. All body sockets opaque, all frames unique within action, all body PNGs transparent native128.

## Gate / remaining production
Owner review of this concrete SE proof is required before other directions. Full defensive,parry,hurt,aerial production and ordinary gameplay default-kunai equipment integration remain future work with Aki. The newly queued P1 jump-recut/air-attack order depends on the approved kunai style and follows this P0 proof; existing Chidori work is not discarded. Kiro camera work and Orcha Lightning Clone remain their owners' scope. Do not merge old sword-first order PR40 as a competing P0.
