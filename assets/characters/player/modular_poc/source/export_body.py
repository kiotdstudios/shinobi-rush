"""Restore reference placement after API padding changes, without rescaling poses.

Every translation is measured independently against original head AND feet;
both must agree. This restores the source coordinate origin, not bbox-centering.
"""
from pathlib import Path
from PIL import Image
from collections import deque
import json,hashlib

ROOT=Path(__file__).resolve().parents[1]
registration=json.loads((ROOT/'source/registration.json').read_text())
out=[]
for r in registration:
 action,i=r['animation'],r['frame'];assert r['head']['shift']==r['foot']['shift'],(action,i,'landmarks disagree');assert r['foot']['matched']>50
 source=ROOT/f'source/body_candidates/{action}/SE_{i:03}.png';im=Image.open(source).convert('RGBA');assert im.size==(128,128)
 assert set(im.getchannel('A').get_flattened_data())<={0,255}
 alpha=im.getchannel('A');seen=set();parts=[]
 for y in range(128):
  for x in range(128):
   if (x,y) in seen or not alpha.getpixel((x,y)):continue
   q=deque([(x,y)]);seen.add((x,y));part=[]
   while q:
    px,py=q.popleft();part.append((px,py))
    for dx,dy in [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]:
     nx,ny=px+dx,py+dy
     if 0<=nx<128 and 0<=ny<128 and (nx,ny) not in seen and alpha.getpixel((nx,ny)):
      seen.add((nx,ny));q.append((nx,ny))
   parts.append(part)
 removed=[]
 for part in sorted(parts,key=len,reverse=True)[1:]:
  assert len(part)<=32,(action,i,'significant detached shape',len(part))
  removed.append(len(part))
  for xy in part:im.putpixel(xy,(0,0,0,0))
 result=Image.new('RGBA',(128,128));result.paste(im,tuple(r['head']['shift']))
 assert result.getchannel('A').histogram()[255]==im.getchannel('A').histogram()[255],(action,i,'body clipping')
 dest=ROOT/'body'/action;dest.mkdir(parents=True,exist_ok=True);target=dest/f'SE_{i:03}.png';result.save(target)
 out.append({'animation':action,'frame_index':i,'body_frame':target.relative_to(ROOT).as_posix(),'body_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'padding_restoration':r['head']['shift'],'removed_detached_pixel_components':removed,'body_bounds':result.getbbox()})
(ROOT/'source/body_export.json').write_text(json.dumps(out,indent=2)+'\n')
print('PASS24 body frames restored to original head/foot placement, binary-alpha128RGBA, no body clipping')
