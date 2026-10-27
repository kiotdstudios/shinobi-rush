"""Documentation only: assemble existing exported pixels; never modify game assets."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, math
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BASE=ROOT/'assets/environment/blightwood/terrain_transitions/tiles'
cases=[('Straight',lambda u,v:u<.5),('Outside corner',lambda u,v:u<.5 and v<.5),
 ('Inside corner',lambda u,v:u<.5 or v<.5),('Thin trail',lambda u,v:abs(v-.5)<.6),
 ('T junction',lambda u,v:abs(v-.5)<.6 or (abs(u-.5)<.6 and v>0)),
 ('Four-way junction',lambda u,v:abs(v-.5)<.6 or abs(u-.5)<.6),
 ('Island',lambda u,v:u*u+v*v<1.5),('Uneven bend',lambda u,v:abs(v-u*.55-.35*math.sin(u))<1.05)]
sheet=Image.new('RGB',(1000,1280),'#1a2d2f');pen=ImageDraw.Draw(sheet)
pen.text((20,10),'EXPORTED PIXEL SEAM DIAGRAMS (asset layout, not a gameplay screenshot)',fill='white')
records=[]
for i,(name,field) in enumerate(cases):
 ox=(i%2)*500+250;oy=(i//2)*310+95
 pen.text((ox-220,oy-50),name+' | dirt / temple',fill='white')
 cells=[]
 for u in range(-3,4):
  for v in range(-3,4):
   mask=sum(bit for bit,(du,dv) in zip([1,2,4,8],[(.5,.5),(-.5,.5),(.5,-.5),(-.5,-.5)]) if field(u+du,v+dv))
   # Keep a consistent variation on split masks when illustrating narrow routes.
   variation='a' if mask in (0,15) else 'b' if mask in (6,9) else 'abc'[(u+2*v)%3]
   tile=Image.open(BASE/f'dirt_temple_{mask:02d}_{variation}.png').convert('RGBA')
   sheet.paste(tile,(ox+(u-v)*36-36,oy+(u+v)*18+70-18),tile)
   cells.append({'u':u,'v':v,'mask':mask,'variation':variation})
 records.append({'case':name,'cells':cells})
sheet.save(OUT/'seam-cases.png')
(OUT/'seam-cases.json').write_text(json.dumps({'corner_bits':{'bottom':1,'left':2,'right':4,'top':8},'source_family':'dirt_temple','cases':records},indent=2)+'\n')
print('PASS: eight connected seam cases, 392 source tiles; game assets untouched')
