"""Deterministic alpha cleanup, protected edge completion, layer extraction and atlas registration.
All creative source pixels originate from PixelLab; no prop geometry is drawn here.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'assets/environment/blightwood_lights'
SRC=BASE/'source'
OUT=BASE/'props'
FX=ROOT/'assets/vfx/blightwood_lights'
DOC=Path(__file__).parent
PALETTE=json.loads((SRC/'palette.json').read_text())['palette']
RGB=np.array([[int(c[i:i+2],16) for i in (1,3,5)] for c in PALETTE],dtype=np.int32)
BLUE=[c for c in PALETTE if c in ['#203a57','#38547c','#476898','#5f82b5','#7699ca','#808eac','#99a7c2','#b9cbe2','#e2f2ff']]

def clean(im,palette=PALETTE):
 a=np.array(im.convert('RGBA'));alpha=a[:,:,3]>=128
 colors=np.array([[int(c[i:i+2],16) for i in (1,3,5)] for c in palette],dtype=np.int32)
 unique,inv=np.unique(a[:,:,:3].reshape(-1,3),axis=0,return_inverse=True)
 nearest=((unique[:,None,:].astype(np.int32)-colors[None,:,:])**2).sum(2).argmin(1)
 a[:,:,:3]=colors[nearest][inv].reshape(a.shape[:2]+(3,));a[:,:,3]=alpha*255;a[~alpha]=0
 return Image.fromarray(a)

def completed(name):
 raw=Image.open(SRC/f'{name}-raw.png').convert('RGBA')
 if name=='stone_brazier':return clean(raw)
 done=Image.open(SRC/f'{name}-complete.png').convert('RGBA')
 w,h=raw.size;assert done.size==(w+64,h+64)
 base=Image.new('RGBA',done.size);base.paste(raw,(32,32));mask=np.zeros((h+64,w+64),dtype=bool)
 a=np.array(raw)[:,:,3]>127
 # Accept only completion near genuinely clipped edges. Do not add new scenery to clear margins.
 for x in np.where(a[:2,:].any(0))[0]:mask[8:40,max(8,x+20):min(w+56,x+45)]=True
 for x in np.where(a[-2:,:].any(0))[0]:mask[h+24:h+56,max(8,x+20):min(w+56,x+45)]=True
 for y in np.where(a[:,:2].any(1))[0]:mask[max(8,y+20):min(h+56,y+45),8:40]=True
 for y in np.where(a[:,-2:].any(1))[0]:mask[max(8,y+20):min(h+56,y+45),w+24:w+56]=True
 b=np.array(base);b[mask]=np.array(done)[mask]
 return clean(Image.fromarray(b))

def glass(im,box):
 a=np.array(im);x0,y0,x1,y1=box
 keep=np.zeros(a.shape[:2],bool)
 rgb=a[:,:,:3].astype(int)
 keep[y0:y1,x0:x1]=(rgb[y0:y1,x0:x1,2]-rgb[y0:y1,x0:x1,0]>18)&(rgb[y0:y1,x0:x1,2]-rgb[y0:y1,x0:x1,1]>7)&(rgb[y0:y1,x0:x1,2]>115)
 a[~keep]=0
 return Image.fromarray(a)

def main():
 OUT.mkdir(exist_ok=True);FX.mkdir(exist_ok=True)
 specs=[
 ('wooden_post',[106,290],[179,149],[54,30],0.,[157,92,202,179],[179,92]),
 ('stone_pagoda',[120,235],[122,141],[84,42],0.,None,None),
 ('branch_lantern',[112,311],[197,184],[70,38],0.,[175,125,222,213],[197,125]),
 ('stone_brazier',[88,177],[88,54],[96,46],0.92,None,None),
 ('spirit_totem',[120,287],[120,119],[75,40],0.82,None,None)]
 records=[];contact=Image.new('RGBA',(1440,400),'#202b32');draw=ImageDraw.Draw(contact)
 for i,(name,foot,light,fp,scale,box,pivot) in enumerate(specs):
  im=completed(name);bbox=im.getbbox();assert bbox and min(bbox[0],bbox[1],im.width-bbox[2],im.height-bbox[3])>=4,(name,bbox)
  im.save(OUT/f'{name}-assembled.png');contact.alpha_composite(im,(i*288+(288-im.width)//2,360-foot[1]))
  draw.text((i*288+12,380),name,fill='#c9def0')
  body=im.copy();maskbox=box if box else ([101,120,145,165] if name=='stone_pagoda' else [0,0,0,0])
  lit=glass(im,maskbox);lit.save(OUT/f'{name}-glass.png')
  r={'id':name,'path':f'res://assets/environment/blightwood_lights/props/{name}.png','size':list(im.size),'foot_anchor':foot,'light_anchor':light,'footprint':fp,'flame_scale':scale,'glass':f'res://assets/environment/blightwood_lights/props/{name}-glass.png','light_radius':150 if scale else 130,'light_energy':1.25 if scale else 1.0,'halo_scale':1.5 if scale else .85,'fly_radius':[72,64]}
  if box:
   cut=im.crop(box);cut.save(OUT/f'{name}-pendant.png');lit.crop(box).save(OUT/f'{name}-pendant-glass.png')
   a=np.array(body);a[box[1]:box[3],box[0]:box[2]]=0;body=Image.fromarray(a)
   r['pendant']={'path':f'res://assets/environment/blightwood_lights/props/{name}-pendant.png','glass':f'res://assets/environment/blightwood_lights/props/{name}-pendant-glass.png','pivot':pivot,'offset':[box[0]-pivot[0],box[1]-pivot[1]],'crop':box}
   # Exact disassembly/reassembly in the rest pose, no painted or interpolated replacement pixels.
   check=body.copy();check.alpha_composite(cut,(box[0],box[1]));assert check.tobytes()==im.tobytes()
  body.save(OUT/f'{name}.png');r['sha256']=hashlib.sha256((OUT/f'{name}.png').read_bytes()).hexdigest();records.append(r)
 contact.convert('RGB').save(DOC/'fixture-contact.png')
 hashes={}
 for kind,n,cell,cols in [('flame',12,(128,160),4),('firefly',8,(32,32),4)]:
  atlas=Image.new('RGBA',(cell[0]*cols,cell[1]*((n+cols-1)//cols)));keys=[]
  for i in range(n):
   raw=clean(Image.open(SRC/f'{kind}-{i:02}.png'),BLUE)
   if kind=='flame':
    arr=np.array(raw);ys,xs=np.where(arr[:,:,3]>0);bottom=int(ys.max());tail=xs[ys>=bottom-3];x=int(np.median(tail))
    frame=Image.new('RGBA',cell);frame.paste(raw,(64-x,144-bottom));assert frame.getbbox()[1]>=4
   else:frame=raw;assert raw.size==cell
   keys.append(hashlib.sha256(frame.tobytes()).hexdigest());atlas.paste(frame,((i%cols)*cell[0],(i//cols)*cell[1]))
  assert len(set(keys))==n,(kind,'duplicate registered frames')
  atlas.save(FX/('spirit_flame_atlas.png' if kind=='flame' else 'firefly_atlas.png'))
  atlas.save(DOC/f'{kind}-contact.png');hashes[kind]=keys
 wing_atlas=Image.open(FX/'firefly_atlas.png').convert('RGBA')
 wing_sheet=Image.new('RGBA',(1024,560),'#17232c');wing_draw=ImageDraw.Draw(wing_sheet)
 for i in range(8):
  frame=wing_atlas.crop(((i%4)*32,(i//4)*32,(i%4+1)*32,(i//4+1)*32)).resize((256,256),Image.Resampling.NEAREST)
  wing_sheet.alpha_composite(frame,((i%4)*256,(i//4)*280))
  wing_draw.text(((i%4)*256+12,(i//4)*280+256),f'Wingbeat {i+1} - native32x32, nearest8x',fill='#c2d9ef')
 wing_sheet.convert('RGB').save(DOC/'firefly-contact.png')
 clean(Image.open(SRC/'firefly-00.png'),BLUE).save(FX/'firefly-icon.png')
 manifest={'schema':'shinobi_blightwood_lights_v1','status':'technical_validation','source_tool':'PixelLab Pro/Pixen/inpaint and animate_image','palette':PALETTE,'palette_sources':['owner concept palette','assets/environment/kosen_courtyard/grass/tiles/grass9_center.png'],'fixtures':records,'flame':{'path':'res://assets/vfx/blightwood_lights/spirit_flame_atlas.png','frames':12,'fps':12,'frame_size':[128,160],'anchor':[64,144],'columns':4,'rows':3,'unique_hashes':hashes['flame']},'firefly':{'path':'res://assets/vfx/blightwood_lights/firefly_atlas.png','frames':8,'fps':18,'frame_size':[32,32],'columns':4,'rows':2,'unique_hashes':hashes['firefly'],'per_fixture':12,'standalone_count':32,'flight':'independent continuous bounded multi-frequency paths and staggered bioluminescent pulses'},'source_endpoint_policy':'Pinned final key omitted from each atlas, preserving12and8unique frames.','body_animation':'Fixed rooted fixture; extracted hanging pendants move independently; emissive glass masks pulse independently.'}
 (BASE/'blightwood-lights.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (DOC/'validation.json').write_text(json.dumps({'fixtures':5,'palette_colors':len(PALETTE),'unique_flame_frames':12,'unique_firefly_frames':8,'lossless_pendant_reassembly':True,'transparent_margins':True},indent=2)+'\n')
 print('PASS five transparent fixtures, lossless extracted pendants,12unique spirit-flame poses and8unique firefly wingbeats')
if __name__=='__main__':main()
