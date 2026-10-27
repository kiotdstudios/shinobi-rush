"""Read-only asset/map coverage audit. Writes review evidence, never game assets."""
from pathlib import Path
from collections import Counter
import hashlib, json, re
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
src = (ROOT/'scripts/arena/blightwood_map_data.gd').read_text()
rows = re.findall(r'"([gdscw ]+)"', src)
k0 = int(re.search(r'K_MIN := (-?\d+)', src)[1])
m0 = int(re.search(r'M_MIN := (-?\d+)', src)[1])
cells = {(k0+i, m0+r): ch for r,row in enumerate(rows) for i,ch in enumerate(row) if ch != ' '}
pairs = Counter()
examples = {}
for (k,m), a in cells.items():
    for dk,dm in [(1,1),(-1,1)]:  # each shared diamond edge counted once
        b = cells.get((k+dk,m+dm))
        if b and b != a:
            pair = ''.join(sorted([a,b])); pairs[pair] += 1
            examples.setdefault(pair, [[k*36,m*18],[(k+dk)*36,(m+dm)*18]])
path = json.loads((ROOT/'assets/environment/blightwood/path_dirt_transitions/path-dirt.art.json').read_text())
shore = json.loads((ROOT/'assets/environment/blightwood_shorelines/shorelines.art.json').read_text())
natural = json.loads((ROOT/'assets/environment/blightwood/brown_dirt_path/natural-path.json').read_text())
families = {f: sorted(t['mask'] for t in shore['tiles'] if t['family']==f) for f in shore['families']}
assert all(v == list(range(16)) for v in families.values())
assert len(path['tiles']) == 48
assert all(sorted(t['mask'] for t in path['tiles'] if t['variation']==v)==list(range(16)) for v in range(3))
yy,xx=np.mgrid[:36,:72]
diamond=abs(xx+.5-36)/36+abs(yy+.5-18)/18<1
for tile in path['tiles']:
    file=ROOT/tile['path'].removeprefix('res://')
    im=Image.open(file).convert('RGBA'); alpha=np.array(im)[:,:,3]
    assert im.size==(72,36) and np.array_equal(alpha,diamond*255), tile['id']
    assert hashlib.sha256(file.read_bytes()).hexdigest()==tile['sha256'], tile['id']
for tile in shore['tiles']:
    land=np.array(Image.open(ROOT/tile['land'].removeprefix('res://')).convert('RGBA'))[:,:,3].astype(int)
    water=np.array(Image.open(ROOT/tile['water_mask'].removeprefix('res://')).convert('RGBA'))[:,:,3].astype(int)
    assert land.shape==(36,72) and water.shape==(36,72),tile['id']
    assert set(np.unique(land))<={0,255} and set(np.unique(water))<={0,255},tile['id']
    assert np.array_equal(land+water,diamond*255),tile['id']
samples = [
 ('Grass', 'assets/environment/kosen_courtyard/grass/tiles/grass9_center.png'),
 ('Ground / paths', 'assets/environment/blightwood/ground_path/ground9_center.png'),
 ('Brown dirt (pure mask)', 'assets/environment/blightwood/path_dirt_transitions/tiles/path_dirt_15_a.png'),
 ('Temple stone', 'assets/environment/kosen_courtyard/floor_tiles/floor9_center.png'),
 ('Cliff / rocky land fill', 'assets/environment/blightwood_shorelines/land/rock_15.png'),
]
sheet = Image.new('RGB',(1100,580),'#1a2d2f'); draw=ImageDraw.Draw(sheet)
materials=[]
for i,(label,p) in enumerate(samples):
    file=ROOT/p; im=Image.open(file).convert('RGBA')
    x=20+(i%3)*360; y=20+(i//3)*280
    draw.text((x,y),label,fill='white'); draw.text((x,y+18),f'{im.width}x{im.height}',fill='#a6bca7')
    # Show floor diamonds only for padded grass, retain native pixels.
    floor=im.crop((20,66,92,102)) if im.size==(112,112) else im
    tile=floor.resize((288,144),Image.Resampling.NEAREST)
    sheet.paste(tile,(x,y+48),tile)
    materials.append({'name':label,'path':p,'size':im.size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
                      'opaque_colors':len({pixel for pixel in im.get_flattened_data() if pixel[3]})})
sheet.save(OUT/'existing-materials.png')
# Diagram of actual authored material cells, separate from a gameplay screenshot.
colors={'g':'#55745c','d':'#b6844a','s':'#7b8098','c':'#373d58','w':'#3f9ac3'}
board=Image.new('RGB',(1200,950),'#10191e'); pen=ImageDraw.Draw(board)
for (k,m),ch in cells.items():
    x,y=600+k*14,490+m*7
    pen.polygon([(x,y-7),(x+14,y),(x,y+7),(x-14,y)],fill=colors[ch])
pen.text((15,15),'AUTHORED MATERIAL DIAGRAM (not a gameplay render)',fill='white')
for i,(ch,label) in enumerate([('g','grass'),('d','ground IDs / natural brown presentation'),('s','temple stone'),('c','cliff rock fill'),('w','water')]):
    pen.text((15,35+i*18),f'{ch}: {label}',fill=colors[ch])
board.save(OUT/'authored-material-map.png')
def rgb_colors(p):
    return {pixel[:3] for pixel in Image.open(ROOT/p).convert('RGBA').get_flattened_data() if pixel[3]}
brown_colors=rgb_colors(samples[2][1])
bank_colors=rgb_colors('assets/environment/blightwood_shorelines/land/dirt_15.png')
out={'source_main':'3b0a4f60','map_sha256':hashlib.sha256(src.encode()).hexdigest(),
 'authored_cell_counts':dict(Counter(cells.values())), 'shared_edge_counts':dict(sorted(pairs.items())),
 'shared_edge_examples_world':examples,'count_scope':'authored base grid, before shoreline retiling, stair landing overwrite, props and natural-path presentation',
 'fresh_asset_checks':{'path_dirt_48_size_opaque_diamond_hashes':True,'shoreline_48_binary_land_water_exact_union':True},
 'shoreline_masks':families,'path_dirt_canonical':len(path['tiles']),
 'path_dirt_unique_images':len({t['sha256'] for t in path['tiles']}),
 'natural_atlas_entries':len(natural['entries']),
 'natural_entry_materials':dict(Counter(e['terrain'] for e in natural['entries'])),
 'shore_dirt_brown_palette_overlap':len(bank_colors & brown_colors),
 'shore_dirt_fill_colors':len(bank_colors),'brown_fill_colors':len(brown_colors),
 'shoreline_palette_sources':json.loads((ROOT/'assets/environment/blightwood_shorelines/source/palettes.json').read_text())['sampled_from'],
 'materials':materials}
(OUT/'coverage-data.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
