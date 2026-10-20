# Summoning jutsu — independent art clips

One SE review: fast hand signs, forceful ONE-palm ground slam, oversized black ink contract spreading from contact, then delayed smoke. All original character art remains128×128 at approved scale; crouch compresses the pose rather than resizing the character. Fixed foot/root[64,116]. One measured16px padding correction applies equally to all four generated body poses; no per-pose recentering or scaling. Original idle is reused for recovery end.

Three separate transparent clips in `summoning.json` (opt-in art data, not a runtime manifest):
- `body/`:4 distinct key poses plus original idle; timed frame references include intentional contact holds. No ink or smoke baked into the character.
- `contract/`:6 unique256×256 ground frames, black ink only, pivot[128,128]. More than225px wide, flattened into the ground plane. Hold last frame after reveal; no baked terrain, glow or shadow.
- `smoke/`:12 unique256×256 frames at70ms, pivot[128,208]. Cartoon white smoke grows, billows and separates, ending with an intentional fully clear frame. No character, contract, creature or object baked in.

Actor-local palm/ground contact is[60,109], relative to foot/root[-4,-7]. Place both contract and smoke at that ground point; subtract each clip's own pivot. The contract goes below the actor; smoke above actor/future summon. For a future summon, use the SAME ground point. Suggested spawn hidden by smoke1.45s; conservative reveal after clip ends1.94s. No summon is included.

Review timing: palm/contact and seal start450ms; fully revealed seal700ms; smoke1100ms (650ms after contact). Ground contract remains readable before smoke; actual gameplay timing is not implemented.2.6s preview reset is for inspection only, not a runtime disappearance rule. Controller/state machine/camera/production manifest untouched.

Sources: PixelLab Pro job96f8994c-9f0e-496a-9526-14cd01b8c5c9 for four body poses from approved idleSE0; exact workbench contract a540dd0b-ee67-43ff-a0b3-8e861a1b4c7c; smoke5aec74a2-a0ee-4e2f-a4a9-18d16b3c4b4d. Python only extracts, translates, composites and exports/QCs. Native binary alpha, nearest preview scaling. Source recipes retained under source/.gdignore.

Normal/half-speed full sequence, independent clip GIFs, labeled contact sheet and layer-toggle browser review are in `../../previews/summoning/`.
