"""Read-only mathematical reproduction of PR245's documented 7x7 junction fixture.
Port of raw_vertex_mat/vertex_mat/_bad_cells/resolve at 61b319f9. Not production code.
Stores explicit corner votes for an actual Godot before/after floor demonstration.
"""
from collections import Counter,defaultdict
from pathlib import Path
import json,itertools
from build_junction_kit import ROOT,MATERIALS
P={'grass':0,'temple':1,'ground':2,'dirt':3,'rock':4}
OFF=[(0,-18),(36,0),(-36,0),(0,18)]
CELLS=[(0,18),(-36,0),(36,0),(0,-18)]
FAR=[(36,36),(-36,36),(36,-36),(-36,-36),(72,18),(72,-18),(-72,18),(-72,-18)]
FAMILIES={'grass_dirt':('dirt','grass'),'grass_rock':('rock','grass'),'dirt_rock':('rock','dirt')}
def add(a,b):return (a[0]+b[0],a[1]+b[1])
own={((i+j)*36,(i-j)*18):('dirt' if i>=3 and j<3 else 'rock' if i>=3 and j>=4 else 'grass') for i in range(7) for j in range(7)}
def raw(v):
 count=Counter(own[add(v,c)] for c in CELLS if add(v,c) in own)
 if len(count)<=1:return next(iter(count),'')
 far=Counter(own[add(v,c)] for c in FAR if add(v,c) in own)
 return min(count,key=lambda m:(count[m],far[m],-P[m]))
def bad(v,cand):
 n=0
 for c in CELLS:
  cell=add(v,c)
  if cell not in own:continue
  present={cand if add(cell,o)==v else raw(add(cell,o)) for o in OFF}-{''}
  n+=len(present)>2
 return n
def vote(v):
 original=raw(v);owners=list(dict.fromkeys(own[add(v,c)] for c in CELLS if add(v,c) in own))
 if len(owners)<3:return original
 best=original;score=bad(v,best)
 for candidate in owners:
  if candidate==original or score==0:continue
  value=bad(v,candidate)
  if value<score:best=candidate;score=value
 return best
def resolve(owner,corners):
 present=sorted(set(corners)-{''},key=lambda m:(m!=owner,-P[m]))
 if len(present)==1:return [present[0]]*4
 lead,partner=present[:2]
 return [m if m in [lead,partner] else lead for m in corners]
def tile(sig):
 if len(set(sig))==3:return 'junction_'+'_'.join(str(MATERIALS.index(m)) for m in sig)
 for fid,(zero,one) in FAMILIES.items():
  if set(sig)<=set([zero,one]):
   mask=sum(b for b,m in zip([8,4,2,1],sig) if m==one)
   return f'{fid}_{mask:02d}_a'
 raise ValueError(sig)
def seams(records,key):
 votes=defaultdict(set)
 for r in records:
  for o,m in zip(OFF,r[key]):votes[add(tuple(r['cell']),o)].add(m)
 return [list(v) for v,m in votes.items() if len(m)>1]
records=[]
for cell,owner in own.items():
 desired=[vote(add(cell,o)) for o in OFF];before=resolve(owner,desired)
 records.append({'cell':list(cell),'owner':owner,'before_corners':before,'after_corners':desired,'before_id':tile(before),'after_id':tile(desired)})
result={'source_pr':245,'source_head':'61b319f91a40cba144e4ece738f3e7a67c47fb4c','method':'read-only Python port of PR245 junction test, final vertex vote and fallback; Godot renders IDs without changing auto-tiling',
 'before_seam_vertices':seams(records,'before_corners'),'after_seam_vertices':seams(records,'after_corners'),'cells':records}
assert len(result['before_seam_vertices'])==2,result['before_seam_vertices']
assert not result['after_seam_vertices']
out=ROOT/'assets/environment/blightwood/terrain_junctions/pr245-fixture.json'
out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print({'before':result['before_seam_vertices'],'after':result['after_seam_vertices'],'cells':len(records)})
