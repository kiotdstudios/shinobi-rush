"""Assemble an editable reference-inspired riverbank from approved catalog pieces.
No image generation, resampling, default-map edits or new gameplay rules.
"""
import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / 'assets/environment/blightwood/cliff_kit'
modules = {m['id']: m for m in json.loads((KIT/'cliffs.art.json').read_text())['modules']}
engineering = json.loads((ROOT/'world/demos/blightwood-cliff-kit.json').read_text())
cells = {(i['x']+p[0], i['y']+p[1]) for i in engineering['items']
         if i['id'] in modules for p in modules[i['id']]['cells']}
items = []
def add(id, x, y):
    items.append(dict(id=id, x=x, y=y))

def wet(x, y):
    # A broad catch pool continues into a narrower southeast-running river.
    basin = ((x-55)/180)**2 + ((y-195)/76)**2 < 1
    stream = 150 < x < 720 and abs(y-(185+.37*x+13*math.sin(x/100))) < 44
    return y >= 103 and (basin or stream)

def path(x, y):
    return abs(x-(-330+65*math.sin((y-50)/115))) < (48+8*math.sin(y/75))

vertices = [(0,-18,8),(36,0,4),(-36,0,2),(0,18,1)]
for u in range(-17,18):
    for v in range(-15,16):
        x,y=36*(u-v),18*(u+v)
        water = [wet(x+dx,y+dy) for dx,dy,_ in vertices]
        if any(water):
            mask=sum(bit for is_water,(_,_,bit) in zip(water,vertices) if not is_water)
            add('shore_grass_%02d'%mask,x,y)
        else:
            # Exact registered grass/path corner masks; matching shared vertices.
            mask=sum(bit for dx,dy,bit in vertices if not path(x+dx,y+dy))
            if mask==15:
                add('grass9_center',x,y)
            else:
                variant='abc'[(u*31+v*17)%3] if mask not in (0,15) else 'a'
                add('grass_dirt_%02d_%s'%(mask,variant),x,y)

# Preserve the proven connected island/stair geometry but dress it as terrain.
# Upper stream follows the SW lattice into the existing two-cell waterfall lip.
river = {(108-36*n,18+18*n) for n in range(-5,5)}
river |= {(x+36,y+18) for x,y in list(river)}
lip = {(-36,90),(0,108)}
for x,y in sorted(cells-lip,key=lambda p:(p[1],p[0])):
    trail = abs(x-(-240+.25*(y+20)))<46 and y<40
    add('cliff_upper_river' if (x,y) in river else 'cliff_path' if trail else 'cliff_grass',x,y)
add('cliff_waterfall_lip',-36,90)
add('cliff_stairs_se',-288,54)
add('cliff_stairs_sw',396,144)
add('cliff_cascade',-36,108)

# Irregular banks retain room for walking and clear the waterfall/left stair.
for u in range(-12,13):
    for v in range(-11,12):
        x,y=36*(u-v),18*(u+v)
        if (x,y) in cells or wet(x,y) or path(x,y) or y<105 or math.hypot(x+36,y-108)<145:
            continue
        if min(abs(y-195),abs(y-(185+.37*x)))<115 and (u*17+v*11)%5 in (0,1):
            add('grass_tall_%02d'%((u+v)%4),x+(u*7%15)-7,y)
for id,x,y in [('tree_3',-475,-70),('tree_5',525,-30),('tree_2',-510,260),
               ('blight_rock_01',-145,245),('blight_rock_02',360,315),
               ('blight_wooden_post',-460,145),('blight_stone_pagoda',325,280),
               ('blight_fireflies',-110,170),('blight_fireflies',220,270),
               ('fence_se_2',-550,60),('fence_sw_1',430,220),
               ('player_spawn',-360,90)]:
    add(id,x,y)
# Root positions are logical ground points; the vine renderer lifts its top 66px.
for n,(x,y) in enumerate([(-198,27),(-126,63),(-90,81),(90,117),(162,135),(270,135)]):
    add('blight_vine_%02d'%(n%3+1),x,y)
for n,(x,y) in enumerate([(-225,180),(-100,290),(270,210),(290,230),(420,250),(330,380),(500,270),(-420,200),(-410,300)]):
    assert not wet(x,y),'Fern roots must remain on the bank'
    add('blight_fern_%02d'%(n%3+1),x,y)
data = dict(version=5,blightwood_map=True,shrine_section=True,items=items)
text=json.dumps(data,indent=2)+'\n'
for p in [ROOT/'world/demos/blightwood-river-section.json',KIT/'river-section.json']:
    p.write_text(text,encoding='utf-8')
print(f'{len(items)} editable items; {len(cells)} upper cells; source/runtime maps identical')
