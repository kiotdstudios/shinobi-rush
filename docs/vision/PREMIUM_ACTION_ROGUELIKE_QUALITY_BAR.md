# Shinobi Rush — Premium Action-Roguelike-Inspired Quality Bar

## Creative identity
Shinobi Rush is a **premium, AAA-quality-aspiring 2D three-quarter faux-isometric shinobi action RPG with roguelike-inspired combat intensity and replayability**. The term **roguelike-inspired describes quality, combat feel, encounter variety, build experimentation and replay appeal**; it is NOT authorization to change the game's progression or world structure.

## Reference quality (inspiration, not cloning)
- **Hades / Hades II:** readability under dense effects, snappy directional combat, satisfying hit feedback, expressive animation, build variety.
- **Returnal:** responsive evasive movement, audiovisual impact, pressure and enemy-pattern readability.
- **Black Myth: Wukong:** dodge feel, animation craftsmanship, weight, precision, and high-impact counter windows. It is an action RPG reference, **not a roguelike**.
- Use original assets, systems, designs and animations; never copy copyrighted sprites, animation sequences, UI, sound or characters.

## Non-negotiable polish targets
1. **Controls:** immediate response, consistent dodge/sprint/attack transitions, buffered inputs only where designed, no artificial lag introduced for animation.
2. **Animation:** strong key poses, timing and spacing, detailed secondary motion, smooth transition states, readable attacks; more frames are not automatically better. Follow Codex's 128×128 production target and eight-direction spec.
3. **Combat feel:** distinctive light/heavy attacks, impactful hit stop/feedback (tune by playtest), crisp perfect dodge, precise hitboxes and recovery.
4. **VFX and audio:** premium but readable layered particles, afterimages, attack arcs, dust, sparks, directional impact, clear audiovisual telegraphs. Keep effects separate from character/equipment layers and profile Web performance.
5. **Enemies and encounters:** clear behavior tells, purposeful enemy mixes, satisfying difficulty ramp, memorable elite/boss attacks and learnable patterns.
6. **Build expression:** meaningful ability/jutsu and skill-tree combinations; cross-branch synergies where already approved.
7. **QA:** actual browser playtest and frame-time/performance review, reproducible feedback, comparison against reference *qualities* rather than copying.

## Preserve existing locked gameplay decisions
The authoritative world/gameplay rules are in `world/maps/MVP_WORLD_MAP.md`. **Do not introduce permadeath, procedural room resets, run-based inventory wipes, randomized maps, loss of persistent progression, or replacement of save stones/autosaves** simply because this document says roguelike-inspired. Such structural changes require explicit owner approval. The game's existing seamless areas, RPG levels, skills, crafting and save/death rules remain in force.

## Department interpretation
- **Codex:** high-detail character/equippable art, 8-direction animation, premium VFX, consistent camera/scale, efficient Web assets.
- **Aki / Orcha:** apply these feel/readability/polish standards to their assigned gameplay, AI, combat, and integration tasks, without taking ownership of Codex art.
- **Kiro:** protect performance, browser export reliability, CI, deployment, and measurable tests; do not treat this document as a request to rewrite gameplay systems.

This is a **quality and inspiration brief**, not a genre-system redesign.


## OWNER DECISION — Genre interpretation LOCKED (2026-10-17)
**Shinobi Rush is an existing-world action RPG, NOT a run-based roguelike.** The user explicitly chose **primarily the premium combat feel of Hades II, Returnal, and Black Myth: Wukong within the existing RPG world**. Preserve seamless regions, persistent levels/skills, crafting, inventory, save stones, and established death rules. Roguelike references are **feel and quality benchmarks only**: responsive dodges, precise attacks, animation polish, hit feedback, readable VFX, intelligent enemies, and build expression. **Do not add randomized runs, run resets, procedural level generation, permadeath, or roguelike progression loops** unless a new explicit order approves them. This owner decision supersedes any ambiguous “roguelike-inspired” language in earlier docs.
