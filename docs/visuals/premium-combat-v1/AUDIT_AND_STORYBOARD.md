# Premium combat Phase1 — audit and SE storyboard

Checkpoint scope: existing-art inventory and choreography/timing proposal. This is not the completed playable-ready prototype, not gameplay approval, and not a new production sprite pack. No paid generation initiated.

## Source inventory

| Source | Reusable art | Boundary / gap |
| --- | --- | --- |
| Existing player_128 production manifest |847 unique128×128 RGBA unarmed locomotion PNGs; idle/walk/run/sprint/jump/dodge,8directions; root[64,116],body104px |Reuse; no regeneration. IdleSW deliberate holds produce855timeline references. |
| PR33 modular sword proof, commit2e5717d |24 weaponless SE combo body frames,8per hit; per-frame right-hand grip/orientation/layer/hand-occluder metadata |Existing one-direction proof, not eight-direction combat coverage or live runtime integration. |
| Same PR33 weapons |2 separate64×64 native-pixel swords, shared pivot[14,32],blade axis+X |Both use the same body library. Verify off-hand and hilt clearance in transitions. |
| Same PR33 combat VFX |8light trails,8heavy trails,4hit sparks |Independent layer/pivot; useful source. White impact silhouette, small flash, dust/afterimage not delivered as this pack yet. |
| Existing local legacy SE dash pilot |8 transparent128×128 candidate frames, clip status CANDIDATE_VISUAL_REVIEW_REQUIRED |Workspace-only untracked source under live-animation-integration; baked sword. Not approved, not shipped, no weaponless dash/socket track yet. Do not falsely list dash as wholly nonexistent or as production-ready. |
| PR38 red-scarf bandit |8directions idle/run/sprint; latest sprint-arms-v3 |Owner supplied design resolves concept dependency; reuse, don't redesign. Enemy strike/hurt/stagger/block/defeat remain separate missing clips. Phase4 waits on player proof approval. |

Machine inventory and current PNG/hash checks: asset-audit.json; audit_sources.py. All847 locomotion files,24 modular bodies,2weapon textures,20VFX and8legacy dash files loaded with expected dimensions/RGBA/binary alpha. Modular body/weapon/VFX hashes agree with metadata. This establishes file integrity, not visual approval.

## Gameplay interface audit

Read main21324af's scripts/combat/attack_def.gd and player_controller.gd. Runtime IDs are light1/light2/light3/dash_attack. Map descriptive art IDs light_attack_1/2/3 to those, not vice versa. Current source startup/active/recovery proposals at60Hz are5/4/9,6/4/11,9/5/15,6/5/13 respectively. Total300/350/483.333/400ms. These are initial gameplay values, not video-derived timings or Aki's final fluidity tuning.

Existing modular contacts are body pose4,1,2 respectively at uniform24FPS. Light1's contact at166.667ms would miss the current83.333ms startup boundary. The source study cannot simply be installed unchanged. Retiming must include body, weapon track, occlusion and effect triggers together. Preserve zero-based pose indices and explicit millisecond holds; don't equate physics ticks with authored images. Half-speed is an inspection mode, not an instruction to halve gameplay speed.

The requested attack_start/hit_active/hit_contact/cancel_open/recovery names were not found as an implemented event interface in audited main. They are a proposed vocabulary until Aki confirms exact API, dispatch/restart/time-skip/cancel semantics. Aki owns gameplay controller, movement, hitboxes and event integration. Current _begin_attack adds lunge to existing velocity; art must not bake a second root translation into the sprite. Existing controller can chain without idle; artwork must preserve that continuity instead of adding neutral separator poses.

## SE pose storyboard — proposed, pending rendered proof

| Beat | Pose / force / layer plan | Contact / transition intent |
| --- | --- | --- |
| Run approach |Existing SE run, root stable. Lead shoulder/katana preparation should continue current momentum. |No inserted idle. Move directly into attack1 startup. |
| Light1 startup |Reuse selected weaponless opening keys0/2 rather than force every old anticipation frame into a short window. Diagonal coil. |Draft2startup poses spanning current83.333ms; Aki must confirm. |
| Light1 impact/extreme |Reuse keys4/5, separate narrow light arc and contact spark. Strong cut silhouette. |Contact key4, suggested active interval follows actual gameplay. No damage implied by preview. |
| Light1 overshoot/exit |Keys6/7 retain sword/body follow-through. |Branch into light2 startup at legal combo event, not forced neutral. |
| Light2 startup/reverse |Reuse key0 then contrasting reverse key1; maintain flow from prior sword angle. |Contact pose1. Check mount/occluder jumps between light1 exit and light2 entry. |
| Light2 impact/exit |Reverse arc separate, smaller spark, keys2–7 only where they clarify reverse force and next windup. |Retiming to current100ms startup/66.667ms active/183.333ms recovery is a proposal. |
| Light3 coil/impact |Reuse heavy keys0/1→2/3. Distinct committed extreme, stronger heavy arc, limited flash at contact. |Current150/83.333/250ms phases are draft. Avoid lengthening anticipation for cosmetic smoothing. |
| Light3 follow-through |Lower recovery4–7 with sleeve/weapon overshoot. |Dodge only at legal recovery/cancel event. No invented universal cancel. |
| Dodge/reposition |Existing SE dodge, movement owned by gameplay. Keep attachments coherent through missing old locomotion sockets. |No idle bridge. Deliberate weapon grip convention for dodge must be supplied/verified. |
| Dash attack |Inspect legacy SE pilot for low forward-driving silhouette. Establish weaponless body, per-frame grip/orientation/layer and an independent directional trail. |Dedicated layered dash remains a gap. Provisional current100/83.333/216.667ms windows; no art-root displacement. |

Proposed light1 hold study using body indices0,2,4,5,6,7:41.667,41.667,33.333,33.333,75,75ms. This is a starting retiming experiment, not accepted combat configuration. Strong silhouettes/frame omission take priority over retaining every old pose. Don't apply the study to runtime before Aki coordination and visual proof.

## Reference and next deliverable

No MP4/MOV/WebM found in this thread's remote-attachment directory during audit. No reference video was viewed in this checkpoint. Use only the Chief order's documented early-sequence observations (rapid approach, white impacts, circular arcs, yellow sparks) until an actual recording is accessible. Do not infer source-game authored frame counts or exact original timing from53.4s/30fps recording metadata.

Next: assemble the SE run→three-hit combo→dodge→dash proof, using separate body/weapon/VFX layers and two compatible swords, exact frame holds and proposed event markers. Render contact sheet plus1×/actual-close/half-speed previews; inspect mount continuity and silhouette/contact readability before requesting owner look/feel approval. Eight-direction expansion waits for that approval. Existing Chidori, Orcha's Lightning Clone and Aki gameplay remain separate; no duplicate jutsu generation. Follow Chief's no-paid-generation-without-owner-authorization rule if reuse proves insufficient.

## Follow-up findings after proof delivery

Phase1 proof is now delivered in PR42. Aki PR43 merged as main63bbd6c16f449d77d3e14e5a4c1afedb80864380. Existing four ground AttackDef timings are unchanged; Aki added aerial attack and hitstop-safe buffering/diagnostics. No new confirmed art-event adapter was found. Aerial art remains a later gap, not a reason to change the current offensive proof's scope.

Added a runtime-chain comparison using legal combo/recovery/dodge branches. The approved runtime run/dodge rate is12FPS; dodge is12frames and1000ms, distinct from the first study's300ms proposed dodge. Actual comparison metadata and integration notes now distinguish both profiles. No controller changes or live-art binding.

A deeper legacy workspace search found normalized baked-weapon candidates: light1 in S/SE/E/N/NW/W/SW, light2 in S/NW, dash inSE (8frames each,128RGBA). They are all marked CANDIDATE_VISUAL_REVIEW_REQUIRED and remain workspace-only; no claim of accepted directional production coverage. PR33 separately supplies weaponless SE light1–3. See directional-source-inventory.json before commissioning new frames. Remaining raw/queued jobs are not normalized/approved modular coverage.
