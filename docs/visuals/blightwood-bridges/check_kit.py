"""Bridge export integrity and grid contract checks; run before committing."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[3];A=R/'assets/environment/blightwood_bridges'
m=json.loads((A/'bridges.art.json').read_text(encoding='utf-8'))
checks=0

def ck(value,message):
 global checks
 assert value,message
 checks+=1
palette={tuple(bytes.fromhex(c[1:])) for c in m['palette']}
ck(m['logical_tile_size']==[72,36],'grid')
ck(len(m['modules'])==13,'module count')
ck(len(m['assemblies'])==18,'assembly count')
for rel,sha in m['sha256'].items():
 p=A/rel;ck(hashlib.sha256(p.read_bytes()).hexdigest()==sha,rel+' hash')
 im=Image.open(p);im.verify();im=Image.open(p)
 ck(im.mode=='RGBA',rel+' RGBA');a=np.array(im)
 ck(set(np.unique(a[:,:,3])).issubset({0,255}),rel+' binary alpha')
 ck((a[:,:,3]==0).any() and (a[:,:,3]==255).any(),rel+' nonempty transparency')
 colors={tuple(c) for c in a[a[:,:,3]>0,:3]}
 ck(colors.issubset(palette),rel+' sampled palette')
for e in m['assemblies']:
 a=e['start_socket'];b=e['end_socket'];n=e['length_tiles'];sgn=1 if e['axis']=='u' else -1
 ck(b==[a[0]+sgn*36*n,a[1]+18*n],e['id']+' sockets')
 ck(e['width_tiles']==2,e['id']+' fixed width')
 im=Image.open(R/e['preview'].removeprefix('res://'));box=im.getbbox()
 ck(box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height,e['id']+' no clipping')
 prefix=e['id'].rsplit('_',1)[0]
 if e['axis']=='v':
  original=Image.open(A/'prefabs'/f'{prefix}_u.png')
  ck(im.tobytes()==original.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes(),e['id']+' mirrored pixel alignment')
for length in ['short','medium','long']:
 intact=np.array(Image.open(A/'layers'/f'{length}_wood_u_deck.png'))[:,:,3]
 damaged=np.array(Image.open(A/'layers'/f'{length}_damaged_u_deck.png'))[:,:,3]
 ck(np.count_nonzero(damaged)<np.count_nonzero(intact)*.95,length+' damage hole')
result={'checks_passed':checks,'failed':0,'files':len(m['sha256']),'modules':13,'assemblies':18,'runtime':'NOT LIVE - art only'}
(Path(__file__).parent/'asset-qc.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
