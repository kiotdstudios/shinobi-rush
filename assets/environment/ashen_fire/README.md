# Ashen Ruins fire fixtures

Five original PixelLab fixtures: tall pillar, short brazier, tripod brazier, wall brazier and ground fire pit. Body PNGs are transparent, nearest-filtered and mapped to the15-color palette sampled from existing Kosen/Ashen stone floor tiles. Sources and job provenance are under source/ (excluded from Godot import).

ashen-fire.art.json records native dimensions, foot anchors, bowl anchors, footprints,12unique flame frames at12FPS, separate coals and smoke and audio resources. Flame atlas registration preserves native pixel size. The duplicate pinned endpoint from PixelLab animation is excluded.

AshenFireProp combines independent body/flame/coals/smoke/embers/light/audio layers. Each instance has fixed pools of24sparks and18smoke puffs. Curling smoke and sparks evolve independently from the1-second flame cycle. Random crackle events trigger a brief bright flash, coal illumination, spark burst and matching positional sound. Audio is original deterministic noise synthesis, not PixelLab audio. No character/combat/camera code changed.

Builder category: Ashen fire. Place, select/move, delete, hide/reveal and save/reload use existing builder controls. Objects do not inflict damage. No automatic placement/repaint of the owner's map. Review scene: scenes/art/ashen_fire_review.tscn; normal/half speed, pause, step, sound and effect toggles. GIF previews are silent; audio plays in-game after browser audio unlock.

Web builder edits also mirror synchronously to the origin-local key shinobi-rush:world-layout:v1, protecting refreshes from delayed IDBFS writeback. Existing FileAccess saves remain supported; no mirror means normal legacy loading, invalid/denied storage falls back to the file, and empty layouts clear both.
