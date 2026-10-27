"""Composite existing ground/path and brown earth pixels into registered blends.
No new raw art, palette, resampling or terrain regeneration.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import json, hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/environment/blightwood/path_dirt_transitions'
DOC=ROOT/'docs/visuals/path-dirt-transitions'
(OUT/'tiles').mkdir(parents=True,exist_ok=True)
DOC.mkdir(parents=True,exist_ok=True)
ground_path=ROOT/'assets/environment/blightwood/ground_path/ground9_center.png'
earth_path=ROOT/'assets/environment/blightwood/brown_dirt_path/source/earth-periodic.png'
ground=np.array(Image.open(ground_path).convert('RGBA'))
earth=np.array(Image.open(earth_path).convert('RGB'))
clusters=np.array(Image.open(earth_path).convert('RGB').filter(ImageFilter.GaussianBlur(1.3)))
yy,xx=np.mgrid[:36,:72]
dx=(xx+.5-36)/36;dy=(yy+.5-18)/18
u=(dx+dy)/2;v=(dy-dx)/2
inside=abs(dx)+abs(dy)<1
su=np.floor((xx-36)/2+(yy-18)).astype(int)%72
sv=np.floor((yy-18)-(xx-36)/2).astype(int)%72
material=earth[sv,su]
fine=(material.mean(2)-earth.mean())/255
roles={'corner_top':8,'edge_ne':12,'corner_right':4,'edge_nw':10,'center':15,'edge_se':5,'corner_left':2,'edge_sw':3,'corner_bottom':1}
tiles={};entries=[]
sheet=Image.new('RGB',(864,1080),'#1a2d2f');draw=ImageDraw.Draw(sheet)
for variant in range(3):
    coarse=(clusters[(sv//3+variant*19)%72,(su//3+variant*13)%72].mean(2)-earth.mean())/255
    for mask in range(16):
        out=np.zeros((36,72,4),np.uint8)
        # Shared corner values make neighboring transitions agree at seams.
        # Modulation vanishes on all four sides; only interiors vary.
        a,b=u+.5,v+.5
        cover=((mask&8)>0)*(1-a)*(1-b)+((mask&4)>0)*a*(1-b)+((mask&1)>0)*a*b+((mask&2)>0)*(1-a)*b
        envelope=np.maximum(0,16*a*b*(1-a)*(1-b))
        threshold=.5+envelope*(coarse*1.8+fine*.24)
        dirt=inside&(cover>threshold)
        out[inside]=ground[inside]
        out[dirt,:3]=material[dirt]
        out[inside,3]=255
        im=Image.fromarray(out);name=f'path_dirt_{mask:02d}_{chr(97+variant)}'
        target=OUT/'tiles'/f'{name}.png';im.save(target);tiles[mask,variant]=im
        entries.append({'id':name,'mask':mask,'variation':variant,'path':'res://'+target.relative_to(ROOT).as_posix(),'dirt_pixels':int(dirt.sum()),'opaque_pixels':int(inside.sum()),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
        sx=(mask%4)*216;sy=variant*360+(mask//4)*90
        sheet.paste(im.resize((144,72),Image.Resampling.NEAREST),(sx+12,sy+4),im.resize((144,72),Image.Resampling.NEAREST))
        draw.text((sx+157,sy+23),f'{mask:02d}{chr(65+variant)}',fill='#d9c2a0')
for role,mask in roles.items():
    for variant in range(3):tiles[mask,variant].save(OUT/'tiles'/f'path_dirt9_{role}_{chr(97+variant)}.png')
sheet.save(DOC/'contact-sheet.png')
data={'schema':'shinobi_path_to_dirt_v1','canvas':[72,36],'anchor':[36,18],'logical_tile_size':[72,36],
      'mask_bits':{'bottom':1,'left':2,'right':4,'top':8},'mask_meaning':'Set corner is dirt; unset corner is existing ground/path. Same corner-bit convention as shoreline kits.',
      'nine_roles':roles,'variations':3,'texture_filter':'nearest','collision':'none; full floor diamond',
      'sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ground_path,earth_path]},'tiles':entries}
(OUT/'path-dirt.art.json').write_text(json.dumps(data,indent=2)+'\n')
# Native tiled overview: original ground surrounds a dirt clearing with bends.
board=Image.new('RGBA',(900,480),'#1a2d2f')
def soil_corner(u,v):
    clearing=((u-3.2)/3.1)**2+((v-2.4)/2.2)**2<1
    # A layout guide for the exported tiles, not newly drawn terrain pixels.
    trail=any((u-(4.5+t*3))**2+(v-(3.5+t*3-.5*np.sin(t*np.pi)))**2<(0.65+.15*np.cos(t*6))**2 for t in np.linspace(0,1,40))
    return clearing or trail
for u in range(-2,11):
    for v in range(-3,10):
        x,y=450+(u-v)*36,40+(u+v)*18
        im=Image.fromarray(ground)
        mask=sum(bit for bit,(du,dv) in zip([1,2,4,8],[(.5,.5),(-.5,.5),(.5,-.5),(-.5,-.5)]) if soil_corner(u+du,v+dv))
        im=tiles[mask,(u+2*v)%3]
        board.alpha_composite(im,(x-36,y-18))
board.convert('RGB').save(DOC/'blend-layout.png')
print(json.dumps({'canonical_tiles':48,'nine_role_aliases':27,'opaque_diamond_pixels':int(inside.sum()),'sources_unchanged':True}))
