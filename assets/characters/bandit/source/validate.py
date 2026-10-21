"""Check shipped art, source preservation, timings and review exports."""
from pathlib import Path
from PIL import Image
import json,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'bandit_128.art.json').read_text())
assert m['frame_size']==[128,128] and m['foot_anchor']==[64,116]
assert m['directions']==['S','SE','E','NE','N','NW','W','SW']
qc=json.loads((ROOT/'source/export_qc.json').read_text());assert not qc['pending'],qc['pending']
count=0
for action,a in m['animations'].items():
 assert set(a['frames'])==set(m['directions'])
 assert a['fps']*2==a['authored_fps'] and a['loop']
 for direction,paths in a['frames'].items():
  assert len(paths)==(4 if action=='idle' else 8),(action,direction,len(paths))
  hashes=[]
  for path in paths:
   im=Image.open(ROOT/path);assert im.size==(128,128) and im.mode=='RGBA'
   alpha=np.array(im)[:,:,3];assert set(np.unique(alpha))<={0,255}
   assert not np.any(alpha[[0,-1],:]) and not np.any(alpha[:,[0,-1]])
   hashes.append(hashlib.sha256(im.tobytes()).hexdigest());count+=1
  assert len(set(hashes))==len(hashes),(action,direction,'duplicate')
  for speed in ['normal','half']:
   gif=Image.open(ROOT/f'previews/{action}-{direction}-{speed}.gif');assert gif.n_frames==len(paths)
   duration=0
   for i in range(gif.n_frames):gif.seek(i);duration+=gif.info['duration']
   expected=len(paths)/a['authored_fps']*1000*(2 if speed=='half' else 1)
   assert abs(duration-expected)<=10,(action,direction,speed,duration,expected)
assert count==160,count
print(f'PASS: {count} RGBA frames, 24 clips, eight directions; fixed roots, unique frames, timings and 48 GIFs')
