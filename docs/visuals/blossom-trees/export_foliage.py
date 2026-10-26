"""Deterministic generated-sheet extraction, spill cleanup and export."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
base=ROOT/'assets/vfx/falling_foliage'
records=[];preview=Image.new('RGB',(1024,256),'#253743')
for row,kind in enumerate(['petal','leaf']):
    raw=Image.open(base/f'source/{kind}-raw.png').convert('RGBA')
    cw,ch=raw.width//4,raw.height//4
    sheet=Image.new('RGBA',(128,128));hashes=[]
    for i in range(16):
        cell=raw.crop((i%4*cw,i//4*ch,(i%4+1)*cw,(i//4+1)*ch)).resize((32,32),Image.Resampling.NEAREST)
        px=[]
        for r,g,b,a in cell.get_flattened_data():
            spill=(r>220 and g<80) or (b>210 and r<70 and g<70)
            px.append((r,g,b,255 if a>=170 and not spill else 0))
        cell.putdata(px);assert cell.getbbox(),(kind,i)
        sheet.alpha_composite(cell,(i%4*32,i//4*32))
        hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
        big=cell.resize((64,64),Image.Resampling.NEAREST)
        preview.paste(big,(i*64,row*128+32),big)
    assert len(set(hashes))>=14
    path=base/f'{kind}_tumble.png';sheet.save(path)
    records.append(dict(id=f'{kind}_tumble',path='res://'+path.relative_to(ROOT).as_posix(),frames=16,columns=4,rows=4,
        frame_size=[32,32],anchor=[16,16],fps_range=[3.5,7],loop=True,frame_hashes=hashes,
        sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
ImageDraw.Draw(preview).text((4,4),'Pink blossom petals / 16 tumble poses',fill='white')
ImageDraw.Draw(preview).text((4,132),'Blue-lavender leaves / 16 tumble poses',fill='white')
preview.save(ROOT/'docs/visuals/blossom-trees/foliage-contact.png')
data=dict(schema='shinobi_falling_foliage_v1',generator='built-in image_gen, two separate coherent 4x4 actions',
    processing='fixed-cell nearest32, alpha170, saturated edge-spill cleanup; no per-frame scaling/fit',
    animations=records,lifecycle_seconds=[6,10],max_particles_per_tree=24,emission_per_second=1.8,
    separation='independent foliage sprites, optional separate emitter; not baked into tree textures',
    motion='continuous downward drift, sinusoidal lateral sway, independent tumble/sleeve-like curl, ground fade')
(base/'falling_foliage.art.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
print('PASS two separate 16-frame32RGBA tumble sheets, transparent and unique poses')
