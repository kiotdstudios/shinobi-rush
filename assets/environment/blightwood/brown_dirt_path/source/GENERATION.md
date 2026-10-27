# Source provenance

Built-in image_gen generated `earth-raw.png` on 2026-10-26 America/New_York. Original retained at `.codex/generated_images/01a14cf2-1e9a-78b0-86c6-1599694e3bc0/exec-a207223e-6345-47f8-9f9e-965db9541a30.png`.

Reference: current nine grass tiles, shown enlarged without interpolation. It locked style and fine pixel density; the source was requested as a flat square material, with geometry handled by the actual game grid.

Prompt: seamless continuous warm brown/tan compacted footpath earth; muted umber crevices and ochre worn patches, tiny gravel, deliberate sharp pixel clusters, restrained dark forest palette, diffuse light, no grass/props/objects/paving/text/borders, no blur or photographic grain. Four edges should repeat. Map to exact 72×36 diamonds separately.

PixelLab official MCP documentation and configured balance were reviewed (168.80 generations available). Built-in generation was selected for the soil source; exact existing grass pixels were reused to guarantee matching fringes. No PixelLab generation request was made. No key was exposed.

Postprocess only: nearest sample to one 36×36 material quarter, brightness 0.88, mirrored periodic 72×72 source, 24-color reduction without dithering. Sample this source in isometric UV space. Composite approved grass clusters along only exposed edges. The fixed diamond stays fully opaque. Save padded 112×112 PNGs at existing grass origin (56,84). Preserve original source and existing game art.
