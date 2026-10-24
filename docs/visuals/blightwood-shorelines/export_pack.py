"""Native PixelLab terrain extraction and exact corner-compatible boundary registration.
Land pixels come from PixelLab. Border repair copies nearest authored land pixels only.
"""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT/'assets/environment/blightwood_shorelines';SRC=BASE/'source';DOC=Path(__file__).parent
LABELS=['Water fill','Outer Bottom','Outer Left','Bank SW','Outer Right','Bank SE','Split L/R','Inner Top','Outer Top','Split T/B','Bank NW','Inner Right','Bank NE','Inner Left','Inner Bottom','Land fill']
P=json.loads((SRC/'palettes.json').read_text())['palettes'];LAND=list(dict.fromkeys(P['grass']+P['dirt']+P['rock']));WATER=P['water'];HEX=LAND+WATER
RGB=np.array([[int(c[i:i+2],16)for i in (1,3,5)]for c in HEX],dtype=int)
y,x=np.mgrid[:36,:72];u=(x+.5-36)/36+(y+.5-18)/18;v=-(x+.5-36)/36+(y+.5-18)/18;DIAMOND=(abs(u)<=1)&(abs(v)<=1)
YMIN=np.argmax(DIAMOND,axis=0);YMAX=35-np.argmax(DIAMOND[::-1],axis=0)
EDGES={'ne':(np.arange(36,72),YMIN[36:],8,4,1),'nw':(np.arange(36),YMIN[:36],2,8,1),'se':(np.arange(36,72),YMAX[36:],1,4,-1),'sw':(np.arange(36),YMAX[:36],2,1,-1)}

def extract(family,mask):
 raw=np.array(Image.open(SRC/f'{family}-{mask:02}.png').convert('RGBA'));assert raw.shape==(36,72,4)
 nearest=((raw[:,:,:3].astype(int)[:,:,None,:]-RGB[None,None,:,:])**2).sum(3).argmin(2)
 original=(nearest<len(LAND))&DIAMOND
 L=original.copy()
 # Register only the two-pixel native boundary strip to the shared corner signature.
 for xs,ys,first,last,inward in EDGES.values():
  expected=np.where(np.arange(36)<18,bool(mask&first),bool(mask&last))
  for k in range(2):
   yy=np.clip(ys+inward*k,0,35);valid=DIAMOND[yy,xs];L[yy[valid],xs[valid]]=expected[valid]
 if mask==0:L[:]=False
 if mask==15:L=DIAMOND.copy()
 colors=RGB[np.minimum(nearest,len(LAND)-1)].astype('uint8')
 missing=L&~original
 if missing.any():
  source_points=np.argwhere(original);assert len(source_points)
  for yy,xx in np.argwhere(missing):
   pick=source_points[((source_points-[yy,xx])**2).sum(1).argmin()];colors[yy,xx]=RGB[nearest[pick[0],pick[1]]]
 land=np.zeros((36,72,4),dtype='uint8');land[:,:,:3]=colors;land[:,:,3]=L*255;land[~L]=0
 water=np.zeros_like(land);water[:,:,:3]=255;water[:,:,3]=(DIAMOND&~L)*255;water[water[:,:,3]==0]=0
 assert np.array_equal((land[:,:,3].astype(int)+water[:,:,3]),DIAMOND*255)
 points=[(36,4,8),(63,18,4),(8,18,2),(36,31,1)]
 for cx,cy,bit in points:assert (L[cy-1:cy+2,cx-1:cx+2].mean()>.5)==bool(mask&bit),(family,mask,bit)
 return land,water,L,int(missing.sum())

def edge_check(masks):
 tested=0
 for a in range(16):
  for b in range(16):
   for side,other,abits,bbits in [('ne','sw',(8,4),(2,1)),('se','nw',(1,4),(2,8))]:
    if all(bool(a&i)==bool(b&j)for i,j in zip(abits,bbits)):
     xa,ya,*_=EDGES[side];xb,yb,*_=EDGES[other]
     valid=DIAMOND[ya,xa]&DIAMOND[yb,xb]
     assert np.array_equal(masks[a][ya,xa][valid],masks[b][yb,xb][valid]),(a,b,side)
     tested+=1
 return tested

def main():
 for name in ['land','water_masks','tiles']:(BASE/name).mkdir(exist_ok=True)
 current=np.array(Image.open(ROOT/'assets/environment/blightwood_water/surface-atlas.png').convert('RGBA'))[:128,:128]
 sampled=current[(y-18)%128,(x-36)%128].copy();sampled[:,:,3]=DIAMOND*255;sampled[~DIAMOND]=0
 records=[];counts={};repairs={}
 for family in ['grass','dirt','rock']:
  masks=[];repairs[family]=0;sheet=Image.new('RGBA',(320,240),'#223139');draw=ImageDraw.Draw(sheet)
  for mask,label in enumerate(LABELS):
   land,water,L,repaired=extract(family,mask);stem=f'{family}_{mask:02}';masks.append(L);repairs[family]+=repaired
   Image.fromarray(land).save(BASE/'land'/f'{stem}.png');Image.fromarray(water).save(BASE/'water_masks'/f'{stem}.png')
   combo=sampled.copy();combo[L]=land[L];im=Image.fromarray(combo);im.save(BASE/'tiles'/f'shore_{stem}.png')
   xx=(mask%4)*80+4;yy=(mask//4)*60+2;sheet.alpha_composite(im,(xx,yy));draw.text((xx,yy+38),f'{mask:02} {label}',fill='#c8d6d9',font_size=8)
   records.append({'id':'shore_'+stem,'family':family,'mask':mask,'label':label,'size':[72,36],'anchor':[36,18],'land':f'res://assets/environment/blightwood_shorelines/land/{stem}.png','water_mask':f'res://assets/environment/blightwood_shorelines/water_masks/{stem}.png','thumbnail':f'res://assets/environment/blightwood_shorelines/tiles/shore_{stem}.png','land_pixels':int(L.sum()),'water_pixels':int((DIAMOND&~L).sum()),'land_sha256':hashlib.sha256(land.tobytes()).hexdigest()})
  counts[family]=edge_check(masks);sheet.resize((960,720),Image.Resampling.NEAREST).save(DOC/f'{family}-contact.png')
 manifest={'schema':'shinobi_blightwood_shorelines_v1','status':'review','tile_size':[72,36],'anchor':[36,18],'corner_bits':{'top':8,'right':4,'left':2,'bottom':1},'terrain_one':'land','terrain_zero':'existing animated water','families':['grass','dirt','rock'],'tiles':records,'animation_reference':'res://assets/environment/blightwood_water/water.art.json','water_fps':16,'texture_filter':'nearest','source_tool':'PixelLab create_tiles_pro','processing':'Native palette classification, land/water separation, exact two-pixel boundary signature with nearest authored land-pixel repair. No scaling or painted substitute geometry.','physics':'Decorative only; no swimming, terrain collision or map layout change.'}
 (BASE/'shorelines.art.json').write_text(json.dumps(manifest,indent=2)+'\n')
 result={'tiles':len(records),'per_family':16,'native_size':[72,36],'land_water_alpha_union':'exact diamond, no holes or overlap','corner_probes':192,'compatible_edge_pairs':counts,'boundary_repair_pixels':repairs,'source_palette_file':'source/palettes.json'}
 (DOC/'validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':main()
