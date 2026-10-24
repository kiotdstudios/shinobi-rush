# Blightwood Forest lighting decor

[Half-speed preview](half-speed.gif) | [Normal preview](normal.gif) | [Fixture contact sheet](fixture-contact.png) | [Wingbeat contact sheet](firefly-contact.png) | [Spirit-flame contact sheet](flame-contact.png)

Five PixelLab fixtures match the owner's concept: wooden lantern post, stone pagoda, flowering branch lantern, stone brazier and spirit totem. The shared forest/blue palette includes colors sampled from the live grass tile. Native ground anchors and transparent margins preserve the world scale.

In World Builder, choose **Blightwood lights**. Five fixture cards have their own lighting, emissive glass, hanging-lantern sway, spirit flames where applicable and independent fireflies. The sixth card, **Forest Fireflies**, places a separate movable/deletable 32-insect emitter. The swarm has no collider and does not block navigation. Every fixture has 12 insects, with fixed pools and independent flight/glow phases.

The spirit flame has 12 unique frames at 12 FPS; insect wings have 8 unique frames at 18 FPS. Hanging pendants are separate native pixel layers and use gentle runtime rotation. The structure stays rooted. These are independent effect clocks, not a single baked animated background.

Review scene controls: Normal, Half speed, Pause, Step, Fireflies, Lighting, Sway and Sound. Normal and half-speed GIFs contain 192 actual Godot Web captures, lasting 8 and 16 seconds respectively. GIFs are silent; the two spirit-flame props reuse quiet original fire ambience in-game.

Metadata and provenance: assets/environment/blightwood_lights/blightwood-lights.art.json and source/pixellab-jobs.json. Report: orders/Codex/reports/2026-10-24-blightwood-lights-report.md.
