# Blightwood shoreline kit

[Half-speed preview](half-speed.gif) | [Normal preview](normal.gif) | [Grass pieces](grass-contact.png) | [Dirt pieces](dirt-contact.png) | [Rock pieces](rock-contact.png)

48 native 72x36 diamond pieces:16 per family. Each set includes straight banks, outer corners, inner corners, two diagonal/split configurations, plus land and water fills. Corner bits refer to diamond tips: top8, right4, left2, bottom1. Matching adjacent corners makes compatible banks. The builder labels the shapes in plain language; metadata preserves the full placement rule.

Builder filters: **Grass banks**, **Dirt banks**, **Rocky banks**. Existing place/paint/select/move/delete/save/reload tools apply. A shoreline replaces the floor tile in its cell. Water is decorative in this pass; terrain collision/swimming and shared map placement are separate work.

Each tile has separate authored land and a complementary transparent water mask. It uses the already-live river atlas/current with shared world coordinates and clock, so water keeps flowing across shoreline and ordinary river cells. Sources are PixelLab terrain tiles, with palettes sampled from the existing grass, ground path, stone floor and river. Native layer extraction and two-pixel edge registration preserve scale. Only nearest authored land pixels fill repaired boundary pixels; no procedural substitute terrain art.

Interactive scene after integration: canonical game `?shore=review`. Normal/Half speed, Pause, Step, and All/Grass/Dirt/Rock focus buttons. The GIFs contain 192 actual Godot Web captures:8s normal and16s half speed. Focus screenshots show each material at2x native scale. A branch preview is not a live deployment; see the report for the verified canonical build identity.

Production metadata: assets/environment/blightwood_shorelines/shorelines.art.json. Source jobs, ZIP archives and original PNGs are retained under source/ with .gdignore. Asset QC verifies192 corner probes,384 compatible edge-pair configurations and exact complementary land/water alpha coverage. Report: orders/Codex/reports/2026-10-24-blightwood-shorelines-report.md.
