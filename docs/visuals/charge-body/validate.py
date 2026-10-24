from pathlib import Path
from PIL import Image
import json,hashlib,numpy as np
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
m=json.loads((HERE/'manifest.json').read_text());q=json.loads((HERE/'qc.json').read_text());allhashes={};count=0
assert m['frame_size']==[128,128] and m['foot_anchor']==[64,116] and m['body_only'] and not m['fx_included']
for c,dirs in m['characters'].items():
 assert set(dirs)==set(m['directions'])
 for d,paths in dirs.items():
  assert len(paths)==16;hashes=[];soles=[]
  for path in paths:
   im=Image.open(ROOT/path.removeprefix('res://'));assert im.mode=='RGBA' and im.size==(128,128)
   a=np.asarray(im);assert set(np.unique(a[:,:,3]))=={0,255};box=im.getbbox();assert box[3]==116 and box[0]>0 and box[2]<128 and box[1]>0
   yy,xx=np.where(a[104:116,:,3]>0);assert abs((int(xx.min())+int(xx.max())+1)/2-64)<=.5
   hashes.append(hashlib.sha256(im.tobytes()).hexdigest());count+=1
  assert len(set(hashes))==16,(c,d,'duplicate keys');allhashes[c+'-'+d]=hashes
 for dst,src in m['mirrors'].items():
  for a,b in zip(dirs[dst],dirs[src]):
   mirror=Image.open(ROOT/b.removeprefix('res://')).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
   assert mirror.tobytes()==Image.open(ROOT/a.removeprefix('res://')).tobytes()
assert count==256
timing={}
for p in HERE.glob('*.gif'):
 im=Image.open(p);duration=0;assert im.n_frames==16
 for n in range(16):im.seek(n);duration+=im.info['duration']
 assert duration==(2670 if 'half-speed' in p.name else 1330),(p.name,duration)
 timing[p.name]=duration
result={'result':'PASS','frame_references':count,'native_size':[128,128],'foot_anchor':[64,116],'characters':list(m['characters']),'directions':m['directions'],'fps':12,'half_speed_fps':6,'all_keys_unique_per_heading':True,'western_mirrors_exact':True,'gif_timing_ms':timing,'within_clip_height_range':{k:v['height_range'] for k,v in q.items()},'visual_review_note':'Height includes view-dependent hair/ponytail and stance foreshortening; no per-frame resizing.'}
(HERE/'validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
