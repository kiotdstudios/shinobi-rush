"""Enemy status-bar art (Bandit and future enemies): own plate, fills and pips, distinct from the player HUD.

Drawn natively at 1x (no runtime scaling) so pixels stay crisp:
  enemy_frame.png 128x14, enemy_hp_fill.png / enemy_chakra_fill.png 124x10, enemy_pip_full/empty.png 12x12.
Run from the repo root: python3 tools/gen_enemy_bars.py
"""
from PIL import Image

D = 'assets/ui/enemy_bars/'
FW, FH = 128, 14
IN = 2  # frame thickness
FILL_W, FILL_H = FW - 2 * IN, FH - 2 * IN
INK = (9, 10, 14, 255)
STEEL = (62, 68, 82, 255)
STEEL_HI = (104, 112, 130, 255)
WELL = (20, 12, 16, 255)
CRIMSON = (176, 48, 47, 255)
CRIMSON_HI = (222, 98, 84, 255)


def frame():
    im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
    px = im.load()
    for y in range(FH):
        for x in range(FW):
            edge = x in (0, FW - 1) or y in (0, FH - 1)
            border = x in (1, FW - 2) or y in (1, FH - 2)
            if edge:
                if (x in (0, FW - 1)) and (y in (0, FH - 1)):
                    continue  # clipped outer corners
                px[x, y] = INK
            elif border:
                px[x, y] = STEEL_HI if y == 1 else STEEL
            else:
                px[x, y] = WELL
    # crimson corner brackets (enemy accent, the player's are gold)
    for cx, sx in ((1, 1), (FW - 2, -1)):
        for cy, sy in ((1, 1), (FH - 2, -1)):
            for k in range(4):
                px[cx + sx * k, cy] = CRIMSON_HI if k == 0 else CRIMSON
            for k in range(1, 3):
                px[cx, cy + sy * k] = CRIMSON
    # centre notch tick on the top edge
    for x in (FW // 2 - 1, FW // 2):
        px[x, 0] = STEEL_HI
    return im


def fill(top, mid, bot, seg_dark):
    im = Image.new('RGBA', (FILL_W, FILL_H), (0, 0, 0, 0))
    px = im.load()
    rows = [top, top, mid, mid, mid, mid, mid, bot, bot, bot]
    for y in range(FILL_H):
        for x in range(FILL_W):
            c = rows[y]
            if x % 12 == 11:  # segment tick every 12 px
                c = seg_dark
            px[x, y] = c
    return im


def pip(full):
    im = Image.new('RGBA', (12, 12), (0, 0, 0, 0))
    px = im.load()
    cx = cy = 5.5
    for y in range(12):
        for x in range(12):
            d = abs(x - cx) + abs(y - cy)
            if d <= 5.5:
                if d > 4.4:
                    px[x, y] = CRIMSON if full else STEEL_HI
                elif full:
                    px[x, y] = (150, 220, 255, 255) if d <= 1.6 else (58, 143, 214, 255)
                else:
                    px[x, y] = WELL
    return im


frame().save(D + 'enemy_frame.png')
fill((226, 108, 92, 255), (190, 52, 52, 255), (126, 30, 38, 255), (96, 22, 30, 255)).save(D + 'enemy_hp_fill.png')
fill((120, 190, 240, 255), (58, 143, 214, 255), (36, 90, 160, 255), (24, 62, 118, 255)).save(D + 'enemy_chakra_fill.png')
pip(True).save(D + 'enemy_pip_full.png')
pip(False).save(D + 'enemy_pip_empty.png')
print('ok')
