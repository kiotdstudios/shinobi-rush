"""Measure AI underpaint padding against original head/foot landmarks, no edits."""
from pathlib import Path
from PIL import Image
import numpy as np
import json

ROOT=Path(__file__).resolve().parents[1]
def code(a):return (a[:,:,0]//32).astype(int)*64+(a[:,:,1]//32).astype(int)*8+(a[:,:,2]//32).astype(int)
def register(b,q,mask):
 bc,qc=code(b),code(q);score=np.zeros((256,256));colors,counts=np.unique(bc[mask],return_counts=True)
 for color,count in zip(colors,counts):
  if count<2:continue
  bm=(bc==color)&mask;qm=(qc==color)&(q[:,:,3]>0)
  score+=np.fft.irfft2(np.fft.rfft2(bm,s=(256,256))*np.conj(np.fft.rfft2(qm,s=(256,256))),s=(256,256))
 options=[(float(score[dy%256,dx%256]),dx,dy) for dy in range(-32,33) for dx in range(-32,33)]
 best=max(options,key=lambda x:x[0]);return {'shift':[best[1],best[2]],'matched':round(best[0]),'target_pixels':int(mask.sum())}
records=[]
for action in ['light_attack_1','light_attack_2','light_attack_3']:
 for i in range(8):
  b=np.array(Image.open(ROOT/f'baked_reference/{action}/SE_{i:03}.png').convert('RGBA'));q=np.array(Image.open(ROOT/f'source/body_candidates/{action}/SE_{i:03}.png').convert('RGBA'));yy=np.indices(b.shape[:2])[0];rgb=b[:,:,:3].astype(float);skin=(rgb[:,:,0]>25)&(rgb[:,:,0]>rgb[:,:,1]*1.15)&(rgb[:,:,0]>rgb[:,:,2]*1.1)
  metal=(rgb.max(axis=2)-rgb.min(axis=2)<20)&(rgb.max(axis=2)>145)
  head=(yy<55)&(b[:,:,3]>0)&~metal;foot=(yy>95)&(b[:,:,3]>0)&~metal
  h,f=register(b,q,head),register(b,q,foot);r={'animation':action,'frame':i,'head':h,'foot':f};records.append(r);print(action,i,'head',h['shift'],'feet',f['shift'],'matches',h['matched'],f['matched'])
(ROOT/'source'/'registration.json').write_text(json.dumps(records,indent=2)+'\n')
