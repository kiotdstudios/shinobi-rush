"""Fixed-scale extraction, chroma cleanup, palette mapping and atlas packaging."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'assets/environment/kosen_courtyard/grass'
COLORS=['#0a0b17','#121720','#1c202b','#1e241a','#242b1c','#283026','#30382c','#383d35','#3f4650','#3c4437','#454e3e','#4f5846','#5a6351','#68705c','#777e6b','#888f79','#9aa08b','#b0b59e','#c2c6b2','#4d535b','#586069','#677077']
palette=Image.new('P',(16,16));flat=[]
for c in COLORS:
    flat.extend(bytes.fromhex(c[1:]))
palette.putpalette(flat+flat[:3]*(256-len(COLORS)))

def cleanup(cell):
    raw=cell.convert('RGBA');px=[]
    for r,g,b,a in raw.get_flattened_data():
        magenta=r>g*1.45+25 and b>g*1.35+25
        px.append((r,g,b,0 if magenta or a<170 else 255))
    raw.putdata(px)
    alpha=raw.getchannel('A')
    clean=raw.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA')
    clean.putalpha(alpha)
    return clean

roles=['corner_top','edge_ne','corner_right','edge_nw','center','edge_se','corner_left','edge_sw','corner_bottom']
raw=Image.open(BASE/'source/nine-raw.png').convert('RGBA')
cw,ch=raw.width//3,raw.height//3
scale=72.0/(cw*0.90)
records=[];contact=Image.new('RGB',(672,672),'#28323b')
for i,role in enumerate(roles):
    cell=cleanup(raw.crop((i%3*cw,i//3*ch,(i%3+1)*cw,(i//3+1)*ch)))
    bbox=cell.getbbox();assert bbox
    size=(round(cw*scale),round(ch*scale))
    scaled=cell.resize(size,Image.Resampling.NEAREST)
    # Shared source scale; explicit front-vertex registration, no bbox fitting.
    offset=(56-size[0]//2,102-round((bbox[3]-1)*scale))
    frame=Image.new('RGBA',(112,112));frame.alpha_composite(scaled,offset)
    bbox_out=frame.getbbox();assert bbox_out and bbox_out[0]>=8 and bbox_out[2]<=104 and bbox_out[3]<=104
    path=BASE/'tiles'/f'grass9_{role}.png';frame.save(path)
    records.append(dict(role=role,path='res://'+path.relative_to(ROOT).as_posix(),size=[112,112],anchor=[56,84],
        logical_size=[72,36],source_cell=[i%3*cw,i//3*ch,cw,ch],shared_scale=scale,registration=list(offset),bbox=list(bbox_out),
        sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    big=frame.resize((224,224),Image.Resampling.NEAREST);contact.paste(big,(i%3*224,i//3*224),big)
    ImageDraw.Draw(contact).text((i%3*224+4,i//3*224+4),role,fill='white')
contact.save(ROOT/'docs/visuals/wind-grass-nine/grass-nine-contact.png')
accents=[]
tuft_path=BASE/'source/tall-raw.png'
if tuft_path.exists():
    tuft=Image.open(tuft_path).convert('RGBA');tw,th=tuft.width//2,tuft.height//2
    shared=92.0/tw
    tc=Image.new('RGB',(448,640),'#28323b')
    for i in range(4):
        cell=cleanup(tuft.crop((i%2*tw,i//2*th,(i%2+1)*tw,(i//2+1)*th)))
        bb=cell.getbbox();assert bb
        scaled=cell.resize((round(tw*shared),round(th*shared)),Image.Resampling.NEAREST)
        off=(56-scaled.width//2,136-round((bb[3]-1)*shared))
        frame=Image.new('RGBA',(112,160));frame.alpha_composite(scaled,off)
        box=frame.getbbox();assert box and box[0]>=9 and box[2]<=103 and box[1]>=8 and box[3]<=140,(i,box)
        path=BASE/'tiles'/f'grass_tall_{i:02}.png';frame.save(path)
        accents.append(dict(id=i,path='res://'+path.relative_to(ROOT).as_posix(),size=[112,160],anchor=[56,136],bbox=list(box),
            shared_scale=shared,registration=list(off),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        big=frame.resize((224,320),Image.Resampling.NEAREST);tc.paste(big,(i%2*224,i//2*320),big)
    tc.save(ROOT/'docs/visuals/wind-grass-nine/grass-tall-contact.png')
data=dict(schema='shinobi_wind_grass_nine_v1',logical_tile_size=[72,36],roles=roles,tiles=records,tall_accents=accents,
    palette=COLORS,palette_basis='exact Aki slate/moss shadows plus derived desaturated sage/straw light ramp; no neon greens',
    floor_reference_commit='661ba9e4efadfe875cc9cd5e87342c6662718248',source_tool='built-in image_gen; no paid PixelLab generation',
    wind=dict(phases=144,fps=24,cycle_seconds=6,technique='world-space gust wave with rooted nearest-sampled blade deformation',
              tall_fixed_from_y=116,ground_fixed_from_y=67,normal_strength=1.0,gust_strength=1.6),
    architecture='nine semantic terrain pieces plus four optional tall blade accents, separate ground/tall Y-sorted layers')
(BASE/'grass-nine.art.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
print(f'PASS nine112RGBA terrain tiles + {len(accents)} tall accents, fixed72x36 footprint, shared palette and registrations')
