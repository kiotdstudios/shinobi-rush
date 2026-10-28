"""Compose approved source pixels into missing flat-floor families; no raw art generation.
Never changes maps, auto-tiling, collision, or original material files.
"""
from pathlib import Path
import json, hashlib, re
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/environment/blightwood/terrain_transitions'
DOC=ROOT/'docs/visuals/terrain-transitions'
FAMILIES=[('grass_path','Grass to path','path','grass'),('grass_temple','Grass to temple','temple','grass'),
 ('dirt_temple','Dirt to temple','temple','dirt'),('grass_rock','Grass to rock','rock','grass'),
 ('dirt_rock','Dirt to rock','rock','dirt'),('temple_rock','Temple to rock','rock','temple'),
 ('grass_dirt','Grass to dirt','dirt','grass')]
SOURCES={'grass':'assets/environment/kosen_courtyard/grass/tiles/grass9_center.png',
 'path':'assets/environment/blightwood/ground_path/ground9_center.png',
 'dirt':'assets/environment/blightwood/path_dirt_transitions/tiles/path_dirt_15_a.png',
 'temple':'assets/environment/kosen_courtyard/floor_tiles/floor9_center.png',
 'rock':'assets/environment/blightwood_shorelines/land/rock_15.png'}
y,x=np.mgrid[:36,:72]; dx=(x+.5-36)/36;dy=(y+.5-18)/18
inside=abs(dx)+abs(dy)<1
a=(dx+dy)/2+.5;b=(dy-dx)/2+.5
ymin=np.argmax(inside,axis=0);ymax=35-np.argmax(inside[::-1],axis=0)
EDGES={'ne':(np.arange(36,72),ymin[36:],8,4,1),'sw':(np.arange(36),ymax[:36],2,1,-1),
 'nw':(np.arange(36),ymin[:36],2,8,1),'se':(np.arange(36,72),ymax[36:],1,4,-1)}

def load_material(name):
 im=Image.open(ROOT/SOURCES[name]).convert('RGBA')
 if im.size==(112,112):im=im.crop((20,66,92,102))
 arr=np.array(im)
 # Source raster outlines differ by a pixel. Extend nearest pixels from the SAME
 # material; olive fallback would contaminate stone borders with grass-colored dots.
 points=np.argwhere(arr[:,:,3]>0)
 for yy,xx in np.argwhere(inside&(arr[:,:,3]==0)):
  nearest=points[((points-[yy,xx])**2).sum(1).argmin()]
  arr[yy,xx]=arr[nearest[0],nearest[1]]
 arr[inside,3]=255;arr[~inside]=0
 return arr

def edge_colors(material, side):
 # One fixed source-pixel signature for each pair of opposite edges.
 xs,ys,*_=EDGES['ne' if side in ('ne','sw') else 'nw']
 colors=material[ys,xs].copy()
 common=material[18,36].copy()
 colors[:4]=common;colors[-4:]=common
 return colors

def compose(zero,one,mask,variant):
 cover=bool(mask&8)*(1-a)*(1-b)+bool(mask&4)*a*(1-b)+bool(mask&1)*a*b+bool(mask&2)*(1-a)*b
 envelope=np.maximum(0,16*a*b*(1-a)*(1-b))
 irregular=(np.sin(x*.37+y*.73+variant*2.1)*.035+np.sin(x*.17-y*.51+variant*.9)*.055)
 chosen=inside&(cover>.5+envelope*irregular)
 out=zero.copy();out[chosen]=one[chosen];out[~inside]=0
 # Register two native border pixels. All variants and compatible neighboring masks agree exactly.
 for side,(xs,ys,first,last,inward) in EDGES.items():
  which=np.where(np.arange(36)<18,bool(mask&first),bool(mask&last))
  colors=np.where(which[:,None],edge_colors(one,side),edge_colors(zero,side))
  for offset in range(2):
   yy=np.clip(ys+inward*offset,0,35);valid=inside[yy,xs]
   out[yy[valid],xs[valid]]=colors[valid]
 out[inside,3]=255
 return out

def verify_seams(tiles):
 count=0
 for (am,av),aa in tiles.items():
  for (bm,bv),bb in tiles.items():
   for side,other,ab,bc in [('ne','sw',(8,4),(2,1)),('se','nw',(1,4),(2,8))]:
    if all(bool(am&i)==bool(bm&j) for i,j in zip(ab,bc)):
     xa,ya,*_=EDGES[side];xb,yb,*_=EDGES[other]
     valid=inside[ya,xa]&inside[yb,xb]
     assert np.array_equal(aa[ya,xa][valid],bb[yb,xb][valid]),(am,av,bm,bv,side)
     count+=1
 return count

def save_png(arr,path):
 path.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(arr).save(path)

def build():
 DOC.mkdir(parents=True,exist_ok=True);BASE.mkdir(parents=True,exist_ok=True)
 materials={n:load_material(n) for n in SOURCES}
 manifest={'schema':'shinobi_remaining_transitions_v1','canvas':[72,36],'anchor':[36,18],
 'corner_bits':{'bottom':1,'left':2,'right':4,'top':8},'filter':'nearest','collision':'none',
 'scope':'flat material joins only; not cliff faces or automatic blending',
 'sources':{n:{'path':p,'sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for n,p in SOURCES.items()},'families':[]}
 catalog=[];categories=[];total_seams=0
 for family,label,zero,one in FAMILIES:
  tiles={};entries=[];ids=[];sheet=Image.new('RGB',(768,1120),'#1a2d2f');pen=ImageDraw.Draw(sheet)
  for mask in range(16):
   for v in range(1 if mask in (0,15) else 3):
    arr=compose(materials[zero],materials[one],mask,v);tiles[mask,v]=arr
    name=f'{family}_{mask:02d}_{chr(97+v)}';target=BASE/'tiles'/f'{name}.png';save_png(arr,target)
    assert np.array_equal(arr[:,:,3],inside*255)
    entry={'id':name,'mask':mask,'variation':v,'path':'res://'+target.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    entries.append(entry);ids.append(name)
    im=Image.fromarray(arr).resize((144,72),Image.Resampling.NEAREST)
    sx=(mask%4)*192;sy=(mask//4)*280
    if v==0:pen.text((sx+12,sy+2),f'Mask {mask:02d}'+(' (pure)' if mask in (0,15) else ''),fill='white')
    sheet.paste(im,(sx+12,sy+20+v*80),im)
    pen.text((sx+160,sy+45+v*80),chr(65+v),fill='white')
    catalog.append(f'\t"{name}": {{"label": "Mask {mask:02d} {chr(65+v)}", "kind": "ground", "group": "{label}", "dir": "res://assets/environment/blightwood/terrain_transitions/tiles/"}},')
  seams=verify_seams(tiles);total_seams+=seams
  palette={tuple(c) for mat in (materials[zero],materials[one]) for c in mat[inside,:3]}
  assert all(tuple(c) in palette for arr in tiles.values() for c in arr[inside,:3]),family
  unique=len({e['sha256'] for e in entries})
  assert unique==44,(family,unique)
  manifest['families'].append({'id':family,'label':label,'zero':zero,'one':one,'tiles':entries,'compatible_seam_checks':seams,'unique_images':unique})
  categories.append([label,ids]);sheet.save(DOC/f'{family}-contact.png')
  board=Image.new('RGBA',(1000,560),'#1a2d2f')
  def field(u,v):
   return ((u-1.7)/3.1)**2+((v-1.5)/2.2)**2<1 or abs(v-u-.5*np.sin(u*.8))<.7 or (u>4 and abs(v-2)<.7)
  for u in range(-4,10):
   for v in range(-4,10):
    mask=sum(bit for bit,(du,dv) in zip([1,2,4,8],[(.5,.5),(-.5,.5),(.5,-.5),(-.5,-.5)]) if field(u+du,v+dv))
    arr=tiles[mask,0 if mask in (0,15) else (u+2*v)%3]
    board.alpha_composite(Image.fromarray(arr),(500+(u-v)*36-36,80+(u+v)*18-18))
  board.convert('RGB').save(DOC/f'{family}-connected.png')
 # Brown banks: keep exact existing shoreline land alpha and water masks; replace land RGB only.
 bank_dir=ROOT/'assets/environment/blightwood/brown_shorelines';bank_entries=[];bank_ids=[]
 for mask in range(16):
  original=ROOT/f'assets/environment/blightwood_shorelines/land/dirt_{mask:02d}.png'
  alpha=np.array(Image.open(original).convert('RGBA'))[:,:,3]
  arr=materials['dirt'].copy();arr[:,:,3]=alpha;arr[alpha==0]=0
  target=bank_dir/'land'/f'brown_{mask:02d}.png';save_png(arr,target)
  water=ROOT/f'assets/environment/blightwood_shorelines/water_masks/dirt_{mask:02d}.png'
  mask_alpha=np.array(Image.open(water).convert('RGBA'))[:,:,3]
  assert np.array_equal(alpha.astype(int)+mask_alpha,inside*255)
  name=f'shore_brown_{mask:02d}';bank_ids.append(name)
  bank_entries.append({'id':name,'mask':mask,'land':'res://'+target.relative_to(ROOT).as_posix(),'water_mask':'res://'+water.relative_to(ROOT).as_posix()})
  # Thumbnail uses existing static water pixels only as an editor icon; runtime water stays animated.
  thumb=np.array(Image.open(ROOT/f'assets/environment/blightwood_shorelines/tiles/shore_dirt_{mask:02d}.png').convert('RGBA'))
  thumb[alpha>0]=arr[alpha>0];save_png(thumb,bank_dir/'tiles'/f'{name}.png')
  catalog.append(f'\t"{name}": {{"label": "Brown bank {mask:02d}", "kind": "ground", "group": "Brown banks", "dir": "res://assets/environment/blightwood/brown_shorelines/tiles/", "water_role": "center", "shore_family": "brown", "shore_mask": {mask}}},')
 categories.append(['Brown banks',bank_ids])
 (bank_dir/'brown-shore.art.json').write_text(json.dumps({'canvas':[72,36],'anchor':[36,18],'one':'brown land','zero':'existing animated water','tiles':bank_entries,'source':'existing dirt shoreline alpha; existing brown-soil RGB; no new water frames'},indent=2)+'\n')
 (BASE/'transitions.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
 # Generated additions are isolated from the existing catalog and category content.
 p=ROOT/'scripts/editor/placed_objects.gd';text=p.read_text(encoding='utf-8')
 text=re.sub(r'\n\t# BEGIN REMAINING TRANSITIONS.*?# END REMAINING TRANSITIONS\n','\n',text,flags=re.S)
 text=text.replace('const CATALOG := {','const CATALOG := {\n\t# BEGIN REMAINING TRANSITIONS\n'+'\n'.join(catalog)+'\n\t# END REMAINING TRANSITIONS')
 text=re.sub(r'\nconst TRANSITION_CATEGORIES := .*?\n', '\n',text)
 text=text.replace('const CATEGORIES := ', 'const TRANSITION_CATEGORIES := '+json.dumps(categories)+'\nconst CATEGORIES := ',1)
 # Append generated groups only once; existing category order/content retained byte-for-byte.
 line=next(l for l in text.splitlines() if l.startswith('const CATEGORIES := '))
 if ' + TRANSITION_CATEGORIES' not in line:text=text.replace(line,line+' + TRANSITION_CATEGORIES')
 p.write_text(text,encoding='utf-8')
 result={'families':7,'flat_tiles':308,'brown_bank_layers':16,'seam_checks':total_seams,'source_art_regenerated':False}
 (DOC/'asset-qa.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
if __name__=='__main__':build()
