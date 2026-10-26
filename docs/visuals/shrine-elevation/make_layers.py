"""Split the Ancient Flame Shrine art into depth layers (pixel partition, nothing is repainted).

Every opaque pixel of stone.png (and of emission.png) is assigned to exactly one layer by the first polygon
that contains it (art pixel coordinates, 544x480 canvas, anchor 272,448). The layers recomposite to the
original byte for byte; the script asserts that. Run from the repo root:  python3 docs/visuals/shrine-elevation/make_layers.py
"""
from pathlib import Path
import numpy as np
from PIL import Image

DIR = Path("assets/environment/blightwood_dynamic_shrine")
# (name, rectangle x0,y0,x1,y1) in priority order; whatever is left is "base".
LAYERS = [
    ("fore_l", (100, 208, 184, 305)),   # left pillar blocks on the mound shoulder
    ("fore_r", (332, 246, 452, 332)),   # right pillar blocks
    ("mon",    (246, 68, 328, 242)),    # central monument (and its glyph)
    ("arch_l", (100, 0, 246, 222)),     # left arch
    ("arch_r", (328, 0, 480, 246)),     # right arch
]
NAMES = ["base"] + [n for n, _ in LAYERS]


def owner_map(shape):
    own = np.zeros(shape, dtype=np.uint8)  # 0 = base
    taken = np.zeros(shape, dtype=bool)
    for i, (_, (x0, y0, x1, y1)) in enumerate(LAYERS, start=1):
        sel = np.zeros(shape, dtype=bool)
        sel[y0:y1, x0:x1] = True
        sel &= ~taken
        own[sel] = i
        taken |= sel
    return own


def split(src_name, prefix, only=None):
    src = np.array(Image.open(DIR / src_name).convert("RGBA"))
    own = owner_map(src.shape[:2])
    total = np.zeros_like(src)
    for i, name in enumerate(NAMES):
        if only is not None and name not in only:
            continue
        layer = np.zeros_like(src)
        sel = (own == i) & (src[:, :, 3] > 0)
        layer[sel] = src[sel]
        total[sel] = src[sel]
        if sel.any():
            Image.fromarray(layer).save(DIR / f"{prefix}_{name}.png")
            print(prefix, name, int(sel.sum()), "px")
    assert (total == np.where((src[:, :, 3] > 0)[:, :, None], src, 0)).all(), "layers do not recomposite"


split("stone.png", "stone")
split("emission.png", "emission")
