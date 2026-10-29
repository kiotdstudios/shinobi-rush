"""Validate actual GPU-rendered foliage frames; never redraws source art."""
from pathlib import Path
from PIL import Image, ImageChops
import json,itertools
ROOT=Path(__file__).resolve().parents[2]
frames=[Image.open(ROOT/f'build/vines-ferns/render/phase-{p:03d}.png').convert('RGB') for p in range(96)]
assert all(im.size==(768,160) for im in frames)
meta=json.loads((ROOT/'assets/environment/blightwood_foliage/foliage.art.json').read_text(encoding='utf-8'))
source={tuple(bytes.fromhex(c[1:])) for c in meta['palette']}
results=[]
for i,item in enumerate(meta['items']):
    tint=tuple(bytes.fromhex(item.get('render_tint','#ffffff')[1:]))
    tolerance=0 if tint==(255,255,255) else 1
    centers={tuple(round(c[j]*tint[j]/255) for j in range(3)) for c in source}
    allowed={tuple(max(0,min(255,c[j]+d[j])) for j in range(3)) for c in centers for d in itertools.product(range(-tolerance,tolerance+1),repeat=3)}|{(26,45,47)}
    crops=[im.crop((i*128,0,(i+1)*128,128)) for im in frames]
    assert all(set(c.get_flattened_data())<=allowed for c in crops),item['id']
    changes=max(sum(p!=(0,0,0) for p in ImageChops.difference(crops[0],c).get_flattened_data()) for c in crops[1:])
    y=item['anchor'][1]
    zone=(0,y,128,y+4) if item['hang'] else (0,y-4,128,y)
    pinned=all(ImageChops.difference(crops[0].crop(zone),c.crop(zone)).getbbox() is None for c in crops[1:])
    assert any(p!=(26,45,47) for p in crops[0].crop(zone).get_flattened_data()),item['id']
    assert changes>0 and pinned,item['id']
    results.append(dict(id=item['id'],changed_pixels=changes,root_pinned=pinned,palette_preserved=True,render_tint=item.get("render_tint","#ffffff"),framebuffer_tolerance=tolerance,phases=96))
(ROOT/'docs/visuals/vines-ferns/render-validation.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print('PASS: all six rendered sprites visibly sway, roots stay pinned, requested palette tint (<=1 framebuffer rounding value), across 96 phases')
