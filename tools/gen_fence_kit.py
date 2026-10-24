"""Modular isometric wooden fence kit built from PixelLab art (assets/environment/fence_kit/src/rail2.png).

rail1.png is one flat front-elevation fence panel (post | two rails | post | two rails | post). The middle post and the
rail span after it are cut out unscaled; each piece shears the rail span along the iso axis (2:1, whole pixels) between
posts one cell (36 px, 18 px down) apart. Every piece starts and ends on a post and pieces chain by putting the next
piece's anchor (ground point of its first post) on the previous piece's end post, so shared posts overlap pixel-for-pixel.
Output: assets/environment/fence_kit/*.png + kit.json (anchor = first post's ground point, run = ground vector).
"""
import json
from PIL import Image

D = 'assets/environment/fence_kit/'
SRC = Image.open(D + 'src/rail2.png').convert('RGBA')
CELL = 36
SCALE = 2
M = 6
POST_X0, POST_X1 = 43, 52
POST_Y0, POST_Y1 = 2, 29
RAIL_X0 = 55           # 26 visible rail columns between the posts (each post hides 5 px at either end)
RAIL_W = 26
RAIL_Y0, RAIL_Y1 = 9, 25

POST = SRC.crop((POST_X0, POST_Y0, POST_X1 + 1, POST_Y1 + 1))
PW, PH = POST.size
CX = PW // 2
RAIL = SRC.crop((RAIL_X0, RAIL_Y0, RAIL_X0 + RAIL_W, RAIL_Y1 + 1))


def strip(flip):
    s = Image.new('RGBA', (CELL, RAIL.height), (0, 0, 0, 0))
    pad = (CELL - RAIL_W) // 2
    s.alpha_composite(RAIL, (pad, 0))
    for i in range(pad):
        s.alpha_composite(RAIL.crop((0, 0, 1, RAIL.height)), (i, 0))
        s.alpha_composite(RAIL.crop((RAIL_W - 1, 0, RAIL_W, RAIL.height)), (pad + RAIL_W + i, 0))
    return s.transpose(Image.FLIP_LEFT_RIGHT) if flip else s


def piece(axis, cells):
    sx = 1 if axis == 'se' else -1
    w = CELL * cells + PW + 2 * M
    h = 18 * cells + PH + 2 * M
    ax = (M + CX) if sx == 1 else (w - M - 1 - CX)
    ay = M + PH - 1
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    s = strip(axis == 'sw')
    top = ay - (PH - 1)
    for c in range(cells):
        x0 = ax + sx * CELL * c
        for i in range(CELL):
            col = s.crop((i, 0, i + 1, s.height))
            im.alpha_composite(col, (x0 + sx * i, top + (RAIL_Y0 - POST_Y0) + 18 * c + round(i * 18 / CELL)))
    for i in range(cells + 1):
        im.alpha_composite(POST, (ax + sx * CELL * i - CX, top + 18 * i))
    return im, (ax, ay), (sx * CELL * cells, 18 * cells)


def main():
    kit = {}
    for axis in ('se', 'sw'):
        for n in (1, 2, 3, 4):
            im, anchor, run = piece(axis, n)
            name = f'fence_{axis}_{n}'
            im.save(D + name + '.png')
            kit[name] = {'size': list(im.size), 'anchor': list(anchor), 'run': list(run)}
    im = Image.new('RGBA', (PW + 2 * M, PH + 2 * M), (0, 0, 0, 0))
    im.alpha_composite(POST, (M, M))
    im.save(D + 'archive/fence_post.png')
    kit['fence_post'] = {'size': list(im.size), 'anchor': [M + CX, M + PH - 1], 'run': [0, 0]}
    tall = Image.open(D + 'src/post3.png').convert('RGBA')
    bb = tall.getbbox()
    t = Image.new('RGBA', (bb[2] - bb[0] + 2 * M, bb[3] - bb[1] + 2 * M), (0, 0, 0, 0))
    t.alpha_composite(tall.crop(bb), (M, M))
    t.save(D + 'archive/fence_post_tall.png')
    kit['fence_post_tall'] = {'size': list(t.size), 'anchor': [t.width // 2, t.height - M - 1], 'run': [0, 0]}
    # Everything is drawn at 1x then enlarged with nearest-neighbour so pixels match the trees and the
    # fences read at human scale next to the player (SCALE=2: a post is ~1.6x the player's calf height).
    kit.pop('fence_post'); kit.pop('fence_post_tall')  # archived: kept in archive/, not in the builder
    for name, v in kit.items():
        im = Image.open(D + name + '.png').convert('RGBA')
        im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST).save(D + name + '.png')
        v['size'] = [c * SCALE for c in v['size']]
        v['anchor'] = [c * SCALE for c in v['anchor']]
        v['run'] = [c * SCALE for c in v['run']]
    json.dump(kit, open(D + 'kit.json', 'w'), indent=1)


if __name__ == '__main__':
    main()
