"""Fire pillar asset processing (owner 2026-10-22: "make this little fire pillar thingy... very
detailed fire animation as always max frames to get the quality matching the grass").

Two generated source images, both built-in image_gen (no paid PixelLab generation):
  1. isometric stone lantern pillar (static base, embers baked into the window/bowl)
  2. a 4x4 grid of 16 distinct hand-animated-style flame key poses (the real painted frames)

Both need custom per-image background separation (the model did not reliably respect a flat
chroma-key instruction on the first try for image 1, and insisted on drawing a small wood/log base
under every flame in image 2 despite repeated explicit "no logs" instructions) -- see the inline
comments on each classifier for the exact reasoning, calibrated against sampled pixel values.
"""
from pathlib import Path
from PIL import Image
import numpy as np
from collections import deque
import json, hashlib

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets/environment/fire_pillar/source"
OUT = ROOT / "assets/environment/fire_pillar"
(OUT / "tiles").mkdir(parents=True, exist_ok=True)


def border_flood(mask: np.ndarray) -> np.ndarray:
    """4-connected flood fill of `mask` (bool) seeded from every True border pixel. Pixels in
    `mask` that are NOT reachable from the border (isolated interior islands) are excluded -- this
    is what correctly keeps small same-colored patches *inside* the subject (stray green moss
    flecks, antialiasing fringes) from being punched out as holes, while still removing the one
    true background region that actually touches every edge of the canvas."""
    h, w = mask.shape
    visited = np.zeros((h, w), dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not visited[y, x]:
                visited[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not visited[y, x]:
                visited[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not visited[ny, nx]:
                visited[ny, nx] = True
                dq.append((ny, nx))
    return visited


def components(mask: np.ndarray, min_size: int = 1):
    """4-connected components of `mask`, largest first. Returns list of (size, list[(y,x)])."""
    h, w = mask.shape
    visited = np.zeros((h, w), dtype=bool)
    out = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not visited[y, x]:
                comp = [(y, x)]
                visited[y, x] = True
                dq = deque([(y, x)])
                while dq:
                    cy, cx = dq.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            dq.append((ny, nx))
                            comp.append((ny, nx))
                if len(comp) >= min_size:
                    out.append(comp)
    out.sort(key=len, reverse=True)
    return out


# =================================================================== 1. stone lantern pillar (static)
# Generated on a flat lime-green chroma-key background (confirmed by sampling all four corners:
# ~(55,225,70), consistent, no gradient). Candidate background = pixels where green is clearly the
# dominant channel over both red and blue -- this is a different, more reliable rule than a global
# flood fill on raw color distance, because the pillar's own cool blue-grey stone shading has large
# LOCAL jumps at every dark mortar/crack outline that a neighbor-tolerant flood fill leaks straight
# through (confirmed by an earlier failed attempt: it ate almost the entire pillar). Classifying by
# hue first, THEN border-flooding only within that candidate set, avoids the leak entirely.
pillar_raw = Image.open(SRC / "pillar-raw.png").convert("RGB")
parr = np.asarray(pillar_raw, dtype=np.int16)
pR, pG, pB = parr[:, :, 0], parr[:, :, 1], parr[:, :, 2]
green_candidate = (pG > pR + 15) & (pG > pB + 15)
true_bg = border_flood(green_candidate)
# A few small green moss/embers-window flecks are green-candidate but NOT connected to the border
# (isolated islands within the subject) -- border_flood correctly keeps them opaque, but they still
# read as an odd bright green blotch, so desaturate (not remove) just that leftover green tint.
green_island = green_candidate & ~true_bg
prgb = parr.copy()
prgb[:, :, 1] = np.where(green_island, np.minimum(pR, pB), prgb[:, :, 1])
pillar_cut = np.zeros((*true_bg.shape, 4), dtype=np.uint8)
pillar_cut[:, :, :3] = np.clip(prgb, 0, 255).astype(np.uint8)
pillar_cut[:, :, 3] = np.where(true_bg, 0, 255)
pillar_img = Image.fromarray(pillar_cut, "RGBA")

ys, xs = np.where(~true_bg)
bx0, by0, bx1, by1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
pillar_crop = pillar_img.crop((bx0, by0, bx1, by1))

PILLAR_CANVAS = (160, 224)
PILLAR_FOOT = (80, 216)
pscale = 190.0 / pillar_crop.height
pw, ph = round(pillar_crop.width * pscale), round(pillar_crop.height * pscale)
pillar_scaled = pillar_crop.resize((pw, ph), Image.Resampling.NEAREST)
pillar_canvas = Image.new("RGBA", PILLAR_CANVAS)
p_off = (PILLAR_FOOT[0] - pw // 2, PILLAR_FOOT[1] - ph)
pillar_canvas.alpha_composite(pillar_scaled, p_off)
pillar_path = OUT / "tiles/pillar_base.png"
pillar_canvas.save(pillar_path)

# Locate the embers bowl mouth (bright warm patch in the upper third of the crop) so the flame
# overlay's runtime anchor lines up with the actual painted bowl, not a guessed constant.
top_band = np.asarray(pillar_crop.convert("RGBA"), dtype=np.float32)[: round(pillar_crop.height * 0.35)]
warm = (top_band[:, :, 0] > 160) & (top_band[:, :, 1] > 70) & (top_band[:, :, 2] < 150) & (top_band[:, :, 3] > 0)
wy, wx = np.where(warm)
bowl_cx = round(p_off[0] + float(wx.mean()) * pscale, 1) if len(wx) else PILLAR_CANVAS[0] / 2.0
# Bottom of the warm-pixel bbox, not the centroid -- this is where the flame's base should visually
# sit (the floor of the embers window), not the middle of the glow.
bowl_cy = round(p_off[1] + float(wy.max()) * pscale, 1) if len(wy) else PILLAR_FOOT[1] * 0.3
print(f"PASS pillar base {PILLAR_CANVAS}, foot {PILLAR_FOOT}, bowl anchor ({bowl_cx},{bowl_cy})")

# =================================================================== 2. 16-frame flame flicker grid
# Generated on a near-white background; the model insisted on drawing a small wood/log base under
# every flame despite explicit "no logs" instructions (tried twice). Log vs. flame color ranges
# overlap too much to separate by hue or brightness alone (both can be dark reddish-brown) -- the
# reliable signal, calibrated by direct pixel sampling, is SATURATION: flame colors are vivid
# (low blue relative to red -- a "pure" warm hue) while the log's brown is comparatively muddy
# (blue is a much bigger fraction of red). Bright pixels (white/yellow core, sum>330) are flame
# regardless of hue; among darker pixels, low blue/red ratio (<0.22) means flame, higher means wood.
grid_raw = Image.open(SRC / "flame-grid-raw.png").convert("RGB")
garr = np.asarray(grid_raw, dtype=np.int16)
gR, gG, gB = garr[:, :, 0], garr[:, :, 1], garr[:, :, 2]
bg = (gR > 222) & (gG > 222) & (gB > 222)
ssum = gR + gG + gB
ratio = gB.astype(np.float32) / (gR.astype(np.float32) + 1.0)
warm = (gR - gB) > 30
flame_like = (~bg) & (((ssum > 330) & warm) | (ratio < 0.22))

GRID = 4
cell = grid_raw.width // GRID
FLAME_PALETTE_HEX = ["#120302", "#3a0d04", "#7a1a05", "#b9360a", "#e2590c", "#f07d16", "#f6a221",
                      "#f9c23c", "#fbdd5e", "#fff2b0", "#ffffff", "#ffe9a3"]
pal_img = Image.new("P", (16, 16))
flat = []
for h in FLAME_PALETTE_HEX:
    flat.extend(bytes.fromhex(h[1:]))
pal_img.putpalette(flat + flat[:3] * (256 - len(FLAME_PALETTE_HEX)))

FLAME_CANVAS = (112, 144)
FLAME_FOOT = (56, 140)
records = []
contact = Image.new("RGB", (4 * 224, 4 * 224), "#1a1f26")
idx = 0
for row in range(GRID):
    for col in range(GRID):
        y0, x0 = row * cell, col * cell
        sub = flame_like[y0:y0 + cell, x0:x0 + cell]
        comps = components(sub, min_size=3)
        if not comps:
            idx += 1
            continue
        keep = np.zeros_like(sub, dtype=bool)
        for comp in comps:
            for yy, xx in comp:
                keep[yy, xx] = True
        main = comps[0]
        main_ys = [p[0] for p in main]
        main_xs = [p[1] for p in main]
        main_bottom = max(main_ys)
        main_cx = (min(main_xs) + max(main_xs)) / 2.0

        cell_rgb = garr[y0:y0 + cell, x0:x0 + cell].astype(np.uint8)
        cell_rgba = np.zeros((cell, cell, 4), dtype=np.uint8)
        cell_rgba[:, :, :3] = cell_rgb
        cell_rgba[:, :, 3] = np.where(keep, 255, 0)
        cell_img = Image.fromarray(cell_rgba, "RGBA")

        ky, kx = np.where(keep)
        cy0, cy1 = int(ky.min()), int(ky.max()) + 1
        cx0, cx1 = int(kx.min()), int(kx.max()) + 1
        flame_crop = cell_img.crop((cx0, cy0, cx1, cy1))
        anchor_x_in_crop = main_cx - cx0
        anchor_y_in_crop = main_bottom - cy0

        rgb = flame_crop.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGBA")
        rgb.putalpha(flame_crop.getchannel("A"))
        # Target height matches the pillar's own embers-window opening (~51px measured in the
        # pillar canvas, see bowl_anchor above) plus a little extra so the flame licks up through
        # and slightly above the window opening, not dwarfing the whole lantern roof.
        fscale = 58.0 / (main_bottom - min(main_ys) + 1)
        fw, fh = max(1, round(rgb.width * fscale)), max(1, round(rgb.height * fscale))
        scaled = rgb.resize((fw, fh), Image.Resampling.NEAREST)
        frame = Image.new("RGBA", FLAME_CANVAS)
        foff = (round(FLAME_FOOT[0] - anchor_x_in_crop * fscale), round(FLAME_FOOT[1] - anchor_y_in_crop * fscale))
        frame.alpha_composite(scaled, foff)
        path = OUT / f"tiles/flame_{idx:02d}.png"
        frame.save(path)
        records.append(dict(index=idx, path="res://" + path.relative_to(ROOT).as_posix(), size=list(FLAME_CANVAS),
                             anchor=list(FLAME_FOOT), sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        big = frame.resize((224, 224), Image.Resampling.NEAREST)
        contact.paste(big, (col * 224, row * 224), big)
        idx += 1

contact.save(ROOT / "docs/visuals/fire-pillar/flame-16-contact.png")
print(f"PASS {len(records)} flame-only frames extracted (log base removed by saturation, not position), shared {len(FLAME_PALETTE_HEX)}-color palette")

data = dict(
    schema="shinobi_fire_pillar_v1",
    source_tool="built-in image_gen; no paid PixelLab generation",
    pillar=dict(path="res://assets/environment/fire_pillar/tiles/pillar_base.png", size=list(PILLAR_CANVAS),
                foot_anchor=list(PILLAR_FOOT), bowl_anchor=[bowl_cx, bowl_cy],
                sha256=hashlib.sha256(pillar_path.read_bytes()).hexdigest()),
    flame=dict(frame_size=list(FLAME_CANVAS), foot_anchor=list(FLAME_FOOT), frames=records,
               palette=FLAME_PALETTE_HEX, fps=14.0, loop=True,
               note="16 real painted key-pose frames extracted from one generated 4x4 flicker grid "
                    "(log/base band removed per-pixel by color saturation, not a fixed crop line, "
                    "after an earlier fixed-proportion-crop attempt cut some frames down to nothing "
                    "-- see order for the full story). Extra flicker richness beyond these 16 painted "
                    "frames (position/scale jitter, ember particles, glow pulse) is procedural, same "
                    "hybrid philosophy as docs/visuals/wind-grass-nine (144 phases) and "
                    "blossom_trees (96 phases) -- not claimed as additional painted frames"),
)
(OUT / "fire_pillar.art.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
print("WROTE assets/environment/fire_pillar/fire_pillar.art.json")
