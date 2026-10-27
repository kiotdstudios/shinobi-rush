"""Curate existing approved poses, without redrawing/rescaling production characters."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/visuals/movement-transitions'
DOC.mkdir(parents=True, exist_ok=True)
timings = {'start':100, 'stop':130, 'pivot':120}
audit = {}
for who, filename in [('player','player_128.manifest.json'),('bandit','bandit_128.art.json')]:
    path = ROOT/'assets/characters'/who/filename
    manifest = json.loads(path.read_text())
    animations = manifest['animations']
    audit[who] = {}
    for gait in ['run','sprint']:
        # Contact -> transfer -> push-off; stop returns to the exact idle origin.
        sources = {
            'start': [('idle',0),('run',1),('run',2)] if gait=='run' else [('run',1),('sprint',2),('sprint',3)],
            'stop': [(gait,2),('run',1),('idle',0)],
            'pivot': [(gait,0),(gait,1),(gait,2)],
        }
        for kind, poses in sources.items():
            aid = 'move_'+kind+('_sprint' if gait=='sprint' else '')
            definition = {'fps':3000/timings[kind], 'loop':False, 'foot_anchor':manifest['foot_anchor'],
                          'source_policy':'curated approved poses; no resampling, mirroring or sprite rotation',
                          'duration_ms':timings[kind], 'frames':{}}
            rows = Image.new('RGB',(128*3,148*8),(27,34,38))
            draw = ImageDraw.Draw(rows)
            records = []
            for y,direction in enumerate(manifest['directions']):
                paths = [animations[action]['frames'][direction][index] for action,index in poses]
                definition['frames'][direction] = paths
                hashes=[]
                for x,relative in enumerate(paths):
                    full=path.parent/relative
                    im=Image.open(full)
                    assert im.size==(128,128) and im.mode=='RGBA'
                    assert im.getbbox() and not (im.getbbox()[0]==0 or im.getbbox()[2]==128)
                    rows.paste(im,(x*128,y*148),im)
                    draw.text((x*128,y*148+128),f'{direction} {kind} {x+1}',fill='white')
                    hashes.append(hashlib.sha256(full.read_bytes()).hexdigest())
                assert len(set(hashes))==3,(who,aid,direction,'duplicate pose')
                records.append({'direction':direction,'paths':paths,'sha256':hashes})
            animations[aid]=definition
            rows.save(DOC/f'{who}-{aid}.png')
            audit[who][aid]={'duration_ms':timings[kind],'frames':records}
    path.write_text(json.dumps(manifest,indent=2)+'\n')
(DOC/'pose-inventory.json').write_text(json.dumps(audit,indent=2)+'\n')
print('PASS: 2 actors x 6 gait/action clips x 8 directions x 3 unique approved RGBA poses; no new texture memory')

