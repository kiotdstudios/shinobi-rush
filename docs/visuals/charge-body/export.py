"""Process generated charge bodies, preserving fixed source scale and registering the feet."""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
DIRECTIONS=['S','SE','E','NE','N','NW','W','SW']
def clean(im):
 a=np.array(im.convert('RGBA'));r,g,b=[a[:,:,n].astype(float) for n in range(3)]
 bg=(r>g+35)&(b>g+35)&(r>b*.7)&(r<b*1.3)
 a[:,:,3]=np.where(bg,0,255);a[a[:,:,3]==0,:3]=0
 return Image.fromarray(a)
def process(character,direction):
 folder=ROOT/f'assets/characters/{character}/charge_body';p=folder/'source'/f'{direction}-loop.png'
 raw=Image.open(p);w,h=raw.size;out=[];records=[]
 for n in range(16):
  x,y=n%4,n//4;im=clean(raw.crop((round(x*w/4),round(y*h/4),round((x+1)*w/4),round((y+1)*h/4)))).resize((128,128),Image.Resampling.NEAREST)
  box=im.getbbox();assert box and min(box[:2])>0 and max(box[2:])<128,(character,direction,n,'source edge',box)
  # Use both sandals, not scarf width or one projected front foot, to find the root X.
  a=np.asarray(im)[:,:,3];yy,xx=np.where(a[max(0,box[3]-12):box[3]]>0);foot_mid=(int(xx.min())+int(xx.max())+1)/2
  dx=round(64-foot_mid);dy=116-box[3]
  assert box[0]+dx>=0 and box[2]+dx<=128 and box[1]+dy>=0
  frame=Image.new('RGBA',(128,128));frame.paste(im,(dx,dy));out.append(frame)
  records.append({'source_frame':n,'source_bbox':box,'registration':[dx,dy],'height':box[3]-box[1]})
 dest=folder/'frames'/direction;dest.mkdir(parents=True,exist_ok=True)
 for n,f in enumerate(out):f.save(dest/f'{n:03}.png')
 return out,{'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'unique':len({f.tobytes() for f in out}),'frames':records,'height_range':[min(r['height'] for r in records),max(r['height'] for r in records)]}
def main():
 skins={};qc={}
 for character in ['player','bandit']:
  skins[character]={}
  for direction in ['S','SE','E','NE','N']:
   if (ROOT/f'assets/characters/{character}/charge_body/source/{direction}-loop.png').exists():
    frames,meta=process(character,direction);skins[character][direction]=frames;qc[character+'-'+direction]=meta
  for dst,src in [('W','E'),('NW','NE'),('SW','SE')]:
   if src not in skins[character]:continue
   seq=[];dest=ROOT/f'assets/characters/{character}/charge_body/frames/{dst}';dest.mkdir(parents=True,exist_ok=True)
   for n,im in enumerate(skins[character][src]):
    f=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT);assert f.getbbox()[3]==116;f.save(dest/f'{n:03}.png');seq.append(f)
   skins[character][dst]=seq
 for c,dirs in skins.items():
  target=ROOT/f'assets/characters/{c}/charge_body/atlases';target.mkdir(exist_ok=True)
  for d,seq in dirs.items():
   atlas=Image.new('RGBA',(512,512))
   for n,f in enumerate(seq):atlas.paste(f,((n%4)*128,(n//4)*128))
   atlas.save(target/f'{d}.png')
 manifest={'schema':1,'status':'owner_requested_charge_body_review','frame_size':[128,128],'foot_anchor':[64,116],'fps':12,'default_review_speed':.5,'frame_count':16,'duration_ms':16000/12,'loop':True,'body_only':True,'fx_included':False,'production_bound':False,'directions':DIRECTIONS,'mirrors':{'W':'E','NW':'NE','SW':'SE'},'characters':{c:{d:[f'res://assets/characters/{c}/charge_body/frames/{d}/{n:03}.png' for n in range(16)] for d in dirs} for c,dirs in skins.items()}}
 (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(HERE/'qc.json').write_text(json.dumps(qc,indent=2)+'\n')
 for d in DIRECTIONS:
  if not all(d in skins[c] for c in skins):continue
  previews=[]
  for n in range(16):
   im=Image.new('RGBA',(640,360),'#233141');draw=ImageDraw.Draw(im);draw.text((20,14),f'CHARGE BODY | {d} | no aura',fill='white')
   for c,x in [('player',64),('bandit',320)]:
    draw.text((x+108,45),c.upper(),fill='white');im.alpha_composite(skins[c][d][n].resize((256,256),Image.Resampling.NEAREST),(x,72))
   previews.append(im.convert('RGB'))
  for speed,label in [(1,'normal'),(.5,'half-speed')]:
   holds=[round((n+1)*100/12/speed)*10-round(n*100/12/speed)*10 for n in range(16)]
   previews[0].save(HERE/f'{d}-{label}.gif',save_all=True,append_images=previews[1:],duration=holds,loop=0,disposal=2,optimize=False)
  previews[0].save(HERE/f'{d}-pose.png')
 contact=Image.new('RGB',(1280,360*4),'#233141')
 for i,d in enumerate(DIRECTIONS):
  p=HERE/f'{d}-pose.png'
  if p.exists():contact.paste(Image.open(p),((i%2)*640,(i//2)*360))
 contact.save(HERE/'directions-contact.png')
 print(json.dumps({k:{'unique':v['unique'],'height_range':v['height_range']} for k,v in qc.items()}))
if __name__=='__main__':main()
