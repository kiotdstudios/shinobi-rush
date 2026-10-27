"""Edit existing generated soil and approved grass; never regenerate terrain art.

The continuous material mask is filtered before cutting diamonds, so its curves
do not follow tile boundaries. All colors come from the two existing materials.
"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageEnhance
import numpy as np
import json, re, hashlib

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/environment/blightwood/brown_dirt_path'
DOC = ROOT/'docs/visuals/brown-dirt-path'
GRASS = ROOT/'assets/environment/kosen_courtyard/grass/tiles'
text = (ROOT/'scripts/arena/blightwood_map_data.gd').read_text()
rows = re.findall(r'"([gdscw ]+)"', text)
cells = {(36*(-35+i), 18*(-39+r)):ch for r,row in enumerate(rows)
         for i,ch in enumerate(row) if ch != ' '}
# Mask edits only: isotropic in the unprojected floor plane (2:1 screen ratio).
origin = (min(p[0] for p in cells)-112,min(p[1] for p in cells)-112)
size = (max(p[0] for p in cells)-origin[0]+112,max(p[1] for p in cells)-origin[1]+112)
yy,xx = np.mgrid[:size[1],:size[0]]
wx,wy = xx+origin[0]+.5, yy+origin[1]+.5
field = np.zeros((size[1],size[0]), np.uint8)
for (x,y),ch in cells.items():
    if ch != 'd': continue
    diamond = abs(wx[y-origin[1]-18:y-origin[1]+18,x-origin[0]-36:x-origin[0]+36]-x)/36 + abs(wy[y-origin[1]-18:y-origin[1]+18,x-origin[0]-36:x-origin[0]+36]-y)/18 < 1
    field[y-origin[1]-18:y-origin[1]+18,x-origin[0]-36:x-origin[0]+36][diamond]=255
mask = Image.fromarray(field).resize((size[0],size[1]*2),Image.Resampling.NEAREST)
mask = mask.filter(ImageFilter.GaussianBlur(23)).resize(size,Image.Resampling.BOX)
coverage = np.asarray(mask)/255.
soil = Image.open(OUT/'source/earth-periodic.png').convert('RGB')
palette = soil.quantize(colors=24)
dark = np.asarray(ImageEnhance.Brightness(soil).enhance(.92).quantize(palette=palette,dither=Image.Dither.NONE).convert('RGB'))
light = np.asarray(ImageEnhance.Brightness(soil).enhance(1.08).quantize(palette=palette,dither=Image.Dither.NONE).convert('RGB'))
base = np.asarray(soil)
clusters = np.asarray(soil.filter(ImageFilter.GaussianBlur(1.3)))
grass = np.asarray(Image.open(GRASS/'grass9_center.png').convert('RGBA'))
under = np.asarray(Image.open(ROOT/'assets/environment/blightwood/ground_path/ground9_center.png').convert('RGBA'))
atlas = Image.new('RGBA',(112*32,112*64))
entries=[]
board=Image.new('RGBA',size)
for (x,y),ch in sorted(cells.items(),key=lambda item:(item[0][1],item[0][0])):
    if ch not in 'gd':continue
    left,top=x-origin[0]-56,y-origin[1]-84
    local=coverage[top:top+112,left:left+112]
    if local.shape != (112,112) or (ch=='g' and local.max()<.12):continue
    out=grass.copy()
    py,px=np.mgrid[:112,:112]
    dx,dy=px+.5-56,py+.5-84
    inside=abs(dx)/36+abs(dy)/18<1
    # Full opaque backing, with unchanged grass pixels wherever they exist.
    missing=inside&(out[:,:,3]==0)
    gy,gx=np.clip(py-66,0,35),np.clip(px-20,0,71)
    out[missing]=under[gy[missing],gx[missing]]
    u=np.floor((x+dx)/2+(y+dy)).astype(int)%72
    v=np.floor((y+dy)-(x+dx)/2).astype(int)%72
    material=base[v,u]
    # Existing texture clusters break the boundary, rather than a hard alpha rim.
    grain=(material.astype(float).mean(axis=2)-base.mean())/255
    cluster=(clusters[(v//4)%72,(u//4)%72].astype(float).mean(axis=2)-base.mean())/255
    cut=.43 + grain*.3 + cluster*1.4
    exposed=inside&(local>cut)
    material=np.where(((local<.85)&(cluster<.02))[:,:,None],dark[v,u],light[v,u])
    # Sparse real grass clusters remain in the worn surface, concentrated at edges.
    tuft=(out[:,:,:3].mean(axis=2)>65)&(local<.9)&(cluster<-.035)
    tuft |= (cluster<-.075)&(grain>.07)&(local<.98)
    exposed &= ~tuft
    out[exposed,:3]=material[exposed]
    out[inside,3]=255
    # No green overhang may cover the neighboring continuous dirt surface.
    out[(~inside)&(local>.42),3]=0
    im=Image.fromarray(out)
    index=len(entries); assert index<2048
    atlas.alpha_composite(im,((index%32)*112,(index//32)*112))
    entries.append({'x':x,'y':y,'terrain':ch,'index':index,'dirt_pixels':int(exposed.sum()),'opaque_pixels':int(inside.sum())})
    board.alpha_composite(im,(left,top))
atlas=atlas.crop((0,0,112*32,112*((len(entries)+31)//32)))
atlas.save(OUT/'natural-path-atlas.png')
data={'schema':'blightwood_natural_path_v1','origin':origin,'tile_canvas':[112,112],'anchor':[56,84],
      'atlas_columns':32,'entries':entries,'source_map_sha256':hashlib.sha256(text.encode()).hexdigest(),
      'collision_changes':False,'grass_regenerated':False,'material_colors':'existing earth and grass palettes only'}
(OUT/'natural-path.json').write_text(json.dumps(data,indent=2)+'\n')
board.convert('RGB').save(DOC/'natural-path-layout.png')
print(json.dumps({'tiles':len(entries),'dirt_cells':sum(e['terrain']=='d' for e in entries),'atlas':atlas.size}))

