"""PixelLab-source cleanup, palette registration, toroidal edge repair and exact diamond masks.
No water motifs are painted procedurally. Only native-size crops and alpha masks are generated.
"""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'assets/environment/blightwood_water'; SRC=BASE/'source'; DOC=Path(__file__).parent
ROLES=['corner_top','edge_ne','corner_right','edge_nw','center','edge_se','corner_left','edge_sw','corner_bottom']
EDGES={'center':[], 'edge_ne':['v-'],'edge_nw':['u-'],'edge_se':['u+'],'edge_sw':['v+'],'corner_top':['u-','v-'],'corner_right':['u+','v-'],'corner_bottom':['u+','v+'],'corner_left':['u-','v+']}

def rgba(path):
 a=np.array(Image.open(path).convert('RGBA')); a[a[:,:,3]<128]=0;a[:,:,3]=np.where(a[:,:,3]>=128,255,0);return a

def wrap(a):
 # Repair only a four-pixel edge band in the full-bleed source texture; no upscaling.
 a=a.copy()
 # PixelLab supplied an unwanted one-pixel dark frame: replace only that border with adjacent native pixels.
 a[0]=a[1];a[-1]=a[-2];a[:,0]=a[:,1];a[:,-1]=a[:,-2]
 for axis in [0,1]:
  a=np.swapaxes(a,axis,0)
  for k in range(4):
   mean=((a[k,:,:3].astype(float)+a[-1-k,:,:3].astype(float))/2).round().astype('uint8')
   weight=(4-k)/4
   a[k,:,:3]=(a[k,:,:3]*(1-weight)+mean*weight).round().astype('uint8')
   a[-1-k,:,:3]=(a[-1-k,:,:3]*(1-weight)+mean*weight).round().astype('uint8')
  a=np.swapaxes(a,axis,0)
 return a

def main():
 (BASE/'tiles').mkdir(exist_ok=True)
 validation={'frames':{},'mask_roles':ROLES,'native_scale':True,'tile_size':[72,36]}
 frames={}
 for name,size in [('surface',(128,128)),('waterfall',(128,192)),('foam',(128,64))]:
  fs=[]
  for i in range(16):
   a=rgba(SRC/f'{name}-{i:02}.png');assert a.shape[:2]==size[::-1]
   if name=='surface':
    a=wrap(a);a[:,:,3]=255
    assert a[0,:,:3].mean()>70 and a[:,0,:3].mean()>70
    assert np.array_equal(a[0],a[-1]) and np.array_equal(a[:,0],a[:,-1])
   if name=='waterfall':a[164:]=0 # original landing apron removed; independent foam owns that region
   fs.append(Image.fromarray(a))
  hashes=[hashlib.sha256(im.tobytes()).hexdigest() for im in fs]
  assert len(set(hashes))==16,(name,'duplicate frames')
  atlas=Image.new('RGBA',(size[0]*4,size[1]*4))
  for i,im in enumerate(fs):atlas.paste(im,((i%4)*size[0],(i//4)*size[1]))
  atlas.save(BASE/f'{name}-atlas.png');fs[0].save(BASE/f'{name}-icon.png');frames[name]=fs
  validation['frames'][name]={'count':16,'hashes':hashes,'size':list(size),'fps':{'surface':16,'waterfall':18,'foam':13}[name]}
  sheet=Image.new('RGBA',(size[0]*4,size[1]*4),'#20323c')
  for i,im in enumerate(fs):sheet.alpha_composite(im,((i%4)*size[0],(i//4)*size[1]))
  sheet.save(DOC/f'{name}-contact.png')
 # Native reference crop for builder thumbnails and the mask texture; runtime samples shared world UV.
 source=np.array(frames['surface'][0]); y,x=np.mgrid[0:36,0:72];xx=x+.5-36;yy=y+.5-18;u=xx/36+yy/18;v=-xx/36+yy/18
 diamond=(abs(u)<=1)&(abs(v)<=1); records=[]
 for role in ROLES:
  alpha=diamond.astype(float)
  for edge in EDGES[role]:
   coord=u if edge[0]=='u' else v;distance=1+(coord if edge[1]=='-' else -coord)
   alpha*=np.clip((distance-.035)/.16,0,1)
  a=source[y+46,x+28].copy();a[:,:,3]=(alpha*255).round().astype('uint8');a[a[:,:,3]==0]=0
  Image.fromarray(a).save(BASE/'tiles'/f'water9_{role}.png')
  records.append({'role':role,'path':f'res://assets/environment/blightwood_water/tiles/water9_{role}.png','size':[72,36],'anchor':[36,18],'shore_edges':EDGES[role]})
 # Exact native droplet extraction from the authored falling-water highlight.
 a=np.array(frames['waterfall'][0]);rgb=a[:,:,:3].astype(int);valid=(a[:,:,3]>0)&(rgb[:,:,0]>160)&(rgb[:,:,2]>180)
 ys,xs=np.where(valid);j=len(xs)//3;cx,cy=int(xs[j]),int(ys[j]);drop=Image.fromarray(a).crop((cx,cy,cx+2,cy+3));assert drop.getbbox();drop.save(BASE/'droplet.png')
 manifest={'schema':'shinobi_blightwood_water_v1','status':'review','logical_tile_size':[72,36],'texture_filter':'nearest','tiles':records,'animations':validation['frames'],'waterfall_anchor':[64,169],'fall_sprite_offset':[0,-73],'foam_sprite_offset':[0,-1],'separate_layers':['river_surface','falling_water','landing_foam','spray'],'droplet_pool':18,'gameplay':'Decorative only; no water collision/swimming behavior or automatic map placement.','provider':'PixelLab','processing':'Native cleanup, one-pixel frame removal, toroidal edge band repair, exact diamond alpha clipping; original waterfall apron cropped out for separate foam. No interpolation or scaling.'}
 (BASE/'water.art.json').write_text(json.dumps(manifest,indent=2)+'\n');(DOC/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
 tiles=Image.new('RGBA',(216,108),'#24323a')
 for i,role in enumerate(ROLES):tiles.alpha_composite(Image.open(BASE/'tiles'/f'water9_{role}.png'),((i%3)*72,(i//3)*36))
 tiles.resize((864,432),Image.Resampling.NEAREST).save(DOC/'nine-tiles.png')
 print('PASS 48 unique native animation frames,9 diamond masks, atlases, metadata, contact sheets')
if __name__=='__main__':main()
