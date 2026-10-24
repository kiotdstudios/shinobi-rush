# Blightwood river and small waterfall

Water-only art matching the owner's elevated three-quarter reference. No stones, cliffs, vegetation, lilies, flowers or scenery are baked into the assets.

[Half-speed preview](half-speed.gif) | [Normal preview](normal.gif) | [River tiles](nine-tiles.png) | [Cascade frames](waterfall-contact.png) | [Foam frames](foam-contact.png)

World Builder: **River water** provides nine 72x36 diamond tiles and a separately placeable small waterfall. River tiles use the existing floor brush and replace the floor tile in that cell. Move/delete/save/reload work through the existing builder tools. These are decorative visuals; swimming, water collision and banks are future integration work. No map layout is changed automatically.

The surface has 16 unique frames at 16 FPS plus an integer-pixel current drift. All neighboring tiles sample one shared world-space flow field, avoiding a restart at each diamond. Shore masks taper water alpha at the nine outer-edge/corner roles. The cascade has 16 unique frames at18 FPS, separate landing foam16frames at13 FPS and 18bounded moving droplets. Source pixels are PixelLab-generated; native cleanup removes an unintended one-pixel frame, repairs toroidal texture edges and separates the original landing apron. No blurred interpolation or native-image upscaling.

Interactive review: canonical game query `?water=review` after integration. Normal/Half speed, Pause, Step, and Spray/foam controls. GIFs are actual Godot Web captures, with a visible clock. They are previews; only a verified canonical deployment is live.

Production metadata: `assets/environment/blightwood_water/water.art.json`. Source jobs and unprocessed PNGs are preserved under its ignored source directory. Report: `orders/Codex/reports/2026-10-24-blightwood-water-report.md`.

Live runtime verified 2026-10-24 at 0921f13: [interactive normal/half-speed review](https://kiotdstudios.github.io/shinobi-rush/?water=review). Builder: River water. Main deployment/postdeploy PASS; 22 targeted live checks PASS. See dated live validation JSON and report for exact URLs/time/build identity.
