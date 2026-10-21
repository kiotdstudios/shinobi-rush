"""Extract the four generated reference cells using one common grid scale."""
from pathlib import Path
from PIL import Image
import numpy as np
p=Path(__file__).resolve().parent/'references'
im=Image.open(p/'sprint-four-pose-guide.png').convert('RGBA');w,h=im.size
assert w==h and w%2==0
for i,d in enumerate(['S','N','NE','NW']):
 x=i%2*w//2;y=i//2*h//2
 key=im.crop((x,y,x+w//2,y+h//2)).resize((128,128),Image.Resampling.NEAREST)
 a=np.array(key);a[:,:,3]=(a[:,:,3]>=128).astype('uint8')*255;a[a[:,:,3]==0,:3]=0
 Image.fromarray(a).save(p/f'{d}-imagegen-key.png')
print('Four pose guides extracted at common 128px grid scale; binary alpha, no interpolation')
