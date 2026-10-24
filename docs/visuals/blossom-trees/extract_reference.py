"""Deterministic background cleanup/extraction only. No creative redraw or resize."""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib, json
import random
from collections import deque
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'assets/environment/blossom_trees'
source=BASE/'source/reference.jpg'
im=Image.open(source).convert('RGB')
rgb=np.array(im)
mask=(rgb.min(2)<239)|(np.ptp(rgb.astype(int),axis=2)>13)
h,w=mask.shape
remaining=mask.copy();components=[]
for y in range(h):
    for x in range(w):
        if not remaining[y,x]: continue
        todo=deque([(x,y)]);remaining[y,x]=False;points=[]
        while todo:
            px,py=todo.popleft();points.append((px,py))
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    xx,yy=px+dx,py+dy
                    if 0<=xx<w and 0<=yy<h and remaining[yy,xx]:
                        remaining[yy,xx]=False;todo.append((xx,yy))
        components.append(points)
main=sorted(sorted(components,key=len,reverse=True)[:5],key=lambda pts:min(p[0] for p in pts))
owners=np.full((h,w),-1,dtype=np.int16);distance=np.full((h,w),999,dtype=np.int16);todo=deque()
for i,points in enumerate(main):
    for x,y in points: owners[y,x]=i;distance[y,x]=0;todo.append((x,y))
while todo:
    x,y=todo.popleft()
    if distance[y,x]>=12: continue
    for dx,dy in ((-1,0),(1,0),(0,-1),(0,1)):
        xx,yy=x+dx,y+dy
        if 0<=xx<w and 0<=yy<h and owners[yy,xx]<0:
            owners[yy,xx]=owners[y,x];distance[yy,xx]=distance[y,x]+1;todo.append((xx,yy))
cuts=[(max(0,min(p[0] for p in pts)-12),min(w,max(p[0] for p in pts)+13)) for pts in main]
names=['tiered','windswept','weeping','branching','sparse']
trees=[]
preview=Image.new('RGB',(1600,540),'#253743')
for index,((left,right),name) in enumerate(zip(cuts,names)):
    crop=im.crop((left,40,right,455)).convert('RGBA')
    # The JPEG's near-white background is not tree paint. Keep saturated pink/blue
    # highlights, including pale blossoms. A binary matte retains sharp clusters.
    a=(mask[40:455,left:right]&(owners[40:455,left:right]==index)).astype(np.uint8)*255
    rgba=np.array(crop)
    rgba[:,:,3]=a
    # Decontaminate the JPEG white matte only at silhouette antialias pixels.
    # Interior RGB stays byte-identical to the source.
    for py,px in zip(*np.where(a>0)):
        if 0<py<a.shape[0]-1 and 0<px<a.shape[1]-1 and np.all(a[py-1:py+2,px-1:px+2]>0): continue
        p=rgba[py,px,:3].astype(float);pv=255-p;best=None
        for dy in range(-2,3):
            for dx in range(-2,3):
                xx,yy=px+dx,py+dy
                if 0<=xx<a.shape[1] and 0<=yy<a.shape[0] and a[yy,xx]:
                    qv=255-np.array(crop.getpixel((xx,yy))[:3],dtype=float)
                    norm=float(qv@qv)
                    if norm<=float(pv@pv)*1.4: continue
                    opacity=float(pv@qv)/norm
                    error=float(np.linalg.norm(pv-opacity*qv))
                    if .15<opacity<.9 and error<8 and (best is None or error<best[0]):best=(error,opacity)
        if best:
            opacity=best[1];rgba[py,px,:3]=np.clip(255-pv/opacity,0,255).astype(np.uint8);rgba[py,px,3]=round(opacity*255)
    crop=Image.fromarray(rgba)
    # Fixed source-scale canvas: no bbox-fit, upscaling, or per-tree resampling.
    frame=Image.new('RGBA',(320,448))
    offset=((320-crop.width)//2,8)
    frame.alpha_composite(crop,offset)
    path=BASE/'textures'/f'tree_{index+1:02}_{name}.png'
    frame.save(path)
    bbox=frame.getbbox()
    assert bbox and bbox[0]>12 and bbox[2]<308 and bbox[1]>8 and bbox[3]<437
    # Original image bases sit around y420; common ground line y430 in source
    # translates to y398 here. Per-tree anchor follows the visible rock base.
    anchors=[(128,419),(350,422),(650,430),(915,428),(1169,425)]
    ax,ay=anchors[index]
    anchor=[ax-left+offset[0],ay-40+offset[1]]
    candidates=[(x-anchor[0],y-anchor[1]) for y in range(40,anchor[1]-90) for x in range(320)
                if (p:=frame.getpixel((x,y)))[3]>220 and (p[2]>p[0]*1.05 or (p[0]>160 and p[2]>140))]
    emitters=random.Random(index+902).sample(candidates,24)
    record=dict(id=f'tree_{index+1:02}_{name}',texture='res://'+path.relative_to(ROOT).as_posix(),
                size=[320,448],anchor=anchor,source_rect=[left,40,right-left,415],
                source_offset=list(offset),bbox=list(bbox),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                wind_phase=index*1.173,wind_strength=[1.,.85,1.15,.9,.8][index],
                canopy_emission=emitters)
    trees.append(record)
    panel=Image.new('RGB',(320,540),'#253743');panel.paste(frame,(0,40),frame)
    d=ImageDraw.Draw(panel);d.text((12,12),f'{index+1}: {name} / source pixels',fill='white')
    d.ellipse((anchor[0]-3,anchor[1]+37,anchor[0]+3,anchor[1]+43),fill='#ffe6a0')
    preview.paste(panel,(index*320,0))
assert len({t['sha256'] for t in trees})==5
manifest=dict(schema='shinobi_blossom_trees_v1',source='source/reference.jpg',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    source_size=list(im.size),extraction='five connected source silhouettes; native scale; interior RGB preserved; white-matte antialias decontaminated at boundaries only; no generative tree redraw',
    render_filter='nearest',wind=dict(cycle_seconds=4.,phase_count=96,phase_fps=24.,fixed_root_height_px=70,
    technique='bounded canopy UV deformation, source pixels sampled nearest; 96 phase poses, no atlas duplication',max_displacement_px=[7.,1.]),trees=trees)
(BASE/'blossom_trees.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
preview.save(ROOT/'docs/visuals/blossom-trees/tree-contact.png')
print('PASS: five isolated native-scale source-pixel cutouts, transparent background, bounded padding and unique hashes')
