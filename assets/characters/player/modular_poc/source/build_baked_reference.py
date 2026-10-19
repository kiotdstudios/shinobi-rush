"""Finish the one-direction baked comparison without scaling/recentering frames."""
from pathlib import Path
from PIL import Image
from collections import deque
import json,hashlib

ROOT=Path(__file__).resolve().parents[1]
specs={
 'light_attack_1':{'translation':[-2,-27],'patches':{},'generation':'combat-light-1-se-pilot-v3'},
 'light_attack_2':{'translation':[-14,-26],'patches':{1:'SE_light2_1.png'},'generation':'combat-light-2-se-v2'},
 'light_attack_3':{'translation':[-6,-30],'patches':{0:'SE_light3_0.png',1:'SE_light3_1.png',2:'SE_light3_2.png'},'generation':'combat-light-3-se-v2'}
}
out={'frame_size':[128,128],'foot_anchor':[64,116],'direction':'SE','fps_proposal':24,'default_review_speed':0.5,'timing_status':'pending_aki','clips':{}}
for action,s in specs.items():
 dest=ROOT/'baked_reference'/action;dest.mkdir(parents=True,exist_ok=True);paths=[];seen=set();removed=0
 for i in range(8):
  f=ROOT/'source'/'corrections'/s['patches'][i] if i in s['patches'] else ROOT/'source'/'raw'/action/f'{i}.png'
  im=Image.open(f).convert('RGBA');assert set(im.getchannel('A').get_flattened_data())<={0,255}
  # Delete only isolated, disconnected specks. Large detached shapes require review.
  alpha=im.getchannel('A');visited=set();parts=[]
  for y in range(im.height):
   for x in range(im.width):
    if (x,y) in visited or not alpha.getpixel((x,y)):continue
    q=deque([(x,y)]);visited.add((x,y));part=[]
    while q:
     px,py=q.popleft();part.append((px,py))
     for dx,dy in [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]:
      nx,ny=px+dx,py+dy
      if 0<=nx<im.width and 0<=ny<im.height and (nx,ny) not in visited and alpha.getpixel((nx,ny)):
       visited.add((nx,ny));q.append((nx,ny))
    parts.append(part)
  for part in sorted(parts,key=len,reverse=True)[1:]:
   assert len(part)<=8,(action,i,'significant detached shape',len(part))
   for pt in part:im.putpixel(pt,(0,0,0,0));removed+=1
  result=Image.new('RGBA',(128,128));result.paste(im,tuple(s['translation']))
  assert result.getchannel('A').histogram()[255]==im.getchannel('A').histogram()[255],(action,i,'clipped pixels')
  assert result.tobytes() not in seen,(action,i,'duplicate');seen.add(result.tobytes())
  target=dest/f'SE_{i:03}.png';result.save(target);paths.append(target.relative_to(ROOT).as_posix())
 out['clips'][action]={'frames':paths,'frame_count':8,'generation':s['generation'],'common_translation':s['translation'],'removed_isolated_pixels':removed,'sha256':[hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in paths]}
(ROOT/'source'/'baked_reference.json').write_text(json.dumps(out,indent=2)+'\n')
print('PASS:24 unique native128 RGBA baked comparison frames, no opaque-pixel clipping, fixed per-clip translations')
