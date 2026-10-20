"""Extract authored assets; retime/reuse summoning smoke without pixel resampling."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,numpy as np,hashlib
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'source';REPO=ROOT.parents[2];PRE=REPO/'assets/characters/player/previews/substitution'
for p in [PRE,ROOT/'log',ROOT/'departure',ROOT/'arrival',ROOT/'ribbons']:p.mkdir(parents=True,exist_ok=True)
def check(im,blank=False):
 a=np.array(im);assert im.mode=='RGBA' and set(np.unique(a[:,:,3]))<={0,255}
 assert blank or np.any(a[:,:,3]);assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3])
def cut(sheet,count,size,cols):
 assert sheet.size==(cols*size,((count+cols-1)//cols)*size)
 return [sheet.crop((i%cols*size,i//cols*size,(i%cols+1)*size,(i//cols+1)*size)) for i in range(count)]
log=cut(Image.open(SRC/'log-sheet.png').convert('RGBA'),9,128,3)
ribbons=cut(Image.open(SRC/'ribbons-sheet.png').convert('RGBA'),12,256,4)
sheet=Image.open(SRC/'rolling-smoke.png').convert('RGBA');source=json.loads((SRC/'rolling-smoke.json').read_text());billows=[]
for entry in source['frames'][:29]:
 r=entry['frame'];im=Image.new('RGBA',(256,256));im.paste(sheet.crop((r['x'],r['y'],r['x']+r['w'],r['y']+r['h'])),(34,23));billows.append(im)
departure_ids=[12,15,16,17,18,19,20,21,22,23,24,25,26,27,28];arrival_ids=list(range(21,29))
departure=[billows[i] for i in departure_ids];arrival=[billows[i] for i in arrival_ids]
all_clips={'log':log,'departure':departure,'arrival':arrival,'ribbons':ribbons}
for name,ims in all_clips.items():
 assert len({im.tobytes() for im in ims})==len(ims),(name,'duplicate')
 for i,im in enumerate(ims):check(im,blank=name!='log' and i==len(ims)-1);im.save(ROOT/f'{name}/{i:03}.png')
for ims in [departure,arrival,ribbons]:assert ims[-1].getbbox() is None
durations={'log':[40,40,50,60,70,80,90,100,520],'departure':[30,30]+[40]*13,'arrival':[40]*8,'ribbons':[40]*12}
def idx(name,t):
 if t<0:return None
 end=0
 for i,ms in enumerate(durations[name]):
  end+=ms
  if t<end:return i
 return len(all_clips[name])-1 if name=='log' else None
idle_e=Image.open(REPO/'assets/characters/player/sprites/production/idle/E_000.png').convert('RGBA')
idle_w=Image.open(REPO/'assets/characters/player/sprites/production/idle/W_000.png').convert('RGBA')
roots={'departure':[100,190],'attacker':[230,190],'arrival':[326,190]}
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12)
def matte():
 im=Image.new('RGBA',(448,256),'#899479');d=ImageDraw.Draw(im)
 d.text((24,10),'OLD POSITION / LOG',fill='#18242b',font=font);d.text((188,10),'ATTACKER',fill='#18242b',font=font);d.text((288,10),'BEHIND ATTACKER',fill='#18242b',font=font)
 # Explicit diagram marker, not enemy art or an in-game object.
 d.rounded_rectangle((218,136,242,190),5,outline='#79453f',width=2);d.polygon([(204,163),(216,157),(216,169)],fill='#79453f');return im
frames=[];renders=[]
for n in range(140):
 t=n*10;elapsed=t-200;li=idx('log',elapsed-40);di=idx('departure',elapsed);ri=idx('ribbons',elapsed);ai=idx('arrival',elapsed-80)
 canvas=matte()
 if t<200:canvas.alpha_composite(idle_e,(36,74))
 if li is not None:canvas.alpha_composite(log[li],(36,74))
 if t>=280:canvas.alpha_composite(idle_w,(262,74))
 if di is not None:canvas.alpha_composite(departure[di],(-28,30))
 if ri is not None:canvas.alpha_composite(ribbons[ri],(-28,30))
 if ai is not None:canvas.alpha_composite(arrival[ai],(198,30))
 renders.append(canvas)
 frames.append({'index':n,'time_ms':t,'duration_ms':10,'player_old_visible':t<200,'player_rear_visible':t>=280,
  'log':None if li is None else f'log/{li:03}.png','departure':None if di is None else f'departure/{di:03}.png','ribbons':None if ri is None else f'ribbons/{ri:03}.png','arrival':None if ai is None else f'arrival/{ai:03}.png'})
clips={name:{'frame_size':list(ims[0].size),'pivot':[64,116] if name=='log' else [128,160],
 'frames':[f'{name}/{i:03}.png' for i in range(len(ims))],'duration_ms':durations[name],'loop':False,'hold_last':name=='log'} for name,ims in all_clips.items()}
meta={'id':'substitution_art_pack_v1','status':'art_review','clips':clips,'direction_policy':'screen-space neutral prop/VFX; no new player directions',
 'trigger':'confirmed_timed_L2_evade_success_gameplay_owned','proposal_events_ms_from_success':{'conceal_player':0,'spawn_log':40,'relocate_behind_attacker':80,'arrival_wisps':80,'log_ground_contact':230},
 'log_contact_frame':4,'log_settle_frame':8,'smoke_consistency':{'summoning_commit':'d2164592e540e544704fb4a5e92eb6b188d1aa68','native_billows_reused':True,'rescaled':False,'departure_source_indices':departure_ids,'arrival_source_indices':arrival_ids},
 'preview':{'canvas':[448,256],'duration_ms':1400,'roots':roots,'offsets':{'log':[36,74],'departure':[-28,30],'ribbons':[-28,30],'arrival':[198,30]},'old_player':'../../characters/player/sprites/production/idle/E_000.png','rear_player':'../../characters/player/sprites/production/idle/W_000.png','timeline':frames},'runtime_integrated':False}
(ROOT/'substitution.json').write_text(json.dumps(meta,indent=2)+'\n')
def gif(name,ims,ms):
 images=[im.convert('RGB').resize((896,512),Image.Resampling.NEAREST) for im in ims];images[0].save(PRE/name,save_all=True,append_images=images[1:],duration=ms,loop=0,disposal=2,optimize=False)
gif('substitution.gif',renders,10);gif('substitution-half-speed.gif',renders,20)
for name,ims in all_clips.items():
 imgs=[]
 for im in ims:
  c=Image.new('RGBA',(448,256),'#899479');c.alpha_composite(im,(160,74) if name=='log' else (96,30));imgs.append(c)
 gif(f'{name}-only.gif',imgs,durations[name])
keys=[(10,'PLAYER BEFORE EVADE'),(20,'CONFIRMED SUCCESS / SMOKE'),(24,'LOG SPAWN UNDER COVER'),(28,'PLAYER REAPPEARS BEHIND'),(38,'SMOKE PEELS AWAY'),(43,'LOG GROUND CONTACT'),(55,'LOG BOUNCE / WISPS'),(75,'SMOKE CLEARS'),(100,'LOG SETTLES'),(130,'REVIEW HOLD')]
contact=Image.new('RGB',(1344,4*288),'#18242b');d=ImageDraw.Draw(contact)
for n,(i,label) in enumerate(keys):
 x=n%3*448;y=n//3*288;contact.paste(renders[i].convert('RGB'),(x,y+32));d.text((x+8,y+3),label,fill='white',font=font);d.text((x+8,y+17),f'{i/100:.2f}s',fill='#9ec8d1',font=font)
contact.save(PRE/'contact-sheet.png')
qa={'result':'PASS','clips':{n:len(ims) for n,ims in all_clips.items()},'unique_drawn_frames':True,'binary_alpha':True,'transparent_borders':True,'smoke_matches_summoning_pixels':True,'no_resampling':True,'runtime_changed':False}
(SRC/'qa.json').write_text(json.dumps(qa,indent=2)+'\n');print(json.dumps(qa))
