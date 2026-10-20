"""Register/cut/composite original PixelLab art. Never generate or rescale body pixels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,hashlib

ROOT=Path(__file__).resolve().parents[1]
PLAYER=ROOT.parents[1]
SRC=ROOT/'source'
PREVIEW=PLAYER/'previews/running-jutsu'
SPRINT=PLAYER/'sprites/production/sprint'
for name in ['body','motion','lightning']:(ROOT/name).mkdir(exist_ok=True)
PREVIEW.mkdir(parents=True,exist_ok=True)

def shift(im,xy):
 out=Image.new('RGBA',im.size);out.paste(im,tuple(xy[:2]));return out
def register(target,candidate,rect):
 b=np.array(target);q=np.array(candidate);x0,y0,x1,y1=rect
 mask=np.zeros((128,128),bool);mask[y0:y1,x0:x1]=b[y0:y1,x0:x1,3]>0
 # The landmarks are measured, not independently recentered bounding boxes.
 opts=[]
 for dy in range(-12,13):
  for dx in range(-12,13):
   v=np.array(shift(candidate,(dx,dy)));diff=np.abs(b[:,:,:3].astype(int)-v[:,:,:3].astype(int)).sum(2)
   score=int(((diff<36)&mask&(v[:,:,3]>0)).sum())
   opts.append((score,-abs(dx)-abs(dy),dx,dy))
 score,_,dx,dy=max(opts);return [dx,dy],score,int(mask.sum())

base=Image.open(SPRINT/'SE_000.png').convert('RGBA')
poses=[];registration=[]
for i in range(4):
 im=Image.open(SRC/f'pose-{i}.png').convert('RGBA')
 h,hs,hn=register(base,im,(59,22,97,49));f,fs,fn=register(base,im,(35,92,90,120))
 assert h==f,('inconsistent source placement',i,h,f)
 assert hs/hn>.75 and fs/fn>.75,(i,hs,hn,fs,fn)
 poses.append(shift(im,h));registration.append({'pose':i,'shift':h,'head_match':[hs,hn],'feet_match':[fs,fn]})

smears=[shift(Image.open(SRC/f'smear-{c}.png').convert('RGBA'),registration[i]['shift']) for i,c in enumerate('ab')]
fxsheet=Image.open(SRC/'lightning-sheet.png').convert('RGBA');assert fxsheet.size==(256,192)
fx=[fxsheet.crop(((i%4)*64,(i//4)*64,(i%4+1)*64,(i//4+1)*64)) for i in range(12)]
assert len({im.tobytes() for im in fx})==12
for im in fx:
 a=np.array(im);assert set(np.unique(a[:,:,3]))=={0,255} and np.any(a[:,:,3])
 assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3])
for i,im in enumerate(fx):im.save(ROOT/f'lightning/charge_{i:02}.png')
for i,im in enumerate(smears):im.save(ROOT/f'motion/multiple_{i:02}.png')

def beat(i):
 if i<9:return 'running',None,None,None
 if i<11:return 'key_cross',0,None,None
 if i==11:return 'smear_a',1,0,None
 if i<14:return 'key_meet',1,None,None
 if i==14:return 'smear_b',0,1,None
 if i==15:return 'separation_flash',2,None,0
 if i<23:return 'lightning_charge',2,None,2+(i-16)%4
 if i==23:return 'explosive_thrust',3,None,6
 if i==24:return 'impact',3,None,8
 if i<29:return 'electrical_follow_through',3,None,[9,10,11,10][i-25]
 if i<33:return 'running_recovery',2,None,0 if i==29 else None
 return 'running',None,None,None

frames=[];renders=[];body_renders=[];records=[]
matte=Image.new('RGBA',(192,192),'#202d39')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for i in range(50):
 # Native30Hz inspection clock, approved12FPS sprint phase. No phase reset at any jutsu beat.
 phase=(i*2)//5
 original=Image.open(SPRINT/f'SE_{phase:03}.png').convert('RGBA')
 stage,key,multiple,electric=beat(i)
 delta,score,total=register(original,base,(59,22,97,49))
 assert score/total>.35,(i,delta,score,total)
 if key is None:body=original.copy()
 else:
  upper=shift(poses[key],delta)
  body=upper.copy();body.paste(original.crop((0,80,128,128)),(0,80))
  # Spear-hand extends into empty margin beside the legs; never erase or move leg pixels.
  if key==3:
   b,u,o=np.array(body),np.array(upper),np.array(original)
   yy,xx=np.indices((128,128));margin=(xx>=94)&(yy>=80)&(yy<96)&(o[:,:,3]==0)
   b[margin]=u[margin];body=Image.fromarray(b)
 # All actual lower-body pixels stay exact, plus the background outside the hand overhang.
 a,o=np.array(body),np.array(original);yy,xx=np.indices((128,128))
 protected=(yy>=80)&((o[:,:,3]>0)|(xx<94)|(yy>=96))
 assert np.array_equal(a[protected],o[protected])
 a=np.array(body);assert set(np.unique(a[:,:,3]))<={0,255}
 assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3])
 rel=f'body/SE_{i:03}.png';body.save(ROOT/rel)
 body_canvas=Image.new('RGBA',(192,192));body_canvas.alpha_composite(body,(32,32))
 canvas=body_canvas.copy()
 if multiple is not None:canvas.alpha_composite(shift(smears[multiple],delta),(32,32))
 hand=None
 if electric is not None:
  hand=[(38 if key==2 else 105)+delta[0],(69 if key==2 else 81)+delta[1]]
  assert body.getpixel(tuple(hand))[3]==255,(i,'lightning anchor outside hand',hand)
  canvas.alpha_composite(fx[electric],tuple(hand)) #32px body offset cancels32px effect pivot
 assert not np.any(np.array(canvas)[[0,-1],:,3]) and not np.any(np.array(canvas)[:,[0,-1],3])
 frame={'index':i,'stage':stage,'duration_ms':1000/30,'body':rel,
  'sprint_source':f'../../sprites/production/sprint/SE_{phase:03}.png','sprint_phase':phase,
  'upper_pose':key,'upper_registration_px':delta,'motion':None if multiple is None else f'motion/multiple_{multiple:02}.png',
  'lightning':None if electric is None else f'lightning/charge_{electric:02}.png',
  'lightning_pivot':[32,32],'lightning_hand_px':hand,'body_sha256':hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()}
 frames.append(frame);renders.append(canvas);body_renders.append(body_canvas)

meta={'id':'running_jutsu_se_review','status':'art_review','direction':'SE','frame_size':[128,128],
 'foot_anchor':[64,116],'body_height_px':104,'timeline_hz':30,'source_sprint_fps':12,
 'duration_ms':50000/30,'loop':True,'lower_body_protected_rect':[0,80,94,128],
 'spear_hand_empty_margin_rect':[94,80,128,96],'all_opaque_sprint_leg_pixels_protected':True,
 'charge_posture':'same near arm swept backward behind hip; lightning trails behind as in owner animated GIF',
 'lightning_independent':True,'lightning_size':[64,64],'motion_overlay_intentional_alpha':[90,120],
 'technique':'2 hand-sign silhouettes,2 one-frame multiples,1 separation/charge pose,1 thrust pose; no generated in-betweens',
 'runtime_integrated':False,'frames':frames}
(ROOT/'jutsu_review.json').write_text(json.dumps(meta,indent=2)+'\n')
(SRC/'registration.json').write_text(json.dumps(registration,indent=2)+'\n')

def gif(name,images,scale=3,speed=1):
 # Cumulative rounding preserves timing; GIF ticks are10ms. PNG/source timing remains exact.
 ts=[round(i*1000/30/speed/10)*10 for i in range(51)]
 durations=[ts[i+1]-ts[i] for i in range(50)]
 out=[]
 for im in images:
  bg=matte.copy();bg.alpha_composite(im);out.append(bg.convert('RGB').resize((192*scale,192*scale),Image.Resampling.NEAREST))
 out[0].save(PREVIEW/name,save_all=True,append_images=out[1:],duration=durations,loop=0,optimize=False,disposal=2)
gif('running-jutsu.gif',renders)
gif('running-jutsu-half-speed.gif',renders,speed=.5)
gif('body-only.gif',body_renders)

keys=[(5,'SPRINT'),(9,'KEY: CROSS'),(11,'SMEAR / MULTIPLES A'),(12,'KEY: HANDS MEET'),(14,'SMEAR / MULTIPLES B'),(15,'SEPARATION / FLASH'),(19,'LIGHTNING CHARGE'),(23,'EXPLOSIVE THRUST'),(24,'IMPACT'),(26,'ELECTRICAL FOLLOW-THROUGH'),(30,'RUNNING RECOVERY'),(36,'SPRINT RESUMES')]
sheet=Image.new('RGB',(4*384,3*430),'#17212b');d=ImageDraw.Draw(sheet)
for n,(i,label) in enumerate(keys):
 x=n%4*384;y=n//4*430
 bg=matte.copy();bg.alpha_composite(renders[i]);sheet.paste(bg.convert('RGB').resize((384,384),Image.Resampling.NEAREST),(x,y+40))
 d.text((x+12,y+4),f'{i:02}  {label}',fill='#d9efff',font=font)
 d.text((x+12,y+22),f'{i/30:.3f}s | sprint phase{frames[i]["sprint_phase"]:02}',fill='#9bb4c9',font=font)
sheet.save(PREVIEW/'contact-sheet.png')
(SRC/'qa.json').write_text(json.dumps({'result':'PASS','native_body_frames':50,'unique_upper_key_poses':4,'smear_drawings':2,'lightning_frames':12,'lower_body_exact_all50':True,'sprint_phases':list(range(20)),'body_alpha':'binary','effect_alpha':'binary','motion_alpha':'intentional faint multiples','no_clipping':True,'loop_ms':meta['duration_ms'],'gif_loop_ms':1670},indent=2)+'\n')
print('PASS:50timeline frames,20unchanged running phases,4upper keys,2smears,12independent lightning frames; no clipping. Previews:',PREVIEW)
