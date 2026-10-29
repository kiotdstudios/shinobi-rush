"""Deterministic processing of native PixelLab sources, never raw art drawing."""
from pathlib import Path
from PIL import Image, ImageDraw
from collections import Counter
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/environment/blightwood_foliage'
DOC=ROOT/'docs/visuals/vines-ferns';DOC.mkdir(parents=True,exist_ok=True)
grass=ROOT/'assets/environment/kosen_courtyard/grass/tiles/grass9_center.png'
allowed={p[:3] for p in Image.open(grass).convert('RGBA').get_flattened_data() if p[3]}
names=['Short ivy','Curled ivy','Dense ivy','Fan fern','Spreading fern','Curled fern']
sources=json.loads((OUT/'source/pixellab-objects.json').read_text())
entries=[]
for n in range(6):
    vine=n<3
    name=('vine' if vine else 'fern')+'_%02d'%(n%3+1)
    raw=OUT/'source'/(name+'-raw.png');im=Image.open(raw).convert('RGBA')
    assert im.size==(128,128) and set(im.getchannel('A').get_flattened_data())=={0,255}
    assert all(p[:3] in allowed for p in im.get_flattened_data() if p[3]),name
    crop=im.crop(im.getbbox())
    ratio=(66 if n!=1 else 72)/crop.height if vine else [72,68,58][n-3]/crop.width
    size=(round(crop.width*ratio),round(crop.height*ratio))
    crop=crop.resize(size,Image.Resampling.NEAREST)
    anchor=[64,12 if vine else 116]
    frame=Image.new('RGBA',(128,128))
    frame.alpha_composite(crop,(64-crop.width//2,anchor[1] if vine else anchor[1]-crop.height))
    frame.save(OUT/(name+'.png'))
    box=frame.getbbox();center=((box[0]+box[2])/2,(box[1]+box[3])/2)
    pick=min(((x,y) for y in range(128) for x in range(128) if frame.getpixel((x,y))[3]),key=lambda p:(p[0]-center[0])**2+(p[1]-center[1])**2)
    entries.append(dict(id='blight_'+name,label=names[n],file=name+'.png',size=[128,128],anchor=anchor,lift=66 if vine else 0,sort_dy=1 if vine else 0,hang=vine,content_bounds=list(box),pick_pixel=list(pick),footprint=[12,6],render_tint='#ffffff' if vine else '#d27dff',source_sha256=hashlib.sha256(raw.read_bytes()).hexdigest(),object_id=sources['objects'][n],processing='alpha crop, uniform nearest-neighbor reduction, fixed root placement; no raw pixels painted'))
manifest=dict(version=1,generator='PixelLab MCP create_1_direction_object',palette_source=str(grass.relative_to(ROOT)),palette_source_sha256=hashlib.sha256(grass.read_bytes()).hexdigest(),palette=['#%02x%02x%02x'%c for c in sorted(allowed)],animation=dict(type='anchored native-pixel shader sway; not AI in-between frames',fps=24,loop_seconds=4,phase_count=96,amplitude_pixels=dict(vine=2,fern=1.3),root_pinned=True),items=entries)
(OUT/'foliage.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
sheet=Image.new('RGB',(576,364),(26,45,47));d=ImageDraw.Draw(sheet)
for n,e in enumerate(entries):
    x=(n%3)*192;y=(n//3)*182
    image=Image.open(OUT/e['file']);sheet.paste(image,(x+32,y+10),image)
    d.text((x+18,y+150),e['label'],fill='#b0b59e')
sheet.save(DOC/'contact-sheet.png')
print('PASS: 6 RGBA assets; exact approved palette; fixed roots; original PixelLab sources preserved')
