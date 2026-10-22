"""Deterministic processing of generated body/VFX and approved locomotion. No creative drawing."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math,hashlib
ROOT=Path(__file__).resolve().parents[3]
PACK=ROOT/'assets/characters/player/kunai_primary_se';PACK.mkdir(parents=True,exist_ok=True)
OUT=ROOT/'docs/visuals/kunai-primary';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'assets/characters/player/source/kunai-primary-se'
RES=lambda p:'res://'+p.relative_to(ROOT).as_posix()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ref=Image.open(ROOT/'assets/characters/player/sprites/production/idle/SE_000.png').convert('RGBA')
colors=sorted(set((r,g,b) for r,g,b,a in ref.get_flattened_data() if a==255))
palette=Image.new('RGB',(len(colors),1));palette.putdata(colors);palette=palette.quantize(colors=min(64,len(colors)),dither=Image.Dither.NONE)
# Measured right-fist centers in raw cells sampled to128. Shared128px extraction, no fit scaling.
specs={
 'light2':dict(indices=list(range(6)),hands=[(71,63),(59,64),(92,90),(89,76),(62,75),(64,75)],angles=[145,155,110,125,145,145],holds=[50,50,100/3,100/3,275/3,275/3],contact=2,active=[2,3]),
 'light3':dict(indices=list(range(6)),hands=[(52,69),(38,75),(78,70),(107,82),(85,80),(53,86)],angles=[145,155,100,70,100,110],holds=[75,75,125/3,125/3,125,125],contact=2,active=[2,3]),
 # Source3 clipped at cell edge, so omit it; source4 has a disconnected neighboring fragment removed.
 'dash_attack':dict(indices=[0,1,2,4,5],hands=[(38,76),(58,70),(118,76),(52,66),(67,61)],angles=[150,20,20,120,130],holds=[50,50,250/3,325/3,325/3],contact=2,active=[2])}
animations={};qc={};provenance={}
for action,spec in specs.items():
 rawpath=SOURCE/(action+'-raw.png');raw=Image.open(rawpath).convert('RGBA');assert raw.size==(1536,1024)
 frames=[];t=0
 for n,i in enumerate(spec['indices']):
  cell=raw.crop((i%3*512,i//3*512,(i%3+1)*512,(i//3+1)*512)).resize((128,128),Image.Resampling.NEAREST)
  alpha=cell.getchannel('A').point(lambda a:255 if a>=160 else 0)
  if action=='dash_attack' and i==4:
   # Detached neighbor-hand bleed at left border; retain the actual character's connected silhouette.
   for y in range(128):
    for x in range(8):alpha.putpixel((x,y),0)
  cell=cell.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');cell.putalpha(alpha)
  # Explicit planted-sole registration; x/pelvis never centered per frame; no per-frame rescaling.
  sole=cell.getbbox()[3]-1;dy=116-sole
  body=Image.new('RGBA',(128,128));body.alpha_composite(cell,(0,dy))
  hand=spec['hands'][n];hand=[hand[0],hand[1]+dy]
  # Snap measurement to an opaque glove pixel within2px; reject a detached socket.
  candidates=[(x,y) for x in range(max(0,hand[0]-2),min(128,hand[0]+3)) for y in range(max(0,hand[1]-2),min(128,hand[1]+3)) if body.getpixel((x,y))[3]==255]
  assert candidates,(action,n,hand)
  hand=list(min(candidates,key=lambda q:(q[0]-hand[0])**2+(q[1]-hand[1])**2))
  target=PACK/'body'/action/f'SE_{n:03}.png';target.parent.mkdir(parents=True,exist_ok=True);body.save(target)
  frame=dict(frame_index=n,source_frame=i,body_frame=RES(target),right_hand_px=hand,weapon_angle_deg=spec['angles'][n],weapon_layer='behind' if action=='light3' and n==1 else 'front',hand_occlusion_rect=[hand[0]-2,hand[1]-2,5,5],start_ms=t,duration_ms=spec['holds'][n],contact=n==spec['contact'],phase='active' if n in spec['active'] else 'startup' if n<spec['contact'] else 'recovery',root_registration_px=[0,dy],body_sha256=sha(target),swipe_frame=2 if n==spec['contact'] else 3 if n in spec['active'] else 4 if n==spec['active'][-1]+1 else -1)
  frames.append(frame);t+=frame['duration_ms']
 animations[action]=dict(duration_ms=t,loop=False,authored_fps=24,frames=frames,contact_frames=[spec['contact']],hitbox_active_frames=spec['active'],transition_ready_frames=list(range(spec['active'][-1]+1,len(frames))))
 provenance[action]={'raw':RES(rawpath),'raw_sha256':sha(rawpath),'source_indices':spec['indices'],'processing':'fixed512-to128 nearest; shared approved player palette; alpha160; explicit planted sole translation, fixed x; no per-frame fit or interpolation'}
# Retain the existing independent one-handed opening thrust.
old=json.loads((ROOT/'assets/characters/player/kunai_poc/kunai-light1.art.json').read_text());frames=[]
for f in old['frames']:
 f=f.copy();f['body_frame']=RES(ROOT/'assets/characters/player/kunai_poc'/f['body_frame']);f['swipe_frame']=2 if f['frame_index']==2 else 3 if f['frame_index']==3 else -1;frames.append(f)
animations['light1']=dict(duration_ms=300,loop=False,authored_fps=24,frames=frames,contact_frames=[2],hitbox_active_frames=[2,3],transition_ready_frames=[4,5])
f=frames[0].copy();f.update(frame_index=0,start_ms=0,duration_ms=400,contact=False,phase='guard',swipe_frame=-1)
animations['guard']=dict(duration_ms=400,loop=True,frames=[f])
# Socket measurements for approved SE body-only dodge and normal run. No duplicate artwork export.
dodge_hands=[(49,74),(46,77),(44,77),(85,68),(85,68),(85,68),(85,68),(68,79),(45,78),(45,71),(51,78),(50,78)]
run_hands=[(53,82),(49,73),(48,67),(47,63),(50,72),(55,76),(69,65),(70,61),(61,70),(51,74),(48,67),(47,63),(50,72),(55,76),(69,65),(70,61),(61,70),(51,74),(48,67),(47,63)]
for action,hands in [('dodge',dodge_hands),('run',run_hands)]:
 frames=[];t=0
 for n,h in enumerate(hands):
  path=ROOT/f'assets/characters/player/sprites/production/{action}/SE_{n:03}.png';body=Image.open(path).convert('RGBA')
  # Manual anatomical selection with small opaque-glove registration, no body modification.
  points=[(x,y) for x in range(h[0]-4,h[0]+5) for y in range(h[1]-4,h[1]+5) if 0<=x<128 and 0<=y<128 and body.getpixel((x,y))[3]==255]
  assert points,(action,n,h)
  hand=list(min(points,key=lambda q:(q[0]-h[0])**2+(q[1]-h[1])**2))
  duration=250/3
  frames.append(dict(frame_index=n,body_frame=RES(path),right_hand_px=hand,weapon_angle_deg=140 if action=='run' else ([120,100,70,45,45,45,45,100,120,120,130,140][n]),weapon_layer='front',hand_occlusion_rect=[hand[0]-2,hand[1]-2,5,5],start_ms=t,duration_ms=duration,phase=action,contact=False,swipe_frame=-1));t+=duration
 animations[action]=dict(duration_ms=t,loop=action=='run',frames=frames)
# Six independent compact silver swipes. Fixed scale across all cells; trim generated glow by alpha threshold.
raw=Image.open(SOURCE/'swipe-raw.png').convert('RGBA');vfx=[]
for i in range(6):
 c=raw.crop((i%3*512,i//3*512,(i%3+1)*512,(i//3+1)*512)).resize((80,80),Image.Resampling.NEAREST)
 pixels=[]
 for r,g,b,a in c.get_flattened_data():
  if a<180:pixels.append((0,0,0,0));continue
  level=min([25,70,125,190,235,255],key=lambda n:abs(n-(r+g+b)//3));pixels.append((level,level,level,255))
 c.putdata(pixels);f=Image.new('RGBA',(128,128));f.alpha_composite(c,(24,24));path=PACK/'vfx'/f'swipe_{i:03}.png';path.parent.mkdir(parents=True,exist_ok=True);f.save(path);vfx.append(RES(path))
sequence=[{'animation':'guard'},{'animation':'light1','end_ms':150},{'animation':'light2','end_ms':200},{'animation':'light3'},{'animation':'dodge','end_ms':920},{'animation':'dash_attack'},{'animation':'run'}]
# Stable explicit order for selectors, with standard gameplay-compatible action labels.
animations={k:animations[k] for k in ['guard','light1','light2','light3','dodge','dash_attack','run']}
data=dict(schema='shinobi_kunai_se_art_proof_v1',status='owner_review_required_before_eight_directions',direction='SE',frame_size=[128,128],foot_anchor=[64,116],body_height_px=104,weapon={'texture':'res://assets/weapons/kunai/black_kunai.png','grip_pivot_px':[25,31],'independent':True,'default_melee_in_this_proof':True},vfx={'frames':vfx,'fps':30,'independent':True},animations=animations,sequence=sequence,source=provenance,gameplay_integrated=False,timing_status='matches existing AttackDef standalone durations; nominal buffered chain exits light1 at150ms, light2 at200ms, dodge at920ms within current gates; approved12FPS locomotion; no hit logic changed',default_review_speed=.5)
(PACK/'kunai-primary.art.json').write_text(json.dumps(data,indent=2)+'\n')
# Layered PNG/GIF previews. All drawing below is labels, not creative sprite content.
weapon=Image.open(ROOT/'assets/weapons/kunai/black_kunai.png').convert('RGBA')
def compose(f):
 body=Image.open(ROOT/f['body_frame'][6:]).convert('RGBA');stage=Image.new('RGBA',(192,192));hand=f['right_hand_px'];hx,hy=hand[0]+32,hand[1]+32;rad=math.radians(f['weapon_angle_deg']);c,s=math.cos(rad),math.sin(rad)
 layer=weapon.transform((192,192),Image.Transform.AFFINE,(c,s,25-c*hx-s*hy,-s,c,31+s*hx-c*hy),Image.Resampling.NEAREST)
 if f['weapon_layer']=='behind':stage.alpha_composite(layer)
 stage.alpha_composite(body,(32,32))
 if f['weapon_layer']=='front':stage.alpha_composite(layer)
 x,y=hand;stage.alpha_composite(body.crop((x-2,y-2,x+3,y+3)),(x+30,y+30))
 if f['swipe_frame']>=0:stage.alpha_composite(Image.open(ROOT/vfx[f['swipe_frame']][6:]),(hx+10-64,hy+5-64))
 return stage
allframes=[];holds=[];names=[]
for step in sequence:
 for f in animations[step['animation']]['frames']:
  if f['start_ms']>=step.get('end_ms',1e9)-.001:break
  stage=compose(f);panel=Image.new('RGB',(384,424),'#26313d');panel.paste(stage.resize((384,384),Image.Resampling.NEAREST),(0,40),stage.resize((384,384),Image.Resampling.NEAREST));draw=ImageDraw.Draw(panel);draw.text((8,6),f"{step['animation']} / {f['frame_index']} / {f['phase']}"+(' CONTACT' if f['contact'] else ''),fill='#ffd17b');draw.text((8,22),'128px body / separate black kunai / SE proof',fill='white');allframes.append(panel);holds.append(min(f['duration_ms'], step.get('end_ms',1e9)-f['start_ms']));names.append(step['animation'])
for name,speed in [('normal',1),('half',.5)]:
 # Quantize cumulative times to10ms ticks to prevent drift over the variable-duration sequence.
 ticks=[0];acc=0
 for h in holds:acc+=h/speed;ticks.append(round(acc/10))
 durations=[max(10,(ticks[i+1]-ticks[i])*10) for i in range(len(holds))]
 allframes[0].save(OUT/f'kunai-sequence-{name}.gif',save_all=True,append_images=allframes[1:],duration=durations,loop=0,optimize=False)
contact=Image.new('RGB',(384*6,424*4),'#26313d')
for row,action in enumerate(['light1','light2','light3','dash_attack']):
 for col,f in enumerate(animations[action]['frames']):
  panel=Image.new('RGB',(384,424),'#26313d');stage=compose(f).resize((384,384),Image.Resampling.NEAREST);panel.paste(stage,(0,40),stage);ImageDraw.Draw(panel).text((8,10),f"{action} / {f['frame_index']} / {f['phase']} {f['duration_ms']:.1f}ms",fill='white');contact.paste(panel,(col*384,row*424))
contact.save(OUT/'attack-contact.png')
qc={'body_frames_new':sum(len(animations[a]['frames']) for a in specs),'source_clipped_dash_frame_omitted':3,'schema':'shared128px no per-frame scale; grounded sole translation'}
for action,anim in animations.items():
 seen=[]
 for f in anim['frames']:
  p=ROOT/f['body_frame'][6:];im=Image.open(p);assert im.size==(128,128) and im.mode=='RGBA';assert set(im.getchannel('A').get_flattened_data())<={0,255};assert im.getpixel(tuple(f['right_hand_px']))[3]==255
  seen.append(sha(p))
 qc[action]={'frames':len(seen),'unique':len(set(seen)),'duration_ms':anim['duration_ms'],'contact_frames':anim.get('contact_frames',[])}
(OUT/'asset-qc.json').write_text(json.dumps(qc,indent=2)+'\n')
print('PASS:17 new weaponless128RGBA body frames; all layered sockets opaque; seven proof actions; six independent VFX; native and half-speed sequence previews')
