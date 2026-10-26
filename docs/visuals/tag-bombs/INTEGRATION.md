# Tag bomb item integration

Two new items preserve all existing gourds and flat paper tags:
- `tag_bomb`: ivory sphere with black decorative calligraphy and scarlet seams. Existing paper-tag ballistic, wall/enemy landing, 1.66-second fuse, 45 damage and explosion effect.
- `smoke_tag_bomb`: black sphere with white decorative calligraphy and red seams. Same ballistic flight/fuse, separate rolling smoke, no explosion damage, hitstop or scorch. Smoke visually screens the scene; **AI stealth/line-of-sight reactions are not implemented**.

Both are available under builder **Pickups**, editable/movable/deletable through the existing placement system. Walk close to collect (stack cap 9, pickup respawns after 30 seconds), then open Inventory and assign either item to a D-pad slot. Defaults and starting quantities of old items are preserved; new bombs start at zero and are obtained from placed pickups.

Art: native 128×128 RGBA centered at (64,64), displayed at 0.5× body scale in the world. Each bomb has 16 idle, 16 flight and 16 armed frames. Pickup aura/embers reuse separate established paper-tag effects. Smoke has 8 burst and 8 billow frames, a separate 256px effect with independent layered motion; never baked into the shell. Decorative ink resembles calligraphy and is not a verified readable translation.

Review: `?bombs=review`, normal / half speed and pause, collection and real item throw buttons. Review invokes actual inventory consumption, controller throw dispatch, pickups and projectile classes. No AI or camera-system edits.

PixelLab job receipts: `generation.json` and `jobs.json`. Source images retained under each item's ignored source folder; `export_pack.py` downloads and checks native dimensions. Explosion and pickup VFX reuse the existing approved art; those reused effects are not claimed as new generations.

Black-shell palette correction neutralizes cool-gray hues in body and white markings while preserving scarlet seams; original PixelLab images retained. All 112 exported frames are unique and hard-alpha RGBA.

## Review media
`normal.gif` and `half-speed.gif` are captured from the actual Godot Web preview (not a fabricated composite). Playback preserves measured capture intervals. `capture-preview.mjs` / `make_previews.py` reproduce them. Inventory and integrated-build screenshots are included beside the browser check receipts.
