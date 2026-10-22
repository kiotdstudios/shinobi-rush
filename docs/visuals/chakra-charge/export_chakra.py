from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[3]
GEN=Path(r'C:/Users/dielp/.codex/generated_images/01a14cf2-1e9a-78b0-86c6-1599694e3bc0')
BODY=ROOT/'assets/characters/player/chakra_charge';FX=ROOT/'assets/vfx/chakra_charge'
SOURCES={'body_S':'exec-aeca60d2-3c3e-4845-9522-a787a0a2fb6a.png','body_E':'exec-03b91fd1-e1e3-4dc8-9143-133fc3f891b9.png','body_N':'exec-bf4b7b1f-5504-4757-99df-ee057ac5a7c7.png','body_SE':'exec-a1c5b0b2-8479-44f0-a85a-632aae9cffd2.png','body_NE':'exec-713aa0de-79ce-440f-b0f5-23e560219e58.png','aura_a':'exec-5e7acd62-33a6-46a9-88e7-46f1ed867a9b.png','aura_b':'exec-193bc657-483b-413a-bea6-651147de22fb.png','aura_c':'exec-3c6164a3-94ed-47d3-ba81-5892bfe02280.png','wisps_a':'exec-1b2aa698-1f12-4389-91e6-607731226e09.png','wisps_b':'exec-b4f1bddc-f4c8-41fd-913e-7f90f509a503.png','ground':'exec-4d7ebff9-42c9-4cdd-8183-4e885529d5f6.png'}

def clean(im):
 a=np.asarray(im.convert('RGBA')).copy();r,g,b=a[:,:,0].astype(int),a[:,:,1].astype(int),a[:,:,2].astype(int)
 mask=(r>100)&(b>95)&(r>g*1.5)&(b>g*1.5)
 a[mask]=0;a[~mask,3]=255
 return Image.fromarray(a)

def raw_cells(key):
 base=BODY if key.startswith('body_') else FX
 path=base/'source'/f'{key}.png';path.parent.mkdir(parents=True,exist_ok=True)
 if key in SOURCES and (GEN/SOURCES[key]).exists():shutil.copyfile(GEN/SOURCES[key],path)
 if not path.exists():return []
 im=Image.open(path);out=[]
 cuts=[0,round(im.height/4),round(im.height/2),round(im.height*3/4),im.height]
 if not key.startswith('body_'):
  alpha=np.asarray(clean(im))[:,:,3];empty=np.sum(alpha>0,axis=1)==0
  for row in range(1,4):
   expected=im.height*row/4
   gaps=[];start=None
   for y in range(max(0,round(expected)-36),min(im.height,round(expected)+36)):
    if empty[y] and start is None:start=y
    if not empty[y] and start is not None:gaps.append((start,y));start=None
   if start is not None:gaps.append((start,min(im.height,round(expected)+36)))
   gap=max(gaps,key=lambda g:g[1]-g[0]);cuts[row]=(gap[0]+gap[1])//2
 for j in range(16):
  x,y=j%4,j//4;box=(round(x*im.width/4),cuts[y],round((x+1)*im.width/4),cuts[y+1]);out.append(clean(im.crop(box)))
 return out

def sheet(frames,path):
 w,h=frames[0].size;out=Image.new('RGBA',(4*w,((len(frames)+3)//4)*h));
 for i,f in enumerate(frames):out.paste(f,((i%4)*w,(i//4)*h))
 path.parent.mkdir(parents=True,exist_ok=True);out.save(path)

def main():
 qc={};body={}
 for direction in ['S','SE','E','NE','N']:
  cells=raw_cells('body_'+direction)
  if not cells:continue
  frames=[]
  for i,c in enumerate([cells[j] for j in [0,1,2,3,4,12,13,15]]):
   a=np.asarray(c);ys,xs=np.where(a[:,:,3]>0);assert len(xs)>100
   # One fixed source-to-game scale, translation only; never bbox-fit individual poses.
   sc=.48;small=c.resize((round(c.width*sc),round(c.height*sc)),Image.Resampling.NEAREST)
   f=Image.new('RGBA',(128,128));dx=round(64-c.width*.5*sc);dy=116-small.getbbox()[3]
   f.paste(small,(dx,dy));assert f.getbbox() and f.getbbox()[3]==116
   if f.getbbox()[0]<2 or f.getbbox()[2]>126:raise ValueError('body crop '+direction+str(i))
   path=BODY/'frames'/f'{direction}_{i:03}.png';path.parent.mkdir(parents=True,exist_ok=True);f.save(path);frames.append(f)
  body[direction]=[(BODY/'frames'/f'{direction}_{i:03}.png').relative_to(ROOT).as_posix() for i in range(8)]
  sheet(frames,BODY/f'{direction}.png');qc['body_'+direction]={'frames':8,'unique':len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}),'height_range':[min(f.getbbox()[3]-f.getbbox()[1] for f in frames),max(f.getbbox()[3]-f.getbbox()[1] for f in frames)]}
 for dst,src in [('W','E'),('NW','NE'),('SW','SE')]:
  if src not in body:continue
  frames=[]
  for i in range(8):
   raw=Image.open(BODY/'frames'/f'{src}_{i:03}.png');f=Image.new('RGBA',(128,128));f.paste(raw.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(1,0));f.save(BODY/'frames'/f'{dst}_{i:03}.png');frames.append(f)
  body[dst]=[(BODY/'frames'/f'{dst}_{i:03}.png').relative_to(ROOT).as_posix() for i in range(8)]
  sheet(frames,BODY/f'{dst}.png');qc['body_'+dst]={'frames':8,'mirrored_from':src}
 aura={k:raw_cells(k) for k in ['aura_a','aura_b','aura_c']}
 if all(aura.values()):
  cells=aura['aura_a'][:8]+aura['aura_b']+aura['aura_c']+aura['aura_a'][8:]
  frames=[]
  for c in cells:
   # Locate actual magenta gutters; translate to a fixed root, one uniform scale for all FX.
   sc=.70
   small=c.resize((round(c.width*sc),round(c.height*sc)),Image.Resampling.NEAREST)
   f=Image.new('RGBA',(256,256));f.paste(small,(round(128-c.width*.5*sc),230-small.getbbox()[3]));frames.append(f)
  sheet(frames,FX/'aura.png');qc['aura']={'frames':48,'unique':len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})}
 data={'schema':1,'fps':24,'default_speed':.5,'body_anchor':[64,116],'fx_anchor':[128,230],'body':body,'layers':{'aura':{'texture':'res://assets/vfx/chakra_charge/aura.png','frames':48,'columns':4,'frame_size':[256,256],'anchor':[128,230]}}}
 for kind,keys in [('wisps',['wisps_a','wisps_b']),('ground',['ground'])]:
  cells=[]
  for key in keys:cells+=raw_cells(key)
  if not cells:continue
  frames=[]
  for c in cells:
   sc=.70;sy=.35 if kind=='ground' else sc
   small=c.resize((round(c.width*sc),round(c.height*sy)),Image.Resampling.NEAREST)
   f=Image.new('RGBA',(256,256))
   # Ground ring anchored to its elliptical center; wisps use the shared aura floor.
   dy=128-round((small.getbbox()[1]+small.getbbox()[3])*.5) if kind=='ground' else 230-small.getbbox()[3]
   f.paste(small,(round(128-c.width*.5*sc),dy));frames.append(f)
  sheet(frames,FX/(kind+'.png'))
  data['layers'][kind]={'texture':'res://assets/vfx/chakra_charge/'+kind+'.png','frames':len(frames),'columns':4,'frame_size':[256,256],'anchor':[128,128] if kind=='ground' else [128,230]}
  qc[kind]={'frames':len(frames),'unique':len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})}
 data['mirrored_directions']={'W':'E','NW':'NE','SW':'SE'}
 data['combined_loop_phases']=96
 data['body_authored_frames_per_source_direction']=8
 data['base_color']='blue'
 data['processing']={'filter':'nearest','body_scale':.48,'fx_scale':.70,'ground_y_scale':.35,'ground_projection':'one shared overhead ellipse correction; no per-frame fit','source_body_keys':[0,1,2,3,4,12,13,15]}
 provenance={}
 for key,filename in SOURCES.items():
  source=(BODY if key.startswith('body_') else FX)/'source'/(key+'.png')
  provenance[key]={'tool':'builtin image_gen','receipt':filename,'source':source.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
 (ROOT/'docs/visuals/chakra-charge/provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
 for direction in body:
  frames=[Image.open(ROOT/path) for path in body[direction]]
  assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==8
  for f in frames:
   box=f.getbbox();assert box and box[3]==116 and box[0]>=2 and box[2]<=126
   assert set(np.unique(np.asarray(f)[:,:,3])) <= {0,255}
  qc['body_'+direction].update({'unique':8,'fixed_sole_y':116,'binary_alpha':True})
 # Inspect every exported frame, including mirrored directions. No clipped FX or soft alpha.
 for kind in ['aura','wisps','ground']:
  atlas=Image.open(FX/(kind+'.png'))
  for i in range(qc[kind]['frames']):
   f=atlas.crop(((i%4)*256,(i//4)*256,(i%4+1)*256,(i//4+1)*256))
   box=f.getbbox();assert box and min(box[:2])>=2 and max(box[2:])<=254,(kind,i,box)
   assert set(np.unique(np.asarray(f)[:,:,3])) <= {0,255}
  assert qc[kind]['frames']==qc[kind]['unique']
  qc[kind]['edge_contacts']=0
  qc[kind]['binary_alpha']=True
 (BODY/'chakra-charge.art.json').write_text(json.dumps(data,indent=2)+'\n');(ROOT/'docs/visuals/chakra-charge/asset-qc.json').write_text(json.dumps(qc,indent=2)+'\n')
 print(json.dumps(qc))
if __name__=='__main__':main()
