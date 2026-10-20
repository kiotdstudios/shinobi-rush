"""Export/composite PixelLab originals; no generated pixels, warping or body scaling."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,hashlib
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'source';PLAYER=ROOT.parents[1];PRE=PLAYER/'previews/summoning'
for p in [ROOT/'body',ROOT/'contract',ROOT/'smoke',PRE]:p.mkdir(exist_ok=True,parents=True)
def check(im,clear=False):
 a=np.array(im);assert im.mode=='RGBA' and set(np.unique(a[:,:,3]))<={0,255}
 assert clear or np.any(a[:,:,3]);assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3])
body=[]
for i in range(4):
 raw=Image.open(SRC/f'pose-{i}.png').convert('RGBA');assert raw.size==(128,128)
 # Same measured16px horizontal padding correction for all four poses; no per-pose recentering.
 im=Image.new('RGBA',(128,128));im.paste(raw,(-16,0));check(im);im.save(ROOT/f'body/SE_{i:03}.png');body.append(im)
idle=Image.open(PLAYER/'sprites/production/idle/SE_000.png').convert('RGBA');idle.save(ROOT/'body/SE_004.png');body.append(idle)
assert body[3].getpixel((60,109))[3]==255
def extract(name,count,size,cols):
 sheet=Image.open(SRC/f'{name}-sheet.png').convert('RGBA');assert sheet.size==(cols*size,((count+cols-1)//cols)*size)
 ims=[]
 for i in range(count):
  im=sheet.crop((i%cols*size,i//cols*size,(i%cols+1)*size,(i//cols+1)*size));check(im,clear=name=='smoke' and i==11);im.save(ROOT/f'{name}/{i:03}.png');ims.append(im)
 assert len({im.tobytes() for im in ims})==count
 return ims
seal=extract('contract',6,256,3);smoke=extract('smoke',12,256,4)
assert smoke[-1].getbbox() is None
ink_bounds=seal[-1].getbbox();assert ink_bounds[2]-ink_bounds[0]>=225
steps=[(0,100),(1,80),(0,60),(1,60),(2,150),(3,50),(3,400),(2,100),(4,1600)]
assert sum(ms for _,ms in steps)==2600
def body_index(t):
 elapsed=0
 for idx,ms in steps:
  elapsed+=ms
  if t<elapsed:return idx
 return 4
timeline=[];renders=[];matte=Image.new('RGBA',(320,256),'#899479')
for i in range(52):
 t=i*50;b=body_index(t);c=None if t<450 else min(5,(t-450)//50);s=None if t<1100 or t>=1940 else min(11,(t-1100)//70)
 canvas=Image.new('RGBA',(320,256))
 if c is not None:canvas.alpha_composite(seal[c],(28,21)) #128,128 pivot -> palm156,149
 canvas.alpha_composite(body[b],(96,40))
 if s is not None:canvas.alpha_composite(smoke[s],(28,-59)) #128,208 pivot -> same palm/ground
 a=np.array(canvas);assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3])
 timeline.append({'index':i,'time_ms':t,'duration_ms':50,'body':f'body/SE_{b:03}.png','contract':None if c is None else f'contract/{c:03}.png','smoke':None if s is None else f'smoke/{s:03}.png'})
 renders.append(canvas)
meta={'id':'summoning_jutsu_se_art_review','status':'art_review','direction':'SE','body_canvas':[128,128],'foot_anchor':[64,116],
 'palm_contact_px':[60,109],'ground_contact_relative_to_root':[-4,-7],'preview_canvas':[320,256],
 'preview_offsets':{'body':[96,40],'contract':[28,21],'smoke':[28,-59]},'duration_ms':2600,
 'events_ms':{'palm_slam':450,'contract_full':700,'smoke_start':1100,'spawn_under_smoke':1450,'smoke_clear':1940},
 'clips':{'body':{'frame_size':[128,128],'steps':[{'frame':f'body/SE_{i:03}.png','duration_ms':ms} for i,ms in steps],'loop':False},
 'contract':{'frame_size':[256,256],'pivot':[128,128],'frames':[f'contract/{i:03}.png' for i in range(6)],'duration_ms':[50,50,50,50,50,100],'hold_last':True,'z':'ground_below_actor'},
 'smoke':{'frame_size':[256,256],'pivot':[128,208],'frames':[f'smoke/{i:03}.png' for i in range(12)],'duration_ms':[70]*12,'loop':False,'z':'above_actor','last_frame_clear':True}},
 'future_summon':{'ground_anchor_relative_to_actor':[-4,-7],'content':None,'suggested_reveal_ms':1940},'timeline':timeline,'runtime_integrated':False}
(ROOT/'summoning.json').write_text(json.dumps(meta,indent=2)+'\n')
def exportgif(name,images,ms,scale=2):
 out=[]
 for im in images:
  bg=matte.copy();bg.alpha_composite(im);out.append(bg.convert('RGB').resize((640,512),Image.Resampling.NEAREST))
 out[0].save(PRE/name,save_all=True,append_images=out[1:],duration=ms,loop=0,disposal=2,optimize=False)
exportgif('summoning.gif',renders,50);exportgif('summoning-half-speed.gif',renders,100)
for layer,ims,offset,durations in [('body',body,(96,40),200),('contract',seal,(28,21),[50,50,50,50,50,650]),('smoke',smoke,(28,-59),70)]:
 if layer=='body':ims=[body[body_index(i*50)] for i in range(52)];durations=50
 canvases=[]
 for im in ims:
  c=Image.new('RGBA',(320,256));c.alpha_composite(im,offset);canvases.append(c)
 exportgif(f'{layer}-only.gif',canvases,durations)
keys=[(2,'HAND SIGNS'),(6,'WINDUP'),(9,'ONE PALM: GROUND CONTACT'),(11,'BLACK INK SPREAD'),(15,'LARGE GROUND CONTRACT'),(20,'CONTRACT HOLD / RECOVERY'),(22,'DELAYED SMOKE START'),(26,'SMOKE EXPANDS'),(29,'FUTURE SUMMON UNDER COVER'),(34,'SMOKE BREAKUP'),(39,'SMOKE CLEAR / EMPTY ANCHOR'),(48,'HOLD / REVIEW RESET')]
sheet=Image.new('RGB',(1280,888),'#18242b');d=ImageDraw.Draw(sheet);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
for n,(i,label) in enumerate(keys):
 x=n%4*320;y=n//4*296;bg=matte.copy();bg.alpha_composite(renders[i]);sheet.paste(bg.convert('RGB'),(x,y+40));d.text((x+8,y+3),label,fill='white',font=font);d.text((x+8,y+21),f'{i*50/1000:.2f}s',fill='#9ec8d1',font=font)
sheet.save(PRE/'contact-sheet.png')
qa={'result':'PASS','body_frames':5,'contract_frames':6,'smoke_frames':12,'binary_alpha':True,'clear_smoke_terminator':True,'no_composite_clipping':True,'contract_bounds':ink_bounds,'palm_alpha':255,'runtime_changes':False,'body_sha256':{f'SE_{i:03}.png':hashlib.sha256((ROOT/f'body/SE_{i:03}.png').read_bytes()).hexdigest() for i in range(5)}}
(SRC/'qa.json').write_text(json.dumps(qa,indent=2)+'\n');print('PASS:',json.dumps(qa))
