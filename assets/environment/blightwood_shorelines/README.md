# Blightwood shoreline assets

Three 16-piece connected terrain sets, native 72x36 RGBA: grass-to-water, dirt-to-water and rocky waterline. The land/ folder contains only land art. water_masks/ contains complementary alpha masks for the existing animated river renderer. tiles/ contains assembled static builder thumbnails; the runtime never uses their baked water pixels.

Metadata/placement rules: shorelines.art.json. PixelLab source/provenance is retained under source/ but excluded from Godot imports/exports. No native source-image scaling. Normal/half-speed previews and usage: docs/visuals/blightwood-shorelines/README.md.
