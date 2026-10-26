# Premium knockback and substitution vortex

Audit: player and bandit already have approved128×128 hit_react,12-frame knockback and death assets in all8 headings, bound to real damage timers. The shared substitution effect already wobbles, drops, bounces and removes its log collider at1.88s, ending at2.95s. This delivery preserves those body assets, gameplay timers, collider removal, teleport and L2 tap/hold input rules. It adds authored VFX and a richer wrap rather than rebuilding approved bodies or changing combat feel.

Original source art is built-in image_gen: one12-frame contact/fragment burst and one16-frame smoke vortex. PixelLab documentation and connected credentials were reviewed earlier in this scheduled session; no PixelLab job was submitted. Sources are preserved under `assets/vfx/premium_damage/source/.gdignore`. `scripts/art/build_impact_vortex.py` is deterministic cleanup/extraction only; it checks unique frames, transparent margins and exact pixel reconstruction of the front/back split.

| Layer | Dimensions / anchor | Timing |
|---|---|---|
| Impact | 4×3 sheet,128px cells,64/64 center |20,20,30,30,35,35,40,40,45,45,50,50ms; first2 are high-contrast contact frames; local burst only |
| Vortex | 4×4 sheet,128px cells,64/104 ground origin | Overlapping16-frame passes at0,.42,.84,1.26,1.88s; first4 last.72s, last1.07s |
| Back/front smoke | Complementary y<70 / y>=70 masks | Back sprites inserted before existing log; fronts after log; union is pixel-identical to full master |
| Recoil snapshots | Existing real128px damage pose | Fixed12-slot pool, real reached positions at12px intervals,0.14s fade; never hide/stretch the real body |
| Skid dust | Existing approved DustPuff art | Reached motion only; suppressed for player on water |

`KnockbackPresentation` is a presentation node under the arena. It observes accepted player hits and bandit health decreases, existing hurt kinds and actual displacement. Invulnerable/rejected damage has no new impact. It writes no health, velocity, position, combat timers, input or camera state. Existing HitFx contact/audio remain functional; the new local burst reinforces confirmed target reaction for melee and projectiles. Only VFX rotates toward actual damage velocity; approved directional body clips remain intact.

The new front/back vortex replaces old flat outgoing departure/ribbon overlays and the procedural smoke circles. Original assets remain in the repo. Arrival smoke at the teleport destination is retained. Each vortex pass captures a reached log origin and remains stationary; later curls gather around its landed position. The existing log wobble/topple/bounce code and physical lifetime are unchanged. At ground contact1.02s a local authored impact plays once. At1.88s the log and collider disappear, leaving the final smoke to dissipate through2.95s.

Review: `?impact=review` uses real player/bandit damage entry points and physics, with AI frozen outside their hurt state. Review fixture reset/healing is isolated from gameplay. Choose headings or All8, Normal/Half, Replay. Log example is an isolated shared SubstitutionFx presentation; normal gameplay continues to spawn it from the existing actual substitution trigger. No global gameplay probability/timing or main camera settings are modified.
