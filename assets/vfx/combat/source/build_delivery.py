"""Export PixelLab's cropped game-pack clips onto stable effect canvases.

No scaling, alpha changes or invented animation frames. PixelLab strips terminal
blank frames; counts come from each clip, not the parent recipe's duration.
"""
from pathlib import Path
from PIL import Image
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
EFFECTS = {
    'sword_trail_light': ('light', '8fb6fc5b-ab01-494a-b20a-6738b3662d6f'),
    'sword_trail_heavy': ('heavy', '6af28e69-c08d-4c00-874a-1bfbac08853c'),
    'hit_spark': ('hit', 'b6950469-32c8-4584-8478-9b2165948349'),
}
manifest = {'schema': 1, 'id': 'combat_vfx_v1', 'frame_size': [128,128],
            'pivot': [64,64], 'index_base': 0, 'timing_status': 'visual_proposal_pending_aki',
            'effects': {}}
for name, (folder, effect_id) in EFFECTS.items():
    source = ROOT/'source'/folder
    meta = json.loads((source/'manifest.json').read_text())
    clip = next(c for c in meta['clips'] if c['name'] == 'whole')
    w,h = clip['frame']['w'], clip['frame']['h']
    dx,dy = clip['offset']['x'], clip['offset']['y']
    assert 0 <= 64+dx and 0 <= 64+dy and 64+dx+w <= 128 and 64+dy+h <= 128
    paths, hashes, seen = [], [], set()
    dest = ROOT/'frames'/name
    dest.mkdir(parents=True, exist_ok=True)
    for sheet in clip['sheets']:
        atlas = Image.open(source/sheet['file']).convert('RGBA')
        for j in range(sheet['frames']):
            x,y = (j%sheet['columns'])*w, (j//sheet['columns'])*h
            frame = atlas.crop((x,y,x+w,y+h))
            out = Image.new('RGBA',(128,128))
            out.paste(frame,(64+dx,64+dy))
            assert out.getbbox(), (name,j,'unexpected blank')
            assert set(out.getchannel('A').get_flattened_data()) <= {0,255}
            assert out.tobytes() not in seen, (name,j,'duplicate')
            seen.add(out.tobytes())
            path = dest/f'{sheet["first_frame"]+j:03}.png'
            out.save(path)
            paths.append(path.relative_to(ROOT).as_posix())
            hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
    assert len(paths) == clip['frames']
    manifest['effects'][name] = {'fps':meta['fps'],'frame_count':len(paths),
        'loop':False,'pivot':[64,64],'frames':paths,'sha256':hashes,
        'pixellab_effect_id':effect_id,'source_clip_offset':[dx,dy],
        'attachment':'sword_hand_socket' if 'trail' in name else 'world_contact_point',
        'trigger':'gameplay_contact_event','independent_of_player_sprite':True}
(ROOT/'combat_vfx.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS:', ', '.join(f'{k}: {v["frame_count"]} unique RGBA128 frames' for k,v in manifest['effects'].items()))
