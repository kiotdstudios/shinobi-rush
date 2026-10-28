"""Lossless native-pixel modular cuts/assembly from approved committed Blightwood art.
No resampling, painted replacement texture, or changes to the source PNGs.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/environment/blightwood/cliff_kit';OUT.mkdir(parents=True,exist_ok=True)
ledge=Image.open(ROOT/'assets/environment/blightwood/stairs/cliff_ledge_se.png').convert('RGBA')
stair=Image.open(ROOT/'assets/environment/blightwood/stairs/earth_stairs_se.png').convert('RGBA')
U=(36,18);V=(-36,18);VERT=[(0,-18),(36,0),(0,18),(-36,0)];RISE=66
# Cut a native 72x36 diamond out of the broad approved stair landing cap.
cap=Image.new('RGBA',(72,36))
for y in range(36):
 for x in range(72):
  if abs((x+.5)-36)/36+abs((y+.5)-18)/18<=1:cap.putpixel((x,y),stair.getpixel((x+110,y+43)))
cap.save(OUT/'cap.png')
grass=Image.open(ROOT/'assets/environment/kosen_courtyard/grass/tiles/grass9_center.png').convert('RGBA').crop((20,66,92,102))
path=Image.open(ROOT/'assets/environment/blightwood/ground_path/ground9_center.png').convert('RGBA')
for name,image in [('grass',grass),('path',path)]:
 if image.size!=(72,36):raise ValueError((name,image.size))
 for y in range(36):
  for x in range(72):
   if abs(x+.5-36)/36+abs(y+.5-18)/18>1:image.putpixel((x,y),(0,0,0,0))
 image.save(OUT/('cap_'+name+'.png'))
faces=[]
for edge,(a,b) in enumerate(zip(VERT,VERT[1:]+VERT[:1])):
 im=Image.new('RGBA',(74,104));mask=Image.new('L',im.size);d=ImageDraw.Draw(mask)
 pts=[(a[0]+37,a[1]+84),(b[0]+37,b[1]+84),(b[0]+37,b[1]+18),(a[0]+37,a[1]+18)]
 d.polygon(pts,fill=255)
 for y in range(104):
  for x in range(74):
   if not mask.getpixel((x,y)):continue
   wx=x-37;wy=y-84
   if edge in (0,2):
    sx=54+(wx+36)%36; top=51+(sx-18)//2
    sy=top+(wy-int(a[1]+(wx-a[0])*.5)+66)
   else:
    sx=230+(wx+36)%36;top=151-(sx-218)//2
    sy=top+(wy-int(a[1]-(wx-a[0])*.5)+66)
   sy=max(0,min(239,sy));c=ledge.getpixel((sx,sy))
   if c[3]==0: c=ledge.getpixel((sx,max(0,min(239,top+30))))
   im.putpixel((x,y),c)
 im.save(OUT/f'face_{edge}.png');faces.append(im)
def rot(c,n):
 u,v=c
 for _ in range(n):u,v=-v,u
 return u,v
def xy(c):u,v=c;return (36*(u-v),18*(u+v))
mods=[]
def add(id,label,uv,role,**extra):
 cells=[xy(c) for c in uv];keys=set(cells)
 xmin=min(p[0]-37 for p in cells);xmax=max(p[0]+37 for p in cells)
 ymin=min(p[1]-84 for p in cells);ymax=max(p[1]+20 for p in cells)
 im=Image.new('RGBA',(xmax-xmin,ymax-ymin));anchor=(-xmin,-ymin)
 for p in sorted(cells,key=lambda p:p[1]):
  for e,(du,dv) in enumerate([(0,-1),(1,0),(0,1),(-1,0)]):
   q=(p[0]+xy((du,dv))[0],p[1]+xy((du,dv))[1])
   if e in (1,2) and q not in keys:im.alpha_composite(faces[e],(p[0]-37-xmin,p[1]-84-ymin))
  im.alpha_composite(Image.open(ROOT/'assets/environment/blightwood_water/tiles/water9_center.png').convert('RGBA') if extra.get('water') else Image.open(OUT/('cap_'+extra['surface']+'.png')) if extra.get('surface') else cap,(p[0]-36-xmin,p[1]-84-ymin))
 im.save(OUT/(id+'.png'))
 mods.append(dict(id=id,label=label,role=role,cells=cells,size=list(im.size),anchor=list(anchor),rise=RISE,collision={'mode':'exposed boundary edges only','layer':64,'thickness':6,'interior_edges':'removed','stairs':'open head edges; blocked sides'},footprint_bounds=[min(p[0]-36 for p in cells),min(p[1]-18 for p in cells),max(p[0]+36 for p in cells),max(p[1]+18 for p in cells)],sockets=sorted(set((p[0]+v[0],p[1]+v[1]) for p in cells for v in VERT)),**extra))
add('cliff_ground','Elevated moss-stone ground',[(0,0)],'fill')
add('cliff_grass','Elevated Blightwood grass',[(0,0)],'fill',surface='grass')
add('cliff_path','Elevated forest path',[(0,0)],'fill',surface='path')
add('cliff_straight_se','Straight cliff SE',[(0,0),(1,0)],'straight')
add('cliff_straight_sw','Straight cliff SW',[(0,0),(0,1)],'straight')
for n,d in enumerate(['s','w','n','e']):
 add('cliff_outer_'+d,'Outer corner '+d.upper(),[rot(c,n) for c in [(0,0),(1,0),(0,1),(1,1)]],'outer_corner')
 add('cliff_inner_'+d,'Inner corner '+d.upper(),[rot(c,n) for c in [(0,0),(1,0),(0,1)]],'inner_corner')
add('cliff_end_se','Cliff end cap SE',[(0,0)],'end_cap')
add('cliff_end_sw','Cliff end cap SW',[(0,0)],'end_cap')
add('cliff_stair_join_se','Stair mouth join SE',[(0,0),(1,0)],'stair_join')
add('cliff_stair_join_sw','Stair mouth join SW',[(0,0),(0,1)],'stair_join')
add('cliff_upper_river','Elevated river',[(0,0)],'river',water=True)
add('cliff_waterfall_lip','Waterfall opening / upper river lip',[(0,0),(1,0)],'waterfall_lip',water=True,fall_socket=[0,18],cascade_crop=[40,52,56,96])
# Two separate native moss-cap shoulder transitions funnel the upper river into the outlet.
for side in ['left','right']:
 image=Image.new('RGBA',(110,122))
 for cx,cy in [(0,0),(36,18)]:
  for y in range(36):
   for x in range(72):
    c=cap.getpixel((x,y))
    if not c[3]:continue
    gx=x-36+cx;gy=y-18+cy
    u=(gx/36+gy/18)*.5;v=(gy/18-gx/36)*.5
    width=1.0-.6*max(0,min(1,v+.5))
    if abs(u-.5)>width and ((u<.5)==(side=='left')):
     image.putpixel((gx+37,gy+18),c)
 image.save(OUT/('lip_'+side+'.png'))
preview=Image.open(OUT/'cliff_waterfall_lip.png').convert('RGBA')
preview.alpha_composite(Image.open(OUT/'lip_left.png'));preview.alpha_composite(Image.open(OUT/'lip_right.png'));preview.save(OUT/'cliff_waterfall_lip.png')
# Native cascade strip: preserve original RGB/frame timing and clip to the diagonal lip and basin.
raw=Image.open(ROOT/'assets/environment/blightwood_water/waterfall-atlas.png').convert('RGBA')
atlas=Image.new('RGBA',(56*4,96*4))
for frame in range(16):
 for y in range(96):
  for x in range(56):
   lip=8+(x-22)*.5
   if lip<=y<lip+66:
    sy=60+y-8
    if 0<=sy<192:atlas.putpixel(((frame%4)*56+x,(frame//4)*96+y),raw.getpixel(((frame%4)*128+40+x,(frame//4)*192+sy)))
atlas.save(OUT/'cascade-atlas.png')
icon=Image.new('RGBA',(128,112));icon.alpha_composite(atlas.crop((0,0,56,96)),(42,6))
foam=Image.open(ROOT/'assets/environment/blightwood_water/foam-atlas.png').convert('RGBA').crop((0,0,128,64));icon.alpha_composite(foam,(0,47));icon.save(OUT/'cliff_cascade-icon.png')
# Stair wrappers preserve exact source images, dimensions, anchors, ramps and existing ids.
manifest={'version':1,'generator':'lossless approved-source cuts and native alpha-mask assembly; no AI pixels accepted','grid':{'u':U,'v':V,'diamond':[72,36],'rise':RISE},'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['assets/environment/blightwood/stairs/cliff_ledge_se.png','assets/environment/blightwood/stairs/earth_stairs_se.png','assets/environment/kosen_courtyard/grass/tiles/grass9_center.png','assets/environment/blightwood/ground_path/ground9_center.png','assets/environment/blightwood_water/waterfall-atlas.png','assets/environment/blightwood_water/foam-atlas.png','assets/environment/blightwood_water/tiles/water9_center.png']},'cascade':{'atlas':'cascade-atlas.png','frame_size':[56,96],'frame_count':16,'fps':18,'anchor':[22,74],'rise':66,'lip':'y=8+0.5*(x-22)','basin':'lip+66','source_row':52,'foam_fps':13,'drops':18},'components':{'cap':{'file':'cap.png','size':[72,36],'anchor':[36,84]},'faces':[{'file':f'face_{i}.png','size':[74,104],'anchor':[37,84]} for i in range(4)]},'modules':mods,'rules':['Cells are ground-plane 72x36 diamonds; surfaces draw 66px above ground.','Shared cells and interior faces are removed deterministically. Exposed edges form collision rims.','Inner corners are real concave three-cell footprints; outer corners are four-cell turns.','SE/SW staircase wrappers retain exact approved art and open two consecutive boundary edges.','Cascade is separate from lip, with native 56x96 frames / 66px rise; no stretching; legacy waterfall defaults unchanged.']}
(OUT/'cliffs.art.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
cs=Image.new('RGB',(1000,((len(mods)+4)//5)*220),(26,45,47));d=ImageDraw.Draw(cs)
for i,m in enumerate(mods):
 im=Image.open(OUT/(m['id']+'.png'));x=(i%5)*200;y=(i//5)*220
 cs.paste(im,(x+(200-im.width)//2,y+20),im);d.text((x+8,y+190),m['id'],fill='white')
(ROOT/'docs/visuals/cliff-kit').mkdir(parents=True,exist_ok=True);cs.save(ROOT/'docs/visuals/cliff-kit/contact-sheet.png')
print(len(mods),'native modules; exact source textures preserved')
