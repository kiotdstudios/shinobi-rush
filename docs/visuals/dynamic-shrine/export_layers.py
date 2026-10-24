"""Extract authored foliage/emission only. Native pixels, no repaint/resampling."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/environment/blightwood_dynamic_shrine'
raw=Image.open(OUT/'source/pixellab-shrine.png').convert('RGBA')
assert raw.size==(512,448)
image=Image.new('RGBA',(544,480));image.paste(raw,(16,16))
a=np.array(image);stone=a.copy()
y,x=np.indices(a.shape[:2]);r,g,b=[a[:,:,i].astype(int) for i in range(3)]
# Exterior hanging flower/vine bands, below stone attachment: no stone pixels cut.
boxes=[(186,51,215,105),(160,89,176,137),(340,98,362,160),(401,129,415,163)]
regions=[]
for i,(x0,y0,x1,y1) in enumerate(boxes):
    mask=(x>=x0+16)&(x<x1+16)&(y>=y0+16)&(y<y1+16)&(a[:,:,3]>0)&(b>r*1.18)&(b>g*1.06)
    layer=np.zeros_like(a);layer[mask]=a[mask];stone[mask]=0
    assert mask.sum()>15,(i,mask.sum())
    Image.fromarray(layer).save(OUT/f'vine_{i:02}.png')
    regions.append({'index':i,'pixels':int(mask.sum()),'top':y0+16,'bottom':y1+16})
mask=(r>g*1.65)&(r>b*1.25)&(r>65)&(a[:,:,3]>0)
emission=np.zeros_like(a);emission[mask]=a[mask]
Image.fromarray(stone).save(OUT/'stone.png')
Image.fromarray(emission).save(OUT/'emission.png')
image.save(OUT/'assembled.png')
# Reassembly at rest must be pixel-exact to the padded PixelLab artwork.
reassembled=Image.fromarray(stone)
for i in range(4):reassembled.alpha_composite(Image.open(OUT/f'vine_{i:02}.png'))
assert np.array_equal(np.array(reassembled),a)
manifest={'id':'blightwood_ancient_flame_shrine','canvas':[544,480],'native_art_canvas':[512,448],
 'padding':[16,16],'anchor':[272,448],'generator':'PixelLab create_image_pro',
 'job_id':'9dc92012-7393-4431-9c7a-47c947d93bde','asset_id':'a85caa78-d1cf-55b4-b935-85bc998768cd',
 'seed':2412401,'generation_cost':25,'source_sha256':hashlib.sha256((OUT/'source/pixellab-shrine.png').read_bytes()).hexdigest(),
 'layers':{'stone':'stone.png','emission':'emission.png','foliage':regions},
 'animation':{'update':'continuous runtime; preview sampled at24fps','glow_period_s':12,'vine_period_s':8,'firefly_groups':3,'fireflies_per_group':14,
 'firefly_art':'existing PixelLab blightwood_lights firefly_atlas, reused','rays':'independent procedural additive shader'},
 'qc':{'reassembly_pixel_exact':True,'no_resampling':True,'emissive_pixels':int(mask.sum()),'transparent_border':True},
 'integration':'Separate optional builder landmark. Does not replace shelter or change map layout.'}
(OUT/'shrine.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest['qc']|{'foliage':regions}))
