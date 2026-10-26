"""Re-register the nine flat grass tiles onto the 72x36 lattice diamond and fill
any gap inside the diamond with the tile's own grass, so every tile covers 100%
of its diamond (1 tile = 1 square, no white void). Blades/tufts that overhang the
diamond are kept. Anchor stays [56,84] in the 112x112 canvas.
Run from the repo root: python3 tools/fix_grass_registration.py
"""
from PIL import Image
import glob, os

DIR = "assets/environment/kosen_courtyard/grass/tiles/"
ROLES = ["corner_top", "edge_ne", "corner_right", "edge_nw", "center", "edge_se", "corner_left", "edge_sw", "corner_bottom"]
AX, AY = 56, 84

def inside(x, y, k=1.0):
    return abs(x + .5) / 36 + abs(y + .5) / 18 < k

def cover(A, dy):
    h = t = 0
    for y in range(-18, 18):
        for x in range(-36, 36):
            if not inside(x, y, .96):
                continue
            t += 1
            yy = y + AY - dy
            if 0 <= yy < 112 and A.getpixel((x + AX, yy)) > 127:
                h += 1
    return h / t

def shifted(im, dy):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, dy), im)
    return out

tiles = {r: Image.open(DIR + "grass9_%s.png" % r).convert("RGBA") for r in ROLES}
best = {}
for r, im in tiles.items():
    A = im.split()[3]
    best[r] = max(range(-4, 20), key=lambda d: cover(A, d))
reg = {r: shifted(tiles[r], best[r]) for r in ROLES}

cen = reg["center"]
for r in ROLES:
    im = reg[r]
    px = im.load()
    cp = cen.load()
    for y in range(-18, 18):
        for x in range(-36, 36):
            if not inside(x, y):
                continue
            X, Y = x + AX, y + AY
            if px[X, Y][3] < 255:
                base = cp[X, Y]
                if base[3] < 255:
                    base = cp[X, Y]
                over = px[X, Y]
                a = over[3] / 255.0
                px[X, Y] = tuple(int(over[i] * a + base[i] * (1 - a)) for i in range(3)) + (255,)
    im.save(DIR + "grass9_%s.png" % r)
    print(r, "shift", best[r])
