from pathlib import Path
from PIL import Image
import hashlib,json,numpy as np,zipfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;ASSET=ROOT/'assets/vfx/chakra_charge_blue_v2'
m=json.loads((ASSET/'manifest.json').read_text());assert m['frame_count']==96 and m['ground_anchor']==[128,224] and not m['production_bound']
hashes=set();bounds=[]
for n,f in enumerate(m['frames']):
 p=ASSET/f['path'];im=Image.open(p);assert im.mode=='RGBA' and im.size==(256,256)
 assert hashlib.sha256(p.read_bytes()).hexdigest()==f['sha256'];a=np.asarray(im);assert set(np.unique(a[:,:,3]))=={0,255}
 box=im.getbbox();assert box is not None and min(box[:2])>0 and max(box[2:])<256
 visible=a[a[:,:,3]>0];assert not np.any((visible[:,0].astype(int)>visible[:,1].astype(int)+45)&(visible[:,0]>.7*visible[:,2])),'pink residue'
 hashes.add(im.tobytes());bounds.append(box)
assert len(hashes)==96
timing={}
for p in HERE.glob('*.gif'):
 g=Image.open(p);count=g.n_frames;duration=0
 for n in range(count):g.seek(n);duration+=g.info['duration']
 assert count==(64 if 'sustain' in p.name else 96)
 assert duration==(5330 if 'sustain' in p.name else 8000 if 'half-speed' in p.name else 4000),(p.name,duration)
 timing[p.name]={'frames':count,'duration_ms':duration}
with zipfile.ZipFile(HERE/'chakra-charge-blue-v2.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in [ASSET/'manifest.json',ASSET/'sheet.png',*sorted((ASSET/'frames').glob('*.png'))]:z.write(p,p.relative_to(ASSET))
 z.write(HERE/'README.md','README.md')
result={'result':'PASS','unique_frames':96,'size':[256,256],'ground_anchor':[128,224],'production_bound':False,'bounds':bounds,'gif_timing':timing,'original_reference_frames':9,'frame_count_multiplier':96/9,'quality_note':'Aesthetic detail multiplier is not measurable; owner review required.'}
(HERE/'validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='bounds'}))
