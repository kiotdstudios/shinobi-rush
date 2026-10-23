"""Chroma cleanup and fixed per-sheet scale/root registration, never per-frame fits."""
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
# Measured whole-sheet source zoom corrections against the accepted standing-equivalent guard.
# Every pose of the continuous combo uses the SAME scale, including all three attacks.
NORMALIZED={'player-S-combo':140,'bandit-S-combo':140,'bandit-N-combo':150,'bandit-E-combo':150,'bandit-NE-combo':154,'bandit-SE-combo':148,'bandit-SE-light3':150}
# One constant root correction across each complete dash sheet; no per-frame X centering.
OFFSETS={'player-NE-dash':-3,'bandit-NE-dash':-3,'bandit-SE-dash':-5}
def clean(im):
 a=np.asarray(im.convert('RGBA')).copy();r,g,b=[a[:,:,i].astype(int) for i in range(3)]
 mask=(r>80)&(b>70)&(r>g*1.5)&(b>g*1.5)&(r>b*.75)&(r<b*1.30);a[mask]=0;a[~mask,3]=255
 return Image.fromarray(a)
def extract(path):
 im=Image.open(path);cols,rows=(4,5) if path.stem.endswith('combo') else (3,2)
 sc=NORMALIZED.get(path.stem,160)/(im.width/cols);frames=[]
 for i in range(cols*rows):
  x,y=i%cols,i//cols;c=clean(im.crop((round(x*im.width/cols),round(y*im.height/rows),round((x+1)*im.width/cols),round((y+1)*im.height/rows))))
  small=c.resize((round(c.width*sc),round(c.height*sc)),Image.Resampling.NEAREST);b=small.getbbox();assert b
  dx=64-round(small.width/2)+OFFSETS.get(path.stem,0);dy=116-b[3]
  bounds=[b[0]+dx,b[1]+dy,b[2]+dx,b[3]+dy]
  assert min(bounds[:2])>=0 and bounds[2]<=128 and bounds[3]==116,(path.stem,i,bounds)
  f=Image.new('RGBA',(128,128));f.paste(small,(dx,dy));frames.append(f)
 return frames,cols,rows
