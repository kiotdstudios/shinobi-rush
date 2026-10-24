# Substitution art handoff — Aki

Trigger this pack from a CONFIRMED timed L2 evade success against an incoming attack. Do not turn every L2 press into substitution. The art pack does not set the timing window, invulnerability, cooldown, input buffering or balance; retain existing combat configuration until reviewed.

Independent opt-in clips in substitution.json:
- log:9 native128×128 poses, reveal/tumble/contact/bounce/settle; pivot[64,116], durations in metadata, hold last. Ground-contact frame4, settle8. No shadow or smoke baked in.
- departure:15 native256×256 rolling smoke samples, faster burst-to-breakup timing, pivot[128,160], ends clear. Exact current summoning smoke pixels/palette, no resampling.
- ribbons:12 native256×256 curling white/gray wisps, same pivot, ends clear. Optional independently timed overlay.
- arrival:8 native256×256 dissipating summoning wisps, same pivot, ends clear. Optional arrival accent above the reappearing body.

Proposal from confirmed success: conceal outgoing body0ms, log40ms, move/reveal player and start arrival wisps80ms. Log ground contact230ms relative to success. These are visual proposals, not authoritative gameplay timing. The review includes200ms lead-in; remove that fixture offset when reading the relative events. Clip playback must follow hitstop/pause policy consistently and not fire events repeatedly on held frames.

Spawn log/departure/ribbons at the outgoing actor's captured FOOT origin. Placement=image top-left=`world_foot_origin - clip.pivot`. Place arrival at the new valid actor FOOT origin. All roots keep the same pixel scale as the128px player. Sort the log at its foot origin, smoke in front while concealing. Keep the log alive after its animation finishes until the gameplay cleanup rule removes it; preview-loop reset does not define that rule.

Gameplay-owned rear position: derive from the actual attacker's current orientation (attacker origin minus normalized facing times a tuned behind distance), then validate player collider, walls, arena/nav bounds and occupancy. Choose a documented fallback if the rear point is blocked; do not blindly teleport through geometry or use the diagram's hardcoded coordinates. Handle stale/dead attacker, simultaneous hits, one proc per attack/evade, i-frames and camera/telemetry using existing contracts. Avoid visible duplicate outgoing/new player.

Preview only uses approved idle E/W as fixtures and a red attacker marker facing left. New root lies to its right, behind the marker. No new enemy art, attack animation, hit detection, state machine or camera changes are supplied. See queued Aki order and Codex report. Other directions reuse neutral screen-space VFX/prop; no incompatible player direction labels invented.

Sources: PixelLab exact log862692ef-c651-4084-93d7-249ba3db220a, ribbons572bc6d9-04bc-4503-806e-e24980a30278; summoning rolling-smoke exportbeff6c99-c909-42d2-a46e-7c709c432c88 from commitd216459. Native source/recipes and source indices are retained. Reuse is intentional for consistency; Python only extracts/reorders/composites/exports/QCs, no synthesized pixels or interpolation.
