"""Deterministic cleanup, palette mapping and projection of generated bridge art.
No creative pixels are drawn here: all visible bridge materials come from raw PNGs.
"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[3]
A=ROOT/'assets/environment/blightwood_bridges'
D=Path(__file__).resolve().parent
S=A/'source'; M=A/'modules'; P=A/'prefabs'; L=A/'layers'
for p in (M,P,L):p.mkdir(exist_ok=True)
NN=Image.Resampling.NEAREST
# Palette is sampled from existing approved art, rather than invented colors.
refs=['assets/environment/blightwood_lights/props/wooden_post.png','assets/environment/kosen_courtyard/grass/tiles/grass9_center.png']
colors=[]
for ref in refs:
 im=Image.open(ROOT/ref).convert('RGBA'); arr=np.asarray(im); colors.extend(arr[arr[:,:,3]>127,:3].tolist())
palimage=Image.fromarray(np.array(colors,dtype=np.uint8).reshape(1,-1,3)).quantize(colors=40,method=Image.Quantize.MEDIANCUT)
pal=np.array(palimage.getpalette(),dtype=np.uint8).reshape(-1,3)[:40]

def clean(name):
 im=Image.open(S/(name+'-crop.png')).convert('RGBA'); a=np.array(im)
 bg=(a[:,:,0].astype(int)-a[:,:,1]>65)&(a[:,:,2].astype(int)-a[:,:,1]>65)
 a[bg]=0
 # Remove a detached fragment of the neighboring rope sprite in accessory crop.
 if name=='wood-rail':
  from collections import deque
  mask=a[:,:,3]>127; seen=np.zeros(mask.shape,bool); groups=[]
  for yy,xx in zip(*np.where(mask)):
   if seen[yy,xx]:continue
   queue=deque([(yy,xx)]); seen[yy,xx]=True; group=[]
   while queue:
    y,x=queue.popleft();group.append((y,x))
    for ny,nx in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
     if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx] and not seen[ny,nx]:
      seen[ny,nx]=True;queue.append((ny,nx))
   groups.append(group)
  keep=np.zeros(mask.shape,bool)
  for y,x in max(groups,key=len):keep[y,x]=True
  a[~keep]=0
 im=Image.fromarray(a); box=im.getbbox(); assert box
 assert box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height,(name,box,im.size)
 im=im.crop(box); a=np.array(im); rgb=a[:,:,:3].astype(np.int32)
 # Chunked nearest-palette mapping, alpha retained as binary mask.
 flat=rgb.reshape(-1,3); out=np.empty_like(flat,dtype=np.uint8)
 for i in range(0,len(flat),10000):
  q=flat[i:i+10000]; dist=((q[:,None,:]-pal.astype(np.int32)[None,:,:])**2).sum(2)
  out[i:i+len(q)]=pal[dist.argmin(1)]
 a[:,:,:3]=out.reshape(rgb.shape); a[:,:,3]=np.where(a[:,:,3]>127,255,0)
 a[a[:,:,3]==0]=0
 im=Image.fromarray(a); im.save(S/(name+'-clean.png')); return im
intact=clean('deck-intact').resize((288,72),NN)
damaged=clean('deck-damaged').resize((288,72),NN)
post=clean('post').resize((24,84),NN)
wood=clean('wood-rail'); rope=clean('rope-rail')
# Flatten the source handrail baseline, then remap its endpoints to exact (72,36).
def rail(im,slope):
 a=np.array(im); h,w=a.shape[:2]; sh=int(abs(slope)*w)+8
 flat=Image.new('RGBA',(w,h+sh))
 for x in range(w):
  flat.alpha_composite(im.crop((x,0,x+1,h)),(x,sh-round(slope*x)))
 box=flat.getbbox(); flat=flat.crop((0,box[1],w,box[3])).resize((72,30),NN)
 result=Image.new('RGBA',(72,66))
 for x in range(72):result.alpha_composite(flat.crop((x,0,x+1,30)),(x,round(x*.5)))
 return result
wood=rail(wood,.37); rope=rail(rope,.35)
post.save(M/'support_post.png'); wood.save(M/'rail_wood_u.png'); rope.save(M/'rail_rope_u.png')
for name in ['wood','rope']:
 im=wood if name=='wood' else rope
 im.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(M/f'rail_{name}_v.png')
CAN=(448,304); START=(64,64)
# Forward projection of a rectangular texture plane with an inverse affine sample.
def project(tex,length):
 # texture x and y already have 36 pixels per logical tile.
 w,h=tex.size
 return tex.transform((w+h,(w+h)//2),Image.Transform.AFFINE,(.5,1,-h/2,-.5,1,h/2),NN)
def flip(im,axis):return im if axis=='u' else im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
entries=[]
# Reusable repeat and half-tile bank lip; no independent remeshing of generation.
for axis in ['u','v']:
 for name,tex,length in [('deck_repeat',intact.crop((72,0,144,72)),2),('deck_damaged',damaged.crop((108,0,180,72)),2),('end_cap_start',intact.crop((0,0,18,72)),.5),('end_cap_end',intact.crop((270,0,288,72)),.5)]:
  im=flip(project(tex,length),axis); path=M/f'{name}_{axis}.png';im.save(path)
  # projected top vertex in the local image; cap dimensions differ by design.
  anchor=[72,0] if axis=='u' else [im.width-1-72,0]
  entries.append(dict(id=f'{name}_{axis}',path='res://'+path.relative_to(ROOT).as_posix(),size=list(im.size),anchor=anchor,length_tiles=length,width_tiles=2,axis=axis))
for name in ['wood','rope']:
 for axis in ['u','v']:
  path=M/f'rail_{name}_{axis}.png';im=Image.open(path)
  start=[0,0] if axis=='u' else [71,0]
  end=[72,36] if axis=='u' else [-1,36]
  entries.append(dict(id=f'rail_{name}_{axis}',path='res://'+path.relative_to(ROOT).as_posix(),size=list(im.size),anchor=start,start_socket=start,end_socket=end,length_tiles=2,axis=axis,role='railing'))
entries.append(dict(id='support_post',path='res://'+(M/'support_post.png').relative_to(ROOT).as_posix(),size=list(post.size),anchor=[12,44],ground_contact=[12,84],role='support',deck_connection=[12,44],upper_rail_connection=[12,12]))
assemblies=[]
for length,label in [(4,'short'),(6,'medium'),(8,'long')]:
 for style in ['wood','rope','damaged']:
  tex=intact.crop((0,0,length*36,72))
  if style=='damaged':
   # Take a centered region of the generated damaged texture; preserves its hole.
   x=(288-length*36)//2;tex=damaged.crop((x,0,x+length*36,72))
  deck=Image.new('RGBA',CAN);rear=Image.new('RGBA',CAN);front=Image.new('RGBA',CAN);supports=Image.new('RGBA',CAN)
  deck.alpha_composite(project(tex,length),(28,46))
  r=rope if style=='rope' else wood
  for t in range(0,length,2):
   for near in [False,True]:
    x=100+36*t-(72 if near else 0);y=46+18*t+(36 if near else 0)
    (front if near else rear).alpha_composite(r,(x,y-32))
  for t in range(0,length+1,2):
   for near in [False,True]:
    x=100+36*t-(72 if near else 0);y=46+18*t+(36 if near else 0)
    # Timber extends 40px below the deck; handrail cap is 44px above.
    supports.alpha_composite(post,(x-12,y-44))
  for axis in ['u','v']:
   prefix=f'{label}_{style}_{axis}'
   layers={}
   composed=Image.new('RGBA',CAN)
   for lname,im in [('supports',supports),('rear',rear),('deck',deck),('front',front)]:
    im=flip(im,axis);path=L/f'{prefix}_{lname}.png';im.save(path);layers[lname]='res://'+path.relative_to(ROOT).as_posix();composed.alpha_composite(im)
   composed.save(P/f'{prefix}.png')
   a=list(START) if axis=='u' else [CAN[0]-1-START[0],START[1]]
   end=[a[0]+(1 if axis=='u' else -1)*36*length,a[1]+18*length]
   assemblies.append(dict(id=prefix,length_tiles=length,width_tiles=2,axis=axis,style=style,size=list(CAN),anchor=a,start_socket=a,end_socket=end,deck_width_vector=[-72 if axis=='u' else 72,36],layers=layers,preview='res://'+(P/f'{prefix}.png').relative_to(ROOT).as_posix()))
manifest=dict(schema='shinobi_blightwood_bridges_v1',status='art_review',production_bound=False,texture_filter='nearest',logical_tile_size=[72,36],basis={'u':[36,18],'v':[-36,18]},width_tiles=2,lengths_tiles=[4,6,8],animation={'frame_count':1,'fps':0,'loop':False},palette=['#'+''.join(f'{c:02x}' for c in p) for p in pal],palette_sampled_from=refs,generator='built-in image_gen; deterministic cleanup/palette quantization/nearest projection and composition',modules=entries,assemblies=assemblies,integration='NOT LIVE - awaiting Aki gameplay integration. PNG prefabs are previews; use separate layers for actor occlusion. No collision/navigation authored. Damaged deck is cosmetic; rope variant uses timber supports.')
manifest['sha256']={str(p.relative_to(A)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(list(M.glob('*.png'))+list(L.glob('*.png'))+list(P.glob('*.png')))}
(A/'bridges.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
# Contact sheet displays delivered bitmap sprites; labels/background are documentation only.
canvas=Image.new('RGB',(1440,1120),'#111b21'); draw=ImageDraw.Draw(canvas)
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',18)
draw.text((24,15),'BLIGHTWOOD BRIDGES | 72x36 grid | 4 / 6 / 8 tile lengths',fill='#c2c6b2',font=font)
for row,style in enumerate(['wood','rope','damaged']):
 for col,label in enumerate(['short','medium','long']):
  im=Image.open(P/f'{label}_{style}_u.png');x=col*480+16;y=row*320+55
  canvas.paste(im,(x,y),im);draw.text((x+12,y+266),f'{label.upper()} / {style.upper()}',font=font,fill='#b0b59e')
draw.text((24,1040),'Both diagonal axes included. Separate deck / rear / front / support layers.',font=font,fill='#b0b59e')
draw.text((24,1070),'ART KIT - traversal, rail collision and builder placement await gameplay integration.',font=font,fill='#888f79')
canvas.save(D/'contact-sheet.png')
print(json.dumps({'modules':len(entries),'assemblies':len(assemblies),'layers':len(assemblies)*4,'palette_colors':len(pal),'contact_sheet':str(D/'contact-sheet.png')}))
