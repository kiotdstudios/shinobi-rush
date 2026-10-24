"""Nearest-pixel art comparison; the body files never depend on weapon choice."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parents[0]/'previews'/'modular-weapon-poc'
OUT.mkdir(parents=True,exist_ok=True)
M=json.loads((ROOT/'modular_poc.json').read_text())
SIZE=(192,192);OFFSET=(32,32)
def render(frame,weapon=None,baked=False):
 canvas=Image.new('RGBA',SIZE)
 body=Image.open(ROOT/(frame['baked_reference'] if baked else frame['body_frame'])).convert('RGBA')
 attachment=None
 if weapon:
  spec=M['weapons'][weapon];im=Image.open(ROOT/spec['texture']).convert('RGBA');angle=math.radians(frame['weapon_angle_deg']);c,s=math.cos(angle),math.sin(angle);px,py=spec['grip_pivot_px'];hx,hy=[frame['right_hand_px'][j]+OFFSET[j] for j in range(2)]
  attachment=im.transform(SIZE,Image.Transform.AFFINE,(c,s,px-c*hx-s*hy,-s,c,py+s*hx-c*hy),Image.Resampling.NEAREST)
  assert attachment.getpixel((hx,hy))[3]==255, 'weapon grip disconnected'
  if frame['weapon_layer']=='behind':canvas.alpha_composite(attachment)
 canvas.alpha_composite(body,OFFSET)
 if attachment is not None and frame['weapon_layer']=='front':
  canvas.alpha_composite(attachment);x,y,w,h=frame['hand_occlusion_rect'];canvas.alpha_composite(body.crop((x,y,x+w,y+h)),(x+32,y+32))
 assert set(canvas.getchannel('A').get_flattened_data())<={0,255}
 assert canvas.getbbox()[0]>0 and canvas.getbbox()[1]>0 and canvas.getbbox()[2]<192 and canvas.getbbox()[3]<192,'composite clipping'
 return canvas

def matte(im):
 base=Image.new('RGB',SIZE,(44,54,62));draw=ImageDraw.Draw(base)
 for y in range(0,192,8):
  for x in range(0,192,8):
   if (x//8+y//8)%2:draw.rectangle((x,y,x+7,y+7),fill=(50,61,70))
 base.paste(im,(0,0),im);return base

if __name__=='__main__':
 frames=[f for a in M['animations'].values() for f in a['frames']]
 modes=[('baked','Fully drawn katana'),('body','Weaponless body'),('katana','Shared body + katana'),('straight_sword','Shared body + straight sword')]
 panels={key:[] for key,label in modes};combined=[]
 contact=Image.new('RGB',(4*384,6*408),(25,33,39));draw=ImageDraw.Draw(contact)
 for index,frame in enumerate(frames):
  row=Image.new('RGB',(4*384,420),(25,33,39));d=ImageDraw.Draw(row)
  for col,(key,label) in enumerate(modes):
   im=render(frame,None if key in ('body','baked') else key,baked=key=='baked');display=matte(im).resize((384,384),Image.Resampling.NEAREST);panels[key].append(display)
   row.paste(display,(col*384,32));d.text((col*384+8,8),label,fill='white')
  combined.append(row)
  if index in [0,2,4,5,8,9,11,15,16,17,18,23]:
   n=[0,2,4,5,8,9,11,15,16,17,18,23].index(index);tile=matte(render(frame,'katana')).resize((384,384),Image.Resampling.NEAREST);contact.paste(tile,(n%4*384,n//4*408+24));draw.text((n%4*384+8,n//4*408+4),f'{index//8+1}:{index%8}',fill='white')
 # GIF ticks are10ms;80,80,90ms gives exact0.5x average for24FPS source.
 durations=[80,80,90]*8
 for key,seq in panels.items():seq[0].save(OUT/f'{key}.gif',save_all=True,append_images=seq[1:],duration=durations,loop=0,optimize=False)
 combined[0].save(OUT/'comparison.gif',save_all=True,append_images=combined[1:],duration=durations,loop=0,optimize=False)
 contact.crop((0,0,1536,3*408)).save(OUT/'katana_contact.png')
 print('PASS48 weapon composites: opaque grip, binary alpha, no canvas clipping;24 shared body frames reused; review GIFs at0.5x')
