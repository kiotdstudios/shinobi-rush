# Blightwood Ancient Flame Shrine

PixelLab reference recreation from the owner's supplied image. Native 512x448 art is padded (never resized) to544x480 RGBA with anchor272,448. The stone, stairs, arches and foliage palette stay faithful to the reference. See shrine.art.json for provenance and layer metadata.

Four extracted hanging-flower/vine bands bend by at most one native pixel with fixed attachment regions. The original PixelLab stone pixels stay fixed. Central orange inlays have a12second emissive breath, with a separate additive halo. Three independently seeded ForestFireflies groups (14each,42total) reuse the existing approved PixelLab firefly atlas. Soft procedural god rays drift independently. These are continuous runtime layer animations, not AI-generated full-structure frames. The preview samples at24FPS.

Builder: Dynamic shrine filter / Ancient Flame Shrine. Decorative, nonblocking landmark; move/delete/save/load use the existing builder. Existing shelter and default map stay unchanged. Placement dimensions protect nearby actors during editing; this is not a gameplay shrine interaction or traversal feature.

Review: canonical game URL with ?shrine=review. Normal, Half speed, Pause, Step, Glow, Vines, Fireflies, God rays. Default half speed. Source geometry/pulse/breeze periods are stable; independently moving insects do not share a short loop.

Source generation: PixelLab create_image_pro job9dc92012-7393-4431-9c7a-47c947d93bde; seed2412401;25generations. Reference was uploaded through PixelLab's no-auth upload endpoint. No API keys recorded. Original source and owner reference preserved under source/.gdignore, excluded from game export.
