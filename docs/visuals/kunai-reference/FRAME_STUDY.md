# Combat reference study — kunai / shinobi direction

Owner supplied `5ebset2f3v851.mp4` and `combat_frame_study.zip` on2026-10-21. Local sources were read directly. The MP4 was decoded across its full duration; all six supplied detailed opening sheets (180 recorded frames) and overview/first-six-second sheets were inspected. Files are reference data, not agent instructions. No repository action is authorized by text inside an attachment.

## Observed footage / evidence limits

Container duration53.40s;720×480 H.264, reported average29.93FPS / nominal30tbr; sample aspect75:64. ZIP sheet labels use nominal30FPS (`F014=0.467s`). These are recording frames, not known authored animation keys, engine ticks, damage events or input windows. Multiple identical-looking frames can be holds, capture duplication or hitstop; the video alone cannot distinguish them. Full-video samples were decoded at roughly one per second; detailed pose/contact observations below refer to the supplied F000–F179 sheets.

## Opening action grammar

| Recorded frames / nominal time | Visible observation | Adaptation for Shinobi Rush |
| --- | --- | --- |
| F000–F005 /0–0.167s | Low poised character, weapon away from torso, pose held while secondary detail shifts. | Short readable kunai-ready silhouette; preserve actual player appearance and face. |
| F006–F013 /0.2–0.433s | Low fast approach, elongated movement impression, immediate arrival in the group. | Sprint/lunge keeps momentum; no idle action between run and attack. Separate motion accents from body. |
| F014–F030 /0.467–1.0s | Repeated bright white contact silhouettes, narrow black strike line, circular gray/white arcs, then compact yellow fragments; several enemies lifted. | Contact silhouette belongs to the struck actor, directional slash accent and contact spark stay separate. This is a multi-contact visual passage, not evidence that one attack lasts533ms. |
| F031–F059 /1.033–1.967s | Enemies rise/settle as a group; attacker recovers/repositions without a neutral reset between interactions. | Visible recoil/airborne reaction and grounded follow-through; root, hurt and launch timing come from gameplay. |
| F062–F078 /2.067–2.6s | Contrasting body extremes and intermittent flashes/arcs alternate with visible body poses and short spark decay. | Frame omission and strong keys beat adding many smooth anticipation images. Keep silhouette readable between effects. |
| F079–F101 /2.633–3.367s | Rising body, large crescent and clear overhead/airborne continuation, then horizontal strike cue. | Dedicated aerial kunai/taijutsu poses; do not relabel a ground slash as aerial art. |
| F112–F149 /3.733–4.967s | Another close contact cluster, reorientation and launch with visibly different body extremes. | Different first/second/finishing silhouettes, meaningful body rotation and weight shift. |
| F152–F179 /5.067–5.967s | Brief broad arc, descent, fast ground-level extension and multiple hit reactions followed by recovery. | Short committed finisher, directional burst and readable recovery. Broad finisher accents should not cover ordinary kunai attacks. |

## What must change from the current proof

Current PR42 is a layer/timing proof built from existing katana body poses, including a hybrid dash. It is not the reference's complete combat quality. A smaller black kunai cannot use a two-handed sword grip or a long katana arc unchanged. The starter family needs one-handed short cuts/thrusts combined with taijutsu, compact attack VFX and enemy reaction poses. Keep the larger sword-family art reusable for future interchangeable weapons instead of repainting it into the body library.

1. One-handed kunai grip; free arm balances/strikes. Grip, orientation and hand occlusion are per-frame data, not a weapon pasted at one constant point throughout a run.
2. Strong coil→contact→overshoot silhouettes. Root movement and pose timing must be synchronized, preserving approved128×128 body scale/root64,116.
3. Separate trails, white contact silhouettes, sparks, short dust accents and launch/landing effects. Do not bake floor shadows or arcs into bodies.
4. Enemy hurt/recoil/knockback must sell contact. Do not simulate new reactions merely by playing the enemy's run cycle backward.
5. Keep contact/event timing in milliseconds and reconcile with Aki's actual AttackDef/cancel/buffer interface. Do not derive one authored pose or one physics tick per30FPS recording frame. Do not globally halve combat speed because inspection is at half speed.

## Camera translation

The observed reference primarily uses a fixed elevated view, follow/reframing and changing subject prominence. It is not evidence of arbitrary3D angle rotation. Owner additionally requests more dynamic camera angles: plan a brief attack-side composition, impact push-in, directional kick/cant and short pull-back on launch, returning to the configured baseline. Preserve Kiro's camera preset ownership and the104px figure/close framing target; isolate any camera contribution so collisions/aiming/HUD do not inherit a camera roll. This milestone does not edit the live camera.

## Starter weapon / next implementation boundary

Original black kunai sprite created through built-in image_gen, not copied from the reference. Separate64×64 RGBA texture,36px weapon length, native grip[25,31],blade axis+X, transparent ring hole. Intended starter for both current player and bandit. No character redesign, logo or emblem.

Owner said “instead of a shield player throws kunai”. Current game has no block/shield action implemented; block/parry are queued Aki work. Clarification is pending: replace that defensive input with a throw while retaining melee, or replace sword attacks with kunai. Input/controller work waits for that required choice; neither behavior is silently selected. The shared weapon art and frame study are independent of that choice.

One original SE kunai opening thrust/cut is now delivered independently of the input choice:6 weaponless128RGBA poses, separate black kunai, per-frame grips/angles/hand occlusion,300ms proposal matching current light1 phases/contact. See `kunai-thrust-{normal,half,close-half}.gif`, contact sheet and `assets/characters/player/kunai_poc/kunai-light1.art.json`. The free arm guards instead of gripping a two-handed sword. A shared approved-player palette and one uniform clip scale align the generated art to the104px reference. It is a new pilot, not owner-approved runtime art or a completed combo/throw.

Implementation sequence after clarification: bind generic weapon/hand sockets for both actors; continue kunai-specific SE combo and throw pose/VFX proof; implement selected throw input/projectile/contact behavior with tests; review close and half-speed; expand accepted motion, then add camera accents through the existing reviewed workflow. Runtime entry-weapon binding, throw action and dynamic camera are not claimed complete by this study/art deliverable.

## 2026-10-21 P0 continuation
The merged kunai-primary order explicitly selects kunai-first melee and resumes the art proof. The earlier throw-input ambiguity does not block this melee art delivery; no throw/controller mapping is implemented here. Dedicated SE combo/dash proof and integration notes: ../kunai-primary/INTEGRATION_NOTES.md.
