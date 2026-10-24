"""Technical extraction only: key magenta, shared nearest scale, root registration."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/environment/ashen_trees'
FX = ROOT / 'assets/vfx/ashen_foliage'
DOC = Path(__file__).parent
NAMES = ['sentinel', 'windbent', 'elder']

def cleaned(path):
    image = Image.open(path).convert('RGBA')
    pixels = np.array(image)
    r, g, b = [pixels[:, :, i].astype(int) for i in range(3)]
    key = (r > 20) & (b > 20) & (g < 115) & (r > g * 1.5) & (b > g * 1.5)
    pixels[:, :, 3] = np.where(key, 0, 255)
    pixels[key, :3] = 0
    return Image.fromarray(pixels)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    originals = [cleaned(OUT / f'source/{n}-raw.png') for n in NAMES]
    crops = [im.crop(im.getbbox()) for im in originals]
    scale = min(min(288 / im.width, 384 / im.height) for im in crops)
    records = []
    contact = Image.new('RGB', (960, 504), '#17212c')
    for index, (name, raw, crop) in enumerate(zip(NAMES, originals, crops)):
        size = tuple(round(v * scale) for v in crop.size)
        thumb = crop.resize(size, Image.Resampling.NEAREST)
        tile = Image.new('RGBA', (320, 448))
        tile.alpha_composite(thumb, ((320-size[0])//2, 416-size[1]))
        path = OUT / f'textures/{name}.png'
        tile.save(path)
        pixels = np.array(tile)
        hot = (pixels[:, :, 0] > pixels[:, :, 1] * 1.7) & (pixels[:, :, 0] > 65) & (pixels[:, :, 3] > 0)
        ys, xs = np.where((pixels[:, :, 3] > 0) & (np.indices(pixels.shape[:2])[0] < 280))
        # Real branch pixels provide births; particle root is the fixed tree origin.
        sampled = np.linspace(0, len(xs)-1, 24).astype(int)
        points = [[int(xs[i])-160, int(ys[i])-416] for i in sampled]
        assert len(points) == 24 and hot.sum() > 20
        assert tile.getbbox()[0] >= 12 and tile.getbbox()[2] <= 308
        assert tile.getbbox()[1] >= 16 and tile.getbbox()[3] <= 417
        contact.paste(tile, (index*320, 16), tile)
        ImageDraw.Draw(contact).text((index*320+16, 470), name.upper(), fill='#c5cbd2')
        records.append({'id': name, 'texture': 'res://' + path.relative_to(ROOT).as_posix(),
                        'size': [320,448], 'anchor': [160,416], 'bbox': list(tile.getbbox()),
                        'shared_scale': scale, 'source_bbox': list(raw.getbbox()),
                        'source_sha256': digest(OUT / f'source/{name}-raw.png'),
                        'sha256': digest(path), 'ash_emission': points,
                        'wind_phase': index*1.7, 'wind_strength': [0.9,1.05,0.82][index]})
    contact.save(DOC / 'contact-sheet.png')
    source = cleaned(FX / 'source/ash-raw.png')
    sheet = Image.new('RGBA',(128,128))
    hashes = []
    for i in range(16):
        # Shared source grid and scale; no per-frame fitting.
        box = (i%4*source.width//4, i//4*source.height//4,
               (i%4+1)*source.width//4, (i//4+1)*source.height//4)
        cell = source.crop(box).resize((32,32),Image.Resampling.NEAREST)
        assert cell.getbbox() and cell.getbbox()[0]>0 and cell.getbbox()[2]<32
        hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
        sheet.alpha_composite(cell,(i%4*32,i//4*32))
    assert len(set(hashes)) == 16
    sheet.save(FX / 'ash_tumble.png')
    sheet.resize((512,512),Image.Resampling.NEAREST).save(DOC / 'ash-contact.png')
    manifest = {'schema':'shinobi_ashen_trees_v1', 'status':'art_review', 'production_bound':False,
                'source_tool':'built-in image_gen, three separate tree images and one coherent16-pose ash sheet',
                'processing':'magenta key, fixed shared nearest scale, root registration; no painted tree/VFX substitutes',
                'render_filter':'nearest', 'trees':records,
                'wind':{'fps':24,'phases':96,'cycle_seconds':4,'fixed_from_y':346,'max_horizontal_px':5.5},
                'heat':{'cycle_seconds':4,'levels':8,'mask':'existing red source pixels in lower150px above roots'},
                'ash':{'texture':'res://assets/vfx/ashen_foliage/ash_tumble.png','frame_size':[32,32],
                       'frames':16,'fps':6,'life_seconds':8,'max_particles_per_tree':24,
                       'birth_points':'branch pixels from each tree; separate emitter and independent controls',
                       'frame_hashes':hashes,'sha256':digest(FX/'ash_tumble.png')}}
    (OUT / 'ashen-trees.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
    result={'result':'PASS','trees':3,'frame_size':[320,448],'fixed_anchor':[160,416],
            'shared_scale':scale,'transparent':True,'clear_wind_margins':True,'distinct_ash_poses':16}
    (DOC/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__ == '__main__':
    main()
