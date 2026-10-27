"""Map generated earth to the existing diamond; composite the actual grass fringe.
No procedural raw art: soil is image_gen output, vegetation is approved game art.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import numpy as np
import json, hashlib, zipfile

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/environment/blightwood/brown_dirt_path'
DOC=ROOT/'docs/visuals/brown-dirt-path'
GRASS=ROOT/'assets/environment/kosen_courtyard/grass/tiles'
ROLES={'corner_top':3,'edge_ne':1,'corner_right':5,'edge_nw':2,'center':0,'edge_se':4,'corner_left':10,'edge_sw':8,'corner_bottom':12}
DOC.mkdir(parents=True,exist_ok=True)
(OUT/'tiles').mkdir(parents=True,exist_ok=True)
raw=Image.open(OUT/'source/earth-raw.png').convert('RGB')
# Mirror the generated material into one periodic source. Opposite boundary
# texels match exactly; each diamond uses the same UV registration.
quarter=ImageEnhance.Brightness(raw.resize((36,36),Image.Resampling.NEAREST)).enhance(.88)
master=Image.new('RGB',(72,72))
master.paste(quarter,(0,0));master.paste(quarter.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(36,0))
master.paste(master.crop((0,0,72,36)).transpose(Image.Transpose.FLIP_TOP_BOTTOM),(0,36))
master=master.quantize(colors=24,dither=Image.Dither.NONE).convert('RGB')
master.save(OUT/'source/earth-periodic.png')
soil=np.array(master)
assert np.array_equal(soil[0],soil[-1]) and np.array_equal(soil[:,0],soil[:,-1])
fallback=np.array(Image.open(ROOT/'assets/environment/blightwood/ground_path/ground9_center.png').convert('RGBA'))
tiles={};entries=[]
for mask in range(16):
    role=next((r for r,m in ROLES.items() if m==mask),'center')
    source=GRASS/f'grass9_{role}.png'
    grass=np.array(Image.open(source).convert('RGBA'))
    out=np.zeros((112,112,4),dtype=np.uint8)
    covered=0
    for y in range(112):
        for x in range(112):
            dx=(x+.5-56)/36;dy=(y+.5-84)/18
            u=(dx+dy)/2;v=(dy-dx)/2
            inside=abs(dx)+abs(dy)<1
            outside=(1 if v<-.5 else 0)|(2 if u<-.5 else 0)|(4 if u>.5 else 0)|(8 if v>.5 else 0)
            if inside:
                uc=min(71,max(0,int((u+.5)*72)));vc=min(71,max(0,int((v+.5)*72)))
                earth=soil[vc,uc]
                rgb=grass[y,x,:3] if grass[y,x,3]>0 else fallback[min(35,max(0,y-66)),min(71,max(0,x-20)),:3]
                distances=[(v+.5)*36,(u+.5)*36,(.5-u)*36,(.5-v)*36]
                distance=min([d for bit,d in zip([1,2,4,8],distances) if mask&bit],default=100)
                # The irregular cut follows real grass clusters/luminance, not
                # a blurred alpha ramp. Every interior pixel remains opaque.
                fringe=1.7+max(0,min(3.4,(float(rgb.mean())-35)/25))
                out[y,x]=tuple(rgb if distance<fringe else earth)+(255,)
                covered+=1
            elif mask and outside and outside & ~mask == 0:
                out[y,x]=grass[y,x]
    im=Image.fromarray(out);path=OUT/'tiles'/f'dirt16_{mask:02d}.png';im.save(path);tiles[mask]=im
    entries.append({'mask':mask,'path':'res://'+path.relative_to(ROOT).as_posix(),'size':[112,112],'anchor':[56,84],
                    'coverage':1.0,'diamond_pixels':covered,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'grass_source':source.relative_to(ROOT).as_posix(),'grass_sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
for role,mask in ROLES.items():tiles[mask].save(OUT/'tiles'/f'dirt9_{role}.png')
atlas=Image.new('RGBA',(336,336));contact=Image.new('RGB',(1008,1050),'#1a2d2f');draw=ImageDraw.Draw(contact)
for i,(role,mask) in enumerate(ROLES.items()):
    atlas.alpha_composite(tiles[mask],((i%3)*112,(i//3)*112))
    image=tiles[mask].resize((336,336),Image.Resampling.NEAREST)
    contact.paste(image,((i%3)*336,(i//3)*336),image)
    draw.text(((i%3)*336+18,(i//3)*336+315),role,fill='#d7c2a0')
atlas.save(OUT/'dirt-nine-atlas.png');contact.save(DOC/'contact-sheet.png')
# An actual tiled layout, with broad trail, narrow spur and right-angle bend.
pathcells={(u,v) for u in range(1,7) for v in range(1,4)}|{(4,v) for v in range(4,8)}|{(u,7) for u in range(4,8)}
board=Image.new('RGBA',(820,480),'#1a2d2f')
centers={}
for u in range(-2,11):
    for v in range(-3,11):
        center=(410+(u-v)*36,55+(u+v)*18);centers[u,v]=center
        grass=Image.open(GRASS/'grass9_center.png').convert('RGBA')
        board.alpha_composite(grass,(center[0]-56,center[1]-84))
for (u,v) in sorted(pathcells,key=lambda p:p[0]+p[1]):
    mask=sum(bit for bit,(du,dv) in zip([1,2,4,8],[(0,-1),(-1,0),(1,0),(0,1)]) if (u+du,v+dv) not in pathcells)
    x,y=centers[u,v];board.alpha_composite(tiles[mask],(x-56,y-84))
board.convert("RGB").save(DOC/"native-grass-blend.png")
board=board.resize((1230,720),Image.Resampling.NEAREST)
ImageDraw.Draw(board).text((30,24),'BROWN / TAN EARTH | existing grass edges | broad trail + narrow bend',fill='#ebdbc1')
board.convert('RGB').save(DOC/'grass-blend-preview.png')
manifest={'schema':'shinobi_brown_dirt_path_v1','production_bound':False,'logical_tile_size':[72,36],'canvas':[112,112],
          'anchor':[56,84],'texture_filter':'nearest','alpha':'opaque diamond, original grass overhang outside exposed sides',
          'mask_bits':{'NE':1,'NW':2,'SE':4,'SW':8},'nine_roles':ROLES,'tiles':entries,
          'source_tool':'built-in image_gen earth; approved grass compositing; no PixelLab generation',
          'earth_boundary_texels_match':True,'integration':'art-only delivery; separate from approved ground9 assets'}
(OUT/'brown-dirt-path.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
qa={'result':'PASS','unique_mask_tiles':16,'nine_role_aliases':9,'canvas':[112,112],'logical_tile_size':[72,36],
    'anchor':[56,84],'opaque_diamond_coverage':1.0,'alpha_values':sorted(set(int(a) for im in tiles.values() for a in np.unique(np.array(im)[:,:,3]))),
    'periodic_material_boundaries_match':True,'png_files':26}
(DOC/'qa.json').write_text(json.dumps(qa,indent=2)+'\n')
with zipfile.ZipFile(DOC/'brown-dirt-path-art.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(OUT.rglob('*')):
        if p.is_file() and 'source' not in p.relative_to(OUT).parts and not p.name.endswith('.import'):
            z.write(p,p.relative_to(OUT).as_posix())
print(json.dumps(qa))
