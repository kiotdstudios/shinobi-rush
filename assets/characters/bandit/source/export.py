"""Lossless fixed-root bandit export; no rescaling, fabricated motion or per-frame recentering."""
from pathlib import Path
from PIL import Image
import zipfile,json,io,hashlib,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'source'
NAMES={'south':'S','south-east':'SE','east':'E','north-east':'NE','north':'N','north-west':'NW','west':'W','south-west':'SW'}
ACTIONS={'idle':'bandit_idle_v1','run':'bandit_run_v1','sprint':'bandit_sprint_v3'}
z=zipfile.ZipFile(SRC/'character.zip');data=json.loads(z.read('metadata.json'));state=next(s for s in data['states'] if s['character']['id']=='cc675e30-2723-4145-b03f-c0d245294305');frames=state['frames']
def read(path):return Image.open(io.BytesIO(z.read(path))).convert('RGBA')
anchors={};records=[];pending=[];rotations={}
for direction,label in NAMES.items():
 if direction not in frames.get('rotations',{}):continue
 im=read(frames['rotations'][direction]);a=np.array(im);box=im.getbbox();assert box
 yy,xx=np.nonzero((a[:,:,3]>0)&(np.indices(a.shape[:2])[0]>=box[3]-8))
 anchor=[int(round((xx.min()+xx.max()+1)/2)),box[3]]
 anchors[direction]={'native_size':list(im.size),'source_foot_anchor':anchor}
 out=Image.new('RGBA',(128,128));offset=(64-anchor[0],116-anchor[1]);out.paste(im,offset)
 assert np.count_nonzero(np.array(out)[:,:,3])==np.count_nonzero(a[:,:,3]),('rotation clips',direction)
 dest=ROOT/f'rotations/{label}.png';dest.parent.mkdir(exist_ok=True);out.save(dest);rotations[label]=str(dest.relative_to(ROOT)).replace('\\','/')
manifest={'schema':1,'id':'bandit_128','frame_size':[128,128],'foot_anchor':[64,116],'body_height_px':104,'directions':list(NAMES.values()),
 'status':'art_review','art_revision':'sprint-arms-v3','default_playback_speed':0.5,'shadow_baked':False,'logo_policy':'plain cloth headband; no symbols/logos/emblems','runtime_integrated':False,'animations':{}}
for action,source_name in ACTIONS.items():
 animation={'fps':4 if action=='idle' else 12,'authored_fps':8 if action=='idle' else 24,'loop':True,'status':'art_review','frames':{}}
 for direction,label in NAMES.items():
  paths=frames.get('animations',{}).get(source_name,{}).get(direction,[])
  # PixMiniMax returns a neutral reference + eight motion frames. Do not loop the reference.
  if action=='sprint' and len(paths)==9:paths=paths[1:]
  if not paths:pending.append([action,label,'not ready']);continue
  ims=[read(p) for p in paths];w,h=ims[0].size;assert all(im.size==(w,h) for im in ims)
  base=anchors[direction];mw,mh=base['native_size'];ax,ay=base['source_foot_anchor']
  dx=round(64-ax-(w-mw)/2);dy=round(116-ay-(h-mh)/2)
  # SE run's tall airborne key needs two pixels of headroom. Fixed across all eight frames.
  if action=='run' and label=='SE' and (w,h)==(164,164):dy+=2
  exported=[];hashes=[];issues=[]
  for i,im in enumerate(ims):
   raw=SRC/f'raw/{action}/{label}/{i:03}.png';raw.parent.mkdir(exist_ok=True,parents=True);im.save(raw)
   a=np.array(im)
   if not set(np.unique(a[:,:,3]))<={0,255}:issues.append([i,'nonbinary alpha']);continue
   out=Image.new('RGBA',(128,128));out.paste(im,(dx,dy));b=np.array(out)
   if np.count_nonzero(a[:,:,3])!=np.count_nonzero(b[:,:,3]):issues.append([i,'clips at fixed root']);continue
   if np.any(b[[0,-1],:,3]) or np.any(b[:,[0,-1],3]):issues.append([i,'touches border']);continue
   dest=ROOT/f'sprites/{action}/{label}_{i:03}.png';dest.parent.mkdir(exist_ok=True,parents=True);out.save(dest)
   exported.append(dest.relative_to(ROOT).as_posix());hashes.append(hashlib.sha256(out.tobytes()).hexdigest())
  if issues:pending.append([action,label,issues])
  elif len(set(hashes))!=len(hashes):pending.append([action,label,'duplicate source frames require explicit hold review'])
  else:animation['frames'][label]=exported
  records.append({'animation':action,'direction':label,'source_canvas':[w,h],'fixed_translation':[dx,dy],'frame_count':len(paths),'frames':exported,'pixel_sha256':hashes,'issues':issues})
 manifest['animations'][action]=animation
(ROOT/'bandit_128.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
(SRC/'export_qc.json').write_text(json.dumps({'rotations':anchors,'clips':records,'pending':pending},indent=2)+'\n')
print(json.dumps({'exported_clips':sum(len(a['frames']) for a in manifest['animations'].values()),'pending':pending},indent=2))
if '--partial' not in sys.argv:assert not pending and len(rotations)==8,'Incomplete/corrections required; see export_qc.json'
