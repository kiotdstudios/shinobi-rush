from pathlib import Path
from PIL import Image
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
base=ROOT/'assets/environment/kosen_courtyard/grass'
d=json.loads((base/'grass-nine.art.json').read_text(encoding='utf-8'))
palette={tuple(bytes.fromhex(c[1:])) for c in d['palette']}
assert len(d['tiles'])==9 and len(set(d['roles']))==9 and len(d['tall_accents'])==4
hashes=[]
for asset in d['tiles']+d['tall_accents']:
    p=ROOT/asset['path'].removeprefix('res://');im=Image.open(p).convert('RGBA')
    assert list(im.size)==asset['size']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==asset['sha256']
    colors={(r,g,b) for r,g,b,a in im.get_flattened_data() if a>0}
    assert colors<=palette,(p,colors-palette)
    assert {p[3] for p in im.get_flattened_data()}=={0,255}
    root_line=116 if im.height==160 else 67
    height=62 if im.height==160 else 30
    amplitude=4.5 if im.height==160 else .6
    for y in range(im.height):
        xs=[x for x in range(im.width) if im.getpixel((x,y))[3]>0]
        if not xs:continue
        weight=max(0,min(1,(root_line-y)/height))**2
        bound=1.59*amplitude*1.6*weight
        assert min(xs)-bound>=0 and max(xs)+bound<im.width,(p,y,bound)
    hashes.append(asset['sha256'])
assert len(set(hashes))==13
print('PASS13 unique RGBA assets;22-color approved palette only; native anchors; strong-gust swept bounds inside frame')
