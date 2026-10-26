"""Only chroma-key, uniformly resample and extract generated mist shapes; no drawn sprite art."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, hashlib
ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'assets/environment/blightwood_mist'
DOC = ROOT/'docs/visuals/ground-mist'
DOC.mkdir(parents=True, exist_ok=True)
raw = Image.open(ART/'source/raw.png').convert('RGBA')
a = np.array(raw); rgb = a[:,:,:3].astype(int)
key = (rgb[:,:,0] > rgb[:,:,1]+40) & (rgb[:,:,2] > rgb[:,:,1]+40)
a[key] = 0
clean = Image.fromarray(a)
atlas = Image.new('RGBA', (512,512)); checks=[]; hashes=[]
for i in range(16):
    x,y=i%4,i//4
    cell = clean.crop((round(x*raw.width/4), round(y*raw.height/4), round((x+1)*raw.width/4), round((y+1)*raw.height/4)))
    cell = cell.resize((128,128), Image.Resampling.NEAREST)
    # Register the existing complete silhouette to the shared ground band, no per-frame scaling.
    bbox = cell.getbbox(); assert bbox
    patch = cell.crop(bbox)
    out = Image.new('RGBA',(128,128))
    out.paste(patch, (64-patch.width//2,64-patch.height//2))
    alpha=np.array(out)[:,:,3]
    assert not (alpha[0].any() or alpha[-1].any() or alpha[:,0].any() or alpha[:,-1].any())
    hashes.append(hashlib.sha256(out.tobytes()).hexdigest())
    checks.append({'variant':i,'bbox':out.getbbox(),'edge_contact':False})
    atlas.paste(out,(x*128,y*128))
assert len(set(hashes)) == 16
atlas.save(ART/'wisps.png')
bg=Image.new('RGBA',atlas.size,(26,45,47,255));bg.alpha_composite(atlas);bg.convert('RGB').save(DOC/'contact.png')
(DOC/'asset-qa.json').write_text(json.dumps({'unique_variants':16,'frame_size':[128,128],'checks':checks},indent=2)+'\n',encoding='utf-8')
(ART/'mist.art.json').write_text(json.dumps({'generator':'built-in image_gen','pixellab_used':False,'reason':'original low fog shape atlas with runtime drift; PixelLab API and configured balance reviewed','texture':'wisps.png','grid':[4,4],'cell_size':[128,128],'anchor':[64,74],'variants':16,'animation':'continuous 23–34.4 second independent drift envelopes, not sequential flipbook frames','max_alpha':0.20,'near_player_alpha_multiplier_min':0.08,'pool_capacity':48,'filter':'nearest','baked_ground':False},indent=2)+'\n',encoding='utf-8')
print('16 unique transparent contained variants; no drawn or interpolated art')
