# Substitution art pack

Separate log, departure smoke, arrival wisps and optional curling ribbons for a confirmed timed L2 evade. This is asset delivery and a choreography diagram; Aki owns actual hit detection, teleportation and collision-safe rear placement. No gameplay/controller/production-player changes are included.

| Clip | Native canvas / root | Frames | Duration |
| --- | --- | --- | --- |
| log |128×128 /[64,116] |9 |1050ms, hold last |
| departure |256×256 /[128,160] |15 |580ms, clear end |
| arrival |256×256 /[128,160] |8 |320ms, clear end |
| ribbons |256×256 /[128,160] |12 |480ms, clear end |

Exact current summoning billows are reused at native scale/palette, retimed for a quick conceal/reveal. New original pixel-art log has bark ridges, a branch stub and visible growth rings; it tumbles, contacts, bounces and settles. Effects contain no body/log/terrain/shadow pixels from other clips. Optional ribbon wisps add the spiraling motion in the owner's animated reference. Explicit holds in metadata do not require duplicate images.

`substitution.json` is opt-in asset data, not a production player manifest. Relative proposal events begin on CONFIRMED evade success, not a raw L2 press: hide0ms, log40ms, reappear/arrival80ms, log contact230ms. Timing remains subject to gameplay configuration. The1.4s preview includes200ms lead-in, uses approved E/W idle fixtures and a labeled red attacker marker. Its hardcoded placement/reset is not a gameplay algorithm.

Normal/half-speed choreography, separate clip GIFs, contact sheet and layer-toggle browser review: `../../characters/player/previews/substitution/`. See INTEGRATION_NOTES.md, queued Aki order and Codex report. Sources are retained under source/.gdignore.
