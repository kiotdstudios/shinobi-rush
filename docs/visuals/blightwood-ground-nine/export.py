"""Extract actual grass palette; register generated texture on the 72x36 grid."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/environment/blightwood/ground_path'
DOC = Path(__file__).parent
GRASS = ROOT / 'assets/environment/kosen_courtyard/grass/tiles'
ROLES = ['corner_top', 'edge_ne', 'corner_right', 'edge_nw', 'center',
         'edge_se', 'corner_left', 'edge_sw', 'corner_bottom']

def main():
    # Read the pixels rather than assuming the old manifest is still accurate.
    colors = set()
    inputs = []
    for path in sorted(GRASS.glob('*.png')):
        arr = np.array(Image.open(path).convert('RGBA'))
        colors.update(map(tuple, arr[arr[:, :, 3] > 0][:, :3].tolist()))
        inputs.append({'path': path.relative_to(ROOT).as_posix(),
                       'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    palette = np.array(sorted(colors), dtype=np.int32)
    assert len(palette) == 22, f'Grass palette changed: {len(palette)}'
    raw = Image.open(OUT / 'source/ground-raw.png').convert('RGB')
    surface = np.array(raw.resize((216, 216), Image.Resampling.NEAREST))
    distances = ((surface[:, :, None, :].astype(np.int32) - palette) ** 2).sum(3)
    surface = palette[distances.argmin(2)].astype(np.uint8)
    Image.fromarray(surface).save(OUT / 'source/palette-mapped-surface.png')
    atlas = Image.new('RGBA', (216, 108))
    patch = Image.new('RGBA', (216, 108))
    contact = Image.new('RGB', (720, 408), '#20272d')
    draw = ImageDraw.Draw(contact)
    entries = []
    masks = []
    for row in range(3):
        for col in range(3):
            idx = row * 3 + col
            # Array columns move SE, rows move SW in diamond-down tile space.
            # u follows down-right, v follows down-left.
            pixels = np.zeros((36, 72, 4), dtype=np.uint8)
            for y in range(36):
                for x in range(72):
                    dx, dy = (x + .5 - 36) / 36, (y + .5) / 18
                    u, v = (dx + dy) / 2, (dy - dx) / 2
                    if 0 <= u < 1 and 0 <= v < 1:
                        # Columns index u; rows index v.
                        pixels[y, x, :3] = surface[col * 72 + int(u * 72),
                                                       row * 72 + int(v * 72)]
                        pixels[y, x, 3] = 255
            tile = Image.fromarray(pixels)
            role = ROLES[idx]
            path = OUT / f'ground9_{role}.png'
            tile.save(path)
            masks.append(pixels[:, :, 3])
            atlas.paste(tile, (col * 72, row * 36))
            # These centers reproduce the nine-role order used by grass.
            px, py = 72 + (col - row) * 36, (row + col) * 18
            patch.alpha_composite(tile, (px, py))
            thumb = tile.resize((216, 108), Image.Resampling.NEAREST)
            contact.paste(thumb, (col * 240 + 12, row * 136 + 6), thumb)
            draw.text((col * 240 + 12, row * 136 + 116), role, fill='#c2c6b2')
            entries.append({'role': role, 'path': 'res://' + path.relative_to(ROOT).as_posix(),
                            'size': [72, 36], 'anchor': [36, 18],
                            'atlas_coords': [col, row],
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    assert all(np.array_equal(masks[0], mask) for mask in masks)
    assert len(set(t['sha256'] for t in entries)) == 9
    atlas.save(OUT / 'ground-nine-atlas.png')
    contact.save(DOC / 'contact-sheet.png')
    preview = Image.new('RGB', (864, 520), '#20272d')
    large = patch.resize((864, 432), Image.Resampling.NEAREST)
    preview.paste(large, (0, 8), large)
    pdraw = ImageDraw.Draw(preview)
    pdraw.text((16, 450), 'BLIGHTWOOD | assembled nine tiles | nearest 4x', fill='#c2c6b2')
    for i, rgb in enumerate(palette):
        pdraw.rectangle((16+i*37, 480, 48+i*37, 503), fill=tuple(rgb))
    preview.save(DOC / 'assembled-preview.png')
    manifest = {'schema': 'shinobi_ground_path_nine_v1', 'status': 'approved',
                'production_bound': True, 'logical_tile_size': [72, 36],
                'texture_filter': 'nearest', 'tiles': entries,
                'palette': ['#%02x%02x%02x' % tuple(rgb) for rgb in palette],
                'palette_sources': inputs,
                'source_tool': 'built-in image_gen; deterministic nearest extraction and exact grass palette mapping',
                'topology': 'nine-slice rectangular patch in diamond grid; same role order as grass',
                'seams': 'continuous source across assembled 3x3 patch; center repetitions are organic, not edge-identical',
                'runtime_integration': 'World Builder Ground / paths category; scripts/editor/placed_objects.gd'}
    (OUT / 'ground-nine.art.json').write_text(json.dumps(manifest, indent=2)+'\n')
    qc = {'png_count': 9, 'unique_tiles': 9, 'dimensions': [72, 36],
          'palette_colors': len(palette), 'exact_grass_palette': True,
          'consistent_diamond_coverage': True, 'opaque_pixels_per_tile': int((masks[0]>0).sum()),
          'alpha_values': [0, 255], 'result': 'PASS'}
    (DOC / 'validation.json').write_text(json.dumps(qc, indent=2)+'\n')
    print(json.dumps(qc))

if __name__ == '__main__':
    main()
