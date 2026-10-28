"""PR247: two missing pairs and a six-pattern reusable three-material compositor.
No original tiles, map, or Aki auto-blending code is modified.
"""
from pathlib import Path
import itertools, json, hashlib, re
import numpy as np
from PIL import Image, ImageDraw
import build_remaining_transitions as old

ROOT=old.ROOT
BASE=ROOT/'assets/environment/blightwood/terrain_junctions'
DOC=ROOT/'docs/visuals/terrain-junctions'
MATERIALS=['grass','ground','dirt','temple','rock']
PAIRS=[('path_temple','Ground to temple','temple','ground'),('path_rock','Ground to rock','rock','ground')]
BITS=[8,4,2,1]
def write(arr,path):
 path.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(arr).save(path)
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def res(path):return 'res://'+path.relative_to(ROOT).as_posix()
def pattern(sig):
 unique=[];out=[]
 for value in sig:
  if value not in unique:unique.append(value)
  out.append(unique.index(value))
 return ''.join(map(str,out)),unique
def owners(sig):
 # Bilinear corner fields retain narrow wedges; edge protocol overrides two pixels.
 weights=np.stack([(1-old.a)*(1-old.b),old.a*(1-old.b),(1-old.a)*old.b,old.a*old.b])
 vals=np.stack([sum(weights[i] for i in range(4) if sig[i]==s) for s in range(3)])
 # No blended colours. Small interior-only perturbation, common to every material.
 env=np.maximum(0,16*old.a*old.b*(1-old.a)*(1-old.b))
 for s in range(3):vals[s]+=env*(np.sin(old.x*.37+old.y*.73+s*2.1)*.035)
 return vals.argmax(axis=0)
def composite(sig,mats):
 key,slots=pattern(sig);indices=list(map(int,key));owner=owners(indices)
 out=np.zeros((36,72,4),dtype=np.uint8)
 for i,name in enumerate(slots):out[owner==i]=mats[name][owner==i]
 for side,(xs,ys,first,last,inward) in old.EDGES.items():
  names=[sig[BITS.index(first)],sig[BITS.index(last)]]
  colors=np.where((np.arange(36)<18)[:,None],old.edge_colors(mats[names[0]],side),old.edge_colors(mats[names[1]],side))
  for off in range(2):
   yy=np.clip(ys+inward*off,0,35);valid=old.inside[yy,xs]
   out[yy[valid],xs[valid]]=colors[valid]
 out[old.inside,3]=255;out[~old.inside]=0
 return out
def build():
 BASE.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 mats={n:old.load_material('path' if n=='ground' else n) for n in MATERIALS}
 manifest={'schema':'shinobi_terrain_junctions_v1','canvas':[72,36],'anchor':[36,18],
 'corner_order':['top','right','left','bottom'],'corner_bits':dict(zip(['top','right','left','bottom'],BITS)),
 'draw_order':'replace the floor cell; Ground z=-1, below actors; never overlay another opaque floor',
 'occupancy':'exactly one opaque pixel owner inside diamond, transparent outside; no collision',
 'placement':'Aki resolves all shared corner materials once, then selects exact signature; manual IDs stay locked',
 'edge_compatibility':{'ne':['top','right'],'sw':['left','bottom'],'nw':['left','top'],'se':['bottom','right'],
 'registered_border_pixels':2,'exact_rgb_protocol':'PR240 opposite edges share source-pixel signature; all variants agree',
 'legacy_path_dirt':'PR230 has its original texture edge sampling; corner polarity matches, exact RGB protocol is not claimed'},
 'unsupported':'four distinct materials in a single diamond; water; elevation. Four-way intersections with only three materials are covered.',
 'sources':{n:{'path':old.SOURCES['path' if n=='ground' else n],'sha256':digest(ROOT/old.SOURCES['path' if n=='ground' else n])} for n in MATERIALS},
 'pairs':[],'junctions':[],'patterns':[]}
 catalog=[];categories=[];arrays={};sig_by_id={};seams=0
 def register(name,label,arr,entry):
  target=BASE/'tiles'/f'{name}.png';write(arr,target)
  entry.update(id=name,path=res(target),sha256=digest(target));arrays[name]=arr
  ui_label=f"Mask {entry['mask']:02d} {chr(65+entry['variation'])}" if 'mask' in entry else '/'.join(s[:3].title() for s in entry['corners'])
  catalog.append(f'\t"{name}": {{"label": "{ui_label}", "kind": "ground", "group": "{label}", "dir": "res://assets/environment/blightwood/terrain_junctions/tiles/"}},')
 for family,label,zero,one in PAIRS:
  entries=[];tiles={}
  for mask in range(16):
   for v in range(1 if mask in (0,15) else 3):
    arr=old.compose(mats[zero],mats[one],mask,v);name=f'{family}_{mask:02d}_{chr(97+v)}'
    entry={'mask':mask,'variation':v,'corners':[one if mask&b else zero for b in BITS]}
    register(name,label,arr,entry);entries.append(entry);tiles[mask,v]=arr;sig_by_id[name]=entry['corners']
  count=old.verify_seams(tiles);seams+=count
  assert len({e['sha256'] for e in entries})==44,family
  manifest['pairs'].append({'id':family,'zero':zero,'one':one,'tiles':entries,'compatible_seam_checks':count})
  categories.append([label,[e['id'] for e in entries]])
 # Only SIX source occupancy patterns. Permuting the 3 material slots gives all
 # 36 signatures per triple. Export lossless PNGs for existing builder compatibility.
 patterns=sorted({pattern(s)[0] for s in itertools.product(range(3),repeat=4) if len(set(s))==3})
 assert len(patterns)==6
 for key in patterns:
  sig=list(map(int,key));arr=composite(sig,{i:np.full((36,72,4),[255 if c==i else 0 for c in range(3)]+[255],dtype=np.uint8) for i in range(3)})
  target=BASE/'patterns'/f'{key}.png';write(arr,target)
  manifest['patterns'].append({'pattern':key,'path':res(target),'channels':['slot0','slot1','slot2'],'sha256':digest(target)})
 for triple in itertools.combinations(MATERIALS,3):
  entries=[];label='Junction '+' / '.join(triple)
  for sig in itertools.product(triple,repeat=4):
   if len(set(sig))!=3:continue
   key,slots=pattern(sig);name='junction_'+'_'.join(str(MATERIALS.index(s)) for s in sig)
   entry={'corners':list(sig),'pattern':key,'slots':slots,'orientation':'explicit top/right/left/bottom; no bitmap rotation'}
   register(name,label,composite(sig,mats),entry);entries.append(entry);sig_by_id[name]=list(sig)
  assert len({e['sha256'] for e in entries})==36,triple
  manifest['junctions'].append({'materials':list(triple),'tiles':entries})
  categories.append([label,[e['id'] for e in entries]])
 # Compare every compatible edge across ALL new pairs/junction signatures and
 # existing pair families (including old path/dirt). Interior styling may differ;
 # exact registered edge colours and occupancy must match, independent of order.
 for fam in old.FAMILIES:
  fid,_,z,o=fam;z='ground' if z=='path' else z;o='ground' if o=='path' else o
  for mask in range(16):
   name=f'old_{fid}_{mask}';arrays[name]=np.array(Image.open(old.BASE/'tiles'/f'{fid}_{mask:02d}_a.png').convert('RGBA'));sig_by_id[name]=[o if mask&b else z for b in BITS]
 checked=0
 for side,other,ai,bi in [('ne','sw',(0,1),(2,3)),('se','nw',(3,1),(2,0))]:
  groups={}
  for name,arr in arrays.items():
   sig=sig_by_id[name];key=tuple(sig[i] for i in bi);xs,ys,*_=old.EDGES[other]
   groups.setdefault(key,[]).append((name,arr[ys,xs]))
  for name,arr in arrays.items():
   sig=sig_by_id[name];key=tuple(sig[i] for i in ai);xs,ys,*_=old.EDGES[side]
   xo,yo,*_=old.EDGES[other];valid=old.inside[ys,xs]&old.inside[yo,xo]
   for other_name,edge in groups.get(key,[]):
    assert np.array_equal(arr[ys,xs][valid],edge[valid]),(name,other_name,side)
    checked+=1
 for name,arr in arrays.items():
  assert np.array_equal(arr[:,:,3],old.inside*255),name
  palette={tuple(c) for s in sig_by_id[name] for c in mats[s][old.inside,:3]}
  assert all(tuple(c) in palette for c in arr[old.inside,:3]),name
 for group in manifest['pairs']+manifest['junctions']:
  entries=group['tiles'];sheet=Image.new('RGBA',(576,((len(entries)+5)//6)*76),'#1a2d2f');pen=ImageDraw.Draw(sheet)
  for i,e in enumerate(entries):
   xx=(i%6)*96;yy=(i//6)*76;sheet.alpha_composite(Image.fromarray(arrays[e['id']]),(xx+12,yy+20))
   caption=f"{e['mask']:02d}{chr(65+e['variation'])}" if 'mask' in e else e['id'].replace('junction_','')
   pen.text((xx+4,yy+2),caption,fill='white')
  title=group.get('id','-'.join(group.get('materials',[])));sheet.save(DOC/(title+'-contact.png'))
 (BASE/'junctions.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 p=ROOT/'scripts/editor/placed_objects.gd';text=p.read_text(encoding='utf-8')
 text=re.sub(r'\n\t# BEGIN JUNCTION KIT.*?# END JUNCTION KIT\n','\n',text,flags=re.S)
 text=text.replace('const CATALOG := {','const CATALOG := {\n\t# BEGIN JUNCTION KIT\n'+'\n'.join(catalog)+'\n\t# END JUNCTION KIT')
 text=re.sub(r'\nconst JUNCTION_CATEGORIES := .*?\n','\n',text)
 text=text.replace('const CATEGORIES := ','const JUNCTION_CATEGORIES := '+json.dumps(categories)+'\nconst CATEGORIES := ',1)
 line=next(l for l in text.splitlines() if l.startswith('const CATEGORIES := '))
 if ' + JUNCTION_CATEGORIES' not in line:text=text.replace(line,line+' + JUNCTION_CATEGORIES')
 p.write_text(text,encoding='utf-8')
 result={'pair_tiles':88,'triples':10,'junction_tiles':360,'source_patterns':6,'exact_edge_checks':checked,'pair_checks':seams,'palette_and_alpha':True}
 (DOC/'asset-qa.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
if __name__=='__main__':build()
