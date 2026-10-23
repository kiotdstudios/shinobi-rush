"""Temple wall face textures for the fixed arena's placeholder walls (owner 2026-10-23: "delete all
placeholder walls and replace them with new temple wall assets").

Scope note: this replaces the VISUAL ONLY of WorldScale.BLOCKS' four "Wall"-classified entries
(indices 1, 4, 5, 6 -- the ones PlacedObjects.def_of() itself labels "Wall", height >= 140) with real
stone-and-trim textures drawn by TrainingArena.Block/BlockRear via tiling, in place of the flat grey
polygon + "PLACEHOLDER" caption. Collision/footprint/height/index values in WorldScale.BLOCKS are
UNCHANGED -- zero risk to ArenaNav, the Bandit's tuned choke-point geometry, or any test that reads
BLOCKS by index. See the order for why: wall_kit_v2's existing temple-wall pieces are diagonal
isometric RUNS (built for the free-form World Builder, not axis-aligned slots), so they cannot be
dropped onto these straight axis-aligned footprints without changing the blocked shape; this
delivers new axis-aligned face art instead, matching wall_kit_v2's shipped palette exactly (dark
blue-grey stone + dark maroon trim) so both wall styles read as the same world.

Source: one AI-generated stone-brick study image (built-in image_gen, no paid PixelLab generation),
cropped to a clean brick region, made horizontally seamless (wrap + feather blend), downsampled to a
small pixel-art tile, and palette-quantized to colors sampled DIRECTLY from the shipped
wall_kit_v2/wall_se_6.png (guarantees an exact palette match to the already-approved temple wall art
rather than an independently-guessed one). The maroon trim stripe is drawn procedurally in the same
sampled trim color -- the source image's trim stripe was vertical and mispositioned for this use.
East-face (side, in shadow) and roof (top, in light) variants are derived from the SAME quantized
tile via brightness multiplication, not separately generated/painted -- this guarantees perfect
palette consistency between faces and is disclosed here rather than implied as independent art.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets/environment/kosen_courtyard/walls/source"
OUT = ROOT / "assets/environment/kosen_courtyard/walls"
OUT.mkdir(parents=True, exist_ok=True)

TILE_SIZE = (64, 128)  # native tile resolution used for horizontal repeat + vertical stretch

# Palette sampled directly from the shipped assets/environment/kosen_courtyard/wall_kit_v2/wall_se_6.png
# (rounded cluster centers, see docs/visuals/walls -- kept here as the single source of truth for reuse).
# Capped at the ACTUAL sampled max (~100,110,110) -- an earlier attempt added brighter shades than
# wall_kit_v2 ever uses, which pulled every near-white highlight pixel in the source crop up to
# those too-bright entries instead of down into wall_kit_v2's real (darker, moodier) tonal range.
STONE_HEX = ["#0a0a0a", "#0a0a14", "#1e2832", "#283240", "#323c46", "#28303c", "#323838",
             "#3c4646", "#464a50", "#50585a", "#5a6264", "#64686e"]
TRIM_HEX = ["#1e1416", "#311f23", "#452733", "#4a3346"]
PALETTE_HEX = STONE_HEX + TRIM_HEX


def seamless_horizontal(img: Image.Image, blend_px: int = 24) -> Image.Image:
    """Standard wrap+feather-blend technique: roll the image by half its width so the original
    left/right seam lands in the CENTER, blend across it with a linear-feathered mask, then roll
    back. Result tiles seamlessly left-to-right. Only the seam region changes; the rest of the
    image (now at the edges) is untouched."""
    arr = np.asarray(img.convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    half = w // 2
    rolled = np.roll(arr, half, axis=1)
    out = rolled.copy()
    for i in range(-blend_px, blend_px):
        x = (half + i) % w
        t = (i + blend_px) / (2.0 * blend_px)  # 0..1 across the blend band
        a = rolled[:, (half - blend_px - 1) % w]
        b = rolled[:, (half + blend_px) % w]
        out[:, x] = a * (1.0 - t) + b * t
    unrolled = np.roll(out, -half, axis=1)
    return Image.fromarray(np.clip(unrolled, 0, 255).astype(np.uint8), "RGB")


def quantize(img: Image.Image, hexes: list[str]) -> Image.Image:
    pal = Image.new("P", (16, 16))
    flat = []
    for h in hexes:
        flat.extend(bytes.fromhex(h[1:]))
    pal.putpalette(flat + flat[:3] * (256 - len(hexes)))
    return img.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")


# ---------------------------------------------------------------- 1. front face tile
raw = Image.open(SRC / "wall-study-raw.png").convert("RGB")
crop = raw.crop((0, 60, 480, 60 + 480))  # clean brick band, avoids the (vertical, wrongly-oriented) trim stripe
seamless = seamless_horizontal(crop, blend_px=28)
small = seamless.resize(TILE_SIZE, Image.Resampling.BOX).resize(TILE_SIZE, Image.Resampling.NEAREST)
# Darken before quantizing: the source crop's highlight pixels are near-white, well above anything
# in wall_kit_v2's real tonal range; without this the quantizer clumps most of the image onto the
# single lightest available shade instead of spreading across the darker palette realistically.
small = Image.fromarray((np.asarray(small, dtype=np.float32) * 0.55).clip(0, 255).astype(np.uint8), "RGB")
front = quantize(small, STONE_HEX)

# Procedural trim stripe (owner's reference called for "a thin gold inlay trim line"; the actually
# shipped wall_kit_v2 uses dark maroon instead -- matching the SHIPPED in-game asset takes precedence
# over the older reference mockup so both wall styles read as the same world, per the order).
front_arr = np.asarray(front).copy()
trim_y0 = int(TILE_SIZE[1] * 0.22)
trim_colors = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in TRIM_HEX]
for dy in range(5):
    c = trim_colors[min(dy, len(trim_colors) - 1)]
    front_arr[trim_y0 + dy, :] = c
front = Image.fromarray(front_arr, "RGB")
front_path = OUT / "wall_front.png"
front.save(front_path)

# ---------------------------------------------------------------- 2. derived east-face (shadow) + roof (lit)
def tint(img: Image.Image, factor: float) -> Image.Image:
    arr = np.asarray(img, dtype=np.float32) * factor
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


side = quantize(tint(front, 0.72), PALETTE_HEX)
side_path = OUT / "wall_side.png"
side.save(side_path)

roof = quantize(tint(front, 1.22), PALETTE_HEX)
roof_path = OUT / "wall_roof.png"
roof.save(roof_path)

contact = Image.new("RGB", (TILE_SIZE[0] * 3 + 40, TILE_SIZE[1] + 20), "#14181d")
for i, (name, im) in enumerate([("front", front), ("side", side), ("roof", roof)]):
    contact.paste(im, (10 + i * (TILE_SIZE[0] + 10), 10))
contact.save(ROOT / "docs/visuals/walls/wall-faces-contact.png")

data = dict(
    schema="shinobi_temple_wall_faces_v1",
    source_tool="built-in image_gen; no paid PixelLab generation",
    palette_source="assets/environment/kosen_courtyard/wall_kit_v2/wall_se_6.png (sampled, not guessed)",
    tile_size=list(TILE_SIZE),
    faces=dict(
        front=dict(path="res://assets/environment/kosen_courtyard/walls/wall_front.png",
                   sha256=hashlib.sha256(front_path.read_bytes()).hexdigest()),
        side=dict(path="res://assets/environment/kosen_courtyard/walls/wall_side.png",
                  derivation="front tinted x0.72 (shadow), then requantized to the shared palette",
                  sha256=hashlib.sha256(side_path.read_bytes()).hexdigest()),
        roof=dict(path="res://assets/environment/kosen_courtyard/walls/wall_roof.png",
                  derivation="front tinted x1.22 (lit top), then requantized to the shared palette",
                  sha256=hashlib.sha256(roof_path.read_bytes()).hexdigest()),
    ),
    usage="TrainingArena.Block/BlockRear tile `front` horizontally across the front rectangle "
          "(stretched vertically to each wall's own height) and texture-map `side`/`roof` onto the "
          "existing east-face/roof parallelograms (TrainingArena._draw_tiled_quad), replacing the "
          "flat grey placeholder color + caption. Applied only to WorldScale.BLOCKS entries with "
          "height >= 140 (indices 1, 4, 5, 6 as of this delivery) -- the ones the World Builder's "
          "own PlacedObjects.def_of() calls \"Wall\"; rocks/crates/other blocks are unaffected.",
)
(OUT / "walls.art.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
print("PASS wall_front/side/roof.png written, palette-matched to wall_kit_v2, contact sheet saved")
