"""Chainable wall kit from PixelLab art (src/wall.png, pillar.png, ruin.png).

wall.png is 2:1 iso, so un-shearing it (shift each column up by x//2) gives a flat elevation. We cut it into
LEFT end (post) | repeatable PANEL | RIGHT end (post + end face), rebuild any run length in whole cells (36px),
and shear it back. Mirrored copies give the other diagonal. Output: wall_kit_v2/*.png + kit.json
(anchor = front-bottom-left ground corner in the PNG; run = ground vector of the front edge).
"""
import colorsys, json, os
from PIL import Image

D = 'assets/environment/kosen_courtyard/wall_kit_v2/'
CELL = 36
X0 = 31                  # first opaque column of src/wall.png
LEFT_W, RIGHT_START = 30, 122   # flat-strip columns (after unshear, relative to X0)
FRONT0, FRONT1 = 8, 140         # front face left/right edge in flat columns
PANEL_SRC = (38, 110)           # plain panel columns used for repeating (72 px = 2 slabs)


def palette_lock(im, sat_k, hue_shift=-3 / 360, hi=0.36, hi_k=0.6):
    """Pull slate pixels onto the floor tile stats (hue 218, sat .23, val .29, p90 .36). Red/gold accents untouched."""
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if (s > .30 and (h < .04 or h > .93)) or (s > .5 and .08 < h < .17):
                continue
            if v > hi:
                v = hi + (v - hi) * hi_k
            r2, g2, b2 = colorsys.hsv_to_rgb((h + hue_shift) % 1, s * sat_k, v)
            out.putpixel((x, y), (round(r2 * 255), round(g2 * 255), round(b2 * 255), a))
    return out


def unshear(im):
    flat = Image.new('RGBA', (im.width, im.height + 120), (0, 0, 0, 0))
    for x in range(X0, im.width):
        col = im.crop((x, 0, x + 1, im.height))
        if col.getbbox() is None:
            continue
        flat.paste(col, (x, 60 - (x - X0) // 2), col)
    bb = flat.getbbox()
    flat = flat.crop((X0, bb[1], bb[2], bb[3]))
    return flat


def build_run(flat, cells):
    n = CELL * cells
    panel_w = n - (LEFT_W - FRONT0) - (FRONT1 - RIGHT_START)
    assert panel_w >= 20, cells
    H = flat.height
    strip = Image.new('RGBA', (FRONT0 + n + (flat.width - FRONT1), H), (0, 0, 0, 0))
    strip.alpha_composite(flat.crop((0, 0, LEFT_W, H)), (0, 0))
    px = LEFT_W
    sx = PANEL_SRC[0]
    while px < LEFT_W + panel_w:
        w = min(PANEL_SRC[1] - sx, LEFT_W + panel_w - px)
        strip.alpha_composite(flat.crop((sx, 0, sx + w, H)), (px, 0))
        px += w
        sx = PANEL_SRC[0] if sx + w >= PANEL_SRC[1] else sx + w
    strip.alpha_composite(flat.crop((RIGHT_START, 0, flat.width, H)), (px, 0))
    W = strip.width
    out = Image.new('RGBA', (W, H + W // 2 + 2), (0, 0, 0, 0))
    for x in range(W):
        out.alpha_composite(strip.crop((x, 0, x + 1, H)), (x, x // 2))
    # anchor: bottom of the front-left edge column
    col = out.crop((FRONT0, 0, FRONT0 + 1, out.height)).getbbox()
    return out, (FRONT0, col[3] - 1), (n, n // 2)


def main():
    meta = {}
    sheet = []
    wall = palette_lock(Image.open(D + 'src/wall.png').convert('RGBA'), 0.85)
    pillar = palette_lock(Image.open(D + 'src/pillar.png').convert('RGBA'), 0.75)
    ruin = palette_lock(Image.open(D + 'src/ruin.png').convert('RGBA'), 0.85)
    flat = unshear(wall)

    def save(name, im, anchor, run):
        bb = im.getbbox()
        im = im.crop(bb)
        anchor = (anchor[0] - bb[0], anchor[1] - bb[1])
        im.save(D + name + '.png')
        meta[name] = {'size': list(im.size), 'anchor': list(anchor), 'run': list(run), 'cell': CELL}
        sheet.append(im)

    for cells in (2, 3, 4, 5, 6):
        im, a, run = build_run(flat, cells)
        bb = im.getbbox()
        save('wall_se_%d' % cells, im, a, run)
        fl = im.crop(bb).transpose(Image.FLIP_LEFT_RIGHT)
        w = bb[2] - bb[0]
        meta['wall_sw_%d' % cells] = {'size': list(fl.size), 'anchor': [w - (a[0] - bb[0]), a[1] - bb[1]], 'run': [-run[0], run[1]], 'cell': CELL}
        fl.save(D + 'wall_sw_%d.png' % cells)
    pb = pillar.getbbox()
    cxp = (pillar.getchannel('A').crop((0, pb[3] - 1, pillar.width, pb[3])).getbbox()[0] + pillar.getchannel('A').crop((0, pb[3] - 1, pillar.width, pb[3])).getbbox()[2]) // 2
    save('pillar', pillar, (cxp, pb[3] - 1), (0, 0))
    save('ruin_se', ruin, (30, ruin.height - 30), (0, 0))
    ruin.crop(ruin.getbbox()).transpose(Image.FLIP_LEFT_RIGHT).save(D + 'ruin_sw.png')
    json.dump(meta, open(D + 'kit.json', 'w'), indent=1)
    # review sheet: 2,3,4,6 cell, pillar, ruin
    show = [Image.open(D + n + '.png') for n in ('wall_se_2', 'wall_se_3', 'wall_se_4', 'wall_se_6', 'pillar', 'ruin_se')]
    W = sum(i.width for i in show) + 14 * len(show)
    H = max(i.height for i in show) + 20
    s = Image.new('RGBA', (W, H), (30, 33, 46, 255))
    x = 8
    for i in show:
        s.alpha_composite(i, (x, H - i.height - 8))
        x += i.width + 14
    s.resize((s.width * 2, s.height * 2), Image.NEAREST).save(D + 'src/kit_sheet.png')
    flat.save(D + 'src/_flat.png')


if __name__ == '__main__':
    main()
