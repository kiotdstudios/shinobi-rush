"""Validate actual GPU-rendered foliage frames; never redraws source art."""
from pathlib import Path
from PIL import Image, ImageChops
import json
ROOT=Path(__file__).resolve().parents[2]
frames=[Image.open(ROOT/f'build/vines-ferns/render/phase-{p:03d}.png').convert('RGB') for p in range(96)]
assert all(im.size==(768,160) for im in frames)
meta=json.loads((ROOT/'assets/environment/blightwood_foliage/foliage.art.json').read_text(encoding='utf-8'))
allowed={tuple(bytes.fromhex(c[1:])) for c in meta['palette']}|{(26,45,47)}
results=[]
for i,item in enumerate(meta['items']):
    crops=[im.crop((i*128,0,(i+1)*128,128)) for im in frames]
    assert all(set(c.get_flattened_data())<=allowed for c in crops),item['id']
    changes=max(sum(p!=(0,0,0) for p in ImageChops.difference(crops[0],c).get_flattened_data()) for c in crops[1:])
    y=item['anchor'][1]
    zone=(0,y,128,y+4) if item['hang'] else (0,y-4,128,y)
    pinned=all(ImageChops.difference(crops[0].crop(zone),c.crop(zone)).getbbox() is None for c in crops[1:])
    assert any(p!=(26,45,47) for p in crops[0].crop(zone).get_flattened_data()),item['id']
    assert changes>0 and pinned,item['id']
    results.append(dict(id=item['id'],changed_pixels=changes,root_pinned=pinned,palette_preserved=True,phases=96))
(ROOT/'docs/visuals/vines-ferns/render-validation.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print('PASS: all six rendered sprites visibly sway, roots stay pinned, exact palette across 96 phases')
