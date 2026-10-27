# Summoning jutsu — independent art clips

One SE review: fast hand signs, forceful ONE-palm ground slam, oversized black ink contract spreading from contact, then delayed smoke. All original character art remains128×128 at approved scale; crouch compresses the pose rather than resizing the character. Fixed foot/root[64,116]. One measured16px padding correction applies equally to all four generated body poses; no per-pose recentering or scaling. Original idle is reused for recovery end.

Three separate transparent clips in `summoning.json` (opt-in art data, not a runtime manifest):
The character data also supplies independent `hand_signs` and `ground_slam` subclips sharing the same PNGs. The standalone slam contacts the ground150ms after it starts; its GIF is ground-slam-only.gif. It does not require replaying the signs.

- `body/`:4 distinct key poses plus original idle; timed frame references include intentional contact holds. No ink or smoke baked into the character.
- `contract/`:6 unique256×256 ground frames, black ink only, pivot[128,128]. More than225px wide, flattened into the ground plane. Hold last frame after reveal; no baked terrain, glow or shadow.
- `smoke/`:29 unique256×256 frames at40ms (25FPS), pivot[128,160]. Shaded, rolling billows evolve into irregular curls, open holes and wispy fragments, ending with one fully clear frame. No character, contract, creature or object baked in. This replaces the original12-frame circular-puff study.

Actor-local palm/ground contact is[60,109], relative to foot/root[-4,-7]. Place both contract and smoke at that ground point; subtract each clip's own pivot. The contract goes below the actor; smoke above actor/future summon. For a future summon, use the SAME ground point. Suggested spawn hidden by smoke1.74s; conservative reveal after clip ends2.26s. No summon is included.

Review timing: palm/contact and seal start450ms; fully revealed seal700ms; smoke1100ms (650ms after contact). Ground contract remains readable before smoke; actual gameplay timing is not implemented.2.6s preview reset is for inspection only, not a runtime disappearance rule. Controller/state machine/camera/production manifest untouched.

Sources: PixelLab Pro job96f8994c-9f0e-496a-9526-14cd01b8c5c9 for four body poses from approved idleSE0; exact workbench contract a540dd0b-ee67-43ff-a0b3-8e861a1b4c7c. Current rolling smoke uses PixelLab VFX workbench effect ef3e6d7f-fc13-4787-bf6c-c9fb0526773f, export beff6c99-c909-42d2-a46e-7c709c432c88. Native190×201 source is padded by[34,23] onto256, with origin[94,137] mapping to pivot[128,160]; no rescaling. Removed only a redundant second blank export terminator. Old smoke recipe remains source reference. Python only extracts, translates, composites and exports/QCs. Native binary alpha, nearest preview scaling. Source recipes/game pack retained under source/.gdignore.

The preview clock now samples every10ms so it shows all native25FPS smoke frames while preserving the original body/contract timings. These repeated timeline references are not additional drawn smoke poses. The smoke lasts1160ms; the full review loop remains2600ms (half-speed5200ms).

Normal/half-speed full sequence, independent clip GIFs, labeled contact sheet and layer-toggle browser review are in `../../previews/summoning/`.
