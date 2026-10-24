"""Extract authored sheets; register fixed feet and supply hand-measured weapon tracks."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,math,numpy as np
from process_common import clean,extract,NORMALIZED,OFFSETS
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
OLD=json.loads((ROOT/'assets/characters/player/kunai_primary_se/kunai-primary.art.json').read_text())
ACTIONS=['light1','light2','light3','dash_attack','guard']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def export():
 config=json.loads((HERE/'sources.json').read_text());qc={};characters={'player':{'SE':{a:OLD['animations'][a]['frames'] for a in ACTIONS}},'bandit':{}}
 for key,spec in config.items():
  character,direction,kind=key.split('-');base=ROOT/f'assets/characters/{character}/kunai_eight';source=base/'source'/spec['file'];im=Image.open(source)
  cols,rows=(4,5) if kind=='combo' else (3,2)
  scale=160/(im.width/cols);frames=[]
  # One shared standing-equivalent scale; no per-pose bbox fits. Restore each character's palette.
  refpath=f'assets/characters/player/sprites/production/idle/{direction}_000.png' if character=='player' else f'assets/characters/bandit/sprites/idle/{direction}_000.png'
  refs=[Image.open(ROOT/refpath).convert('RGBA')]
  if character=='player':refs += [Image.open(ROOT/f['body_frame'].removeprefix('res://')).convert('RGBA') for a in ACTIONS for f in OLD['animations'][a]['frames']]
  colors=sorted({p[:3] for r in refs for p in r.get_flattened_data() if p[3]==255})
  pal=Image.new('RGB',(len(colors),1));pal.putdata(colors);pal=pal.quantize(colors=min(256,len(colors)),dither=Image.Dither.NONE)
  for f in extract(source)[0]:
   alpha=f.getchannel('A');f=f.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');f.putalpha(alpha);frames.append(f)
  character_dirs=characters[character].setdefault(direction,{})
  mapping=spec.get('indices',{'light1':list(range(6)),'light2':list(range(6,12)),'light3':list(range(12,18)),'guard':[18]} if kind=='combo' else {'dash_attack':list(range(5))} if kind=='dash' else {kind:list(range(6))})
  for action,indices in mapping.items():
   poses=[]
   for n,i in enumerate(indices):
    f=frames[i];path=base/'body'/action/f'{direction}_{n:03}.png';path.parent.mkdir(parents=True,exist_ok=True);f.save(path)
    pose=dict(OLD['animations'][action]['frames'][n]);h=spec['hands'][i]
    points=[(x,y) for x in range(max(0,h[0]-2),min(128,h[0]+3)) for y in range(max(0,h[1]-2),min(128,h[1]+3)) if f.getpixel((x,y))[3]==255]
    assert points,(key,i,'detached hand',h)
    hand=list(min(points,key=lambda q:(q[0]-h[0])**2+(q[1]-h[1])**2))
    facing={'E':0,'SE':45,'S':90,'NE':-45,'N':-90}[direction]
    pose.update(body_frame='res://'+path.relative_to(ROOT).as_posix(),body_sha256=sha(path),right_hand_px=hand,weapon_angle_deg=spec['angles'][i],weapon_layer='behind' if i in spec.get('behind',[]) else 'front',hand_occlusion_rect=[hand[0]-2,hand[1]-2,5,5],source_sheet=source.relative_to(ROOT).as_posix(),source_frame=i,swipe_rotation_deg=facing-45,swipe_offset_px=[round(math.cos(math.radians(facing))*11,3),round(math.sin(math.radians(facing))*11,3)]);poses.append(pose)
   character_dirs[action]=poses
   qc[key+'-'+action]={'frames':len(poses),'unique':len({p['body_sha256'] for p in poses}),'height_range':[min(frames[i].getbbox()[3]-frames[i].getbbox()[1] for i in indices),max(frames[i].getbbox()[3]-frames[i].getbbox()[1] for i in indices)],'sole_y':116,'source_sha256':sha(source)}
 for character,dirs in characters.items():
  for dst,src in [('W','E'),('NW','NE'),('SW','SE')]:
   if src not in dirs:continue
   mirrored={}
   for action,poses in dirs[src].items():
    result=[]
    for n,p in enumerate(poses):
     raw=Image.open(ROOT/p['body_frame'].removeprefix('res://')).convert('RGBA');f=Image.new('RGBA',(128,128));f.paste(raw.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(1,0))
     assert f.getbbox() and f.getbbox()[3]==raw.getbbox()[3]
     path=ROOT/f'assets/characters/{character}/kunai_eight/body/{action}/{dst}_{n:03}.png';path.parent.mkdir(parents=True,exist_ok=True);f.save(path)
     q=dict(p);hand=[128-p['right_hand_px'][0],p['right_hand_px'][1]]
     q.update(body_frame='res://'+path.relative_to(ROOT).as_posix(),body_sha256=sha(path),right_hand_px=hand,weapon_angle_deg=180-p['weapon_angle_deg'],hand_occlusion_rect=[hand[0]-2,hand[1]-2,5,5],mirrored_from=src,swipe_rotation_deg={'W':135,'NW':-180,'SW':90}[dst],swipe_offset_px=[-float(p.get('swipe_offset_px',[10,5])[0]),float(p.get('swipe_offset_px',[10,5])[1])]);result.append(q)
    mirrored[action]=result
   dirs[dst]=mirrored
 profiles={a:{k:v for k,v in OLD['animations'][a].items() if k!='frames'} for a in ACTIONS}
 directions=['S','SE','E','NE','N','NW','W','SW']
 data={'schema':1,'frame_size':[128,128],'foot_anchor':[64,116],'profiles':profiles,'weapon':OLD['weapon'],'characters':characters,'directions':directions,'mirrored_directions':{'W':'E','NW':'NE','SW':'SE'},'source_scale_profile':{'normalized_cells':NORMALIZED,'default_normalized_cell':160,'constant_sheet_root_x_offsets':OFFSETS,'resampling':'nearest','body_target':'approved104px standing-equivalent; natural crouch/arm extension permitted; uniform source scale across every sheet'},'status':'owner_requested_eight_direction_review','default_review_speed':.5}
 for character,dirs in characters.items():
  assert set(dirs)==set(directions),(character,list(dirs))
  for direction,actions in dirs.items():
   assert set(actions)==set(ACTIONS),(character,direction,list(actions))
   for action,poses in actions.items():
    assert len(poses)==(1 if action=='guard' else 5 if action=='dash_attack' else 6)
    for p in poses:
     im=Image.open(ROOT/p['body_frame'].removeprefix('res://')).convert('RGBA');assert im.size==(128,128)
     assert im.getpixel(tuple(p['right_hand_px']))[3]==255,(character,direction,action,p['frame_index'])
     assert set(np.unique(np.asarray(im)[:,:,3]))<={0,255}
  manifest_path=ROOT/('assets/characters/player/player_128.manifest.json' if character=='player' else 'assets/characters/bandit/bandit_128.art.json')
  manifest=json.loads(manifest_path.read_text())
  for action in ACTIONS:
   if action=='guard' and character=='player':continue
   name='kunai_guard' if action=='guard' else action
   count=len(dirs['SE'][action]);duration=float(profiles[action]['duration_ms'])
   manifest['animations'][name]={'fps':count*1000/duration,'authored_fps':24,'loop':action=='guard','status':'owner_requested_eight_direction_kunai','source_art_json':'res://assets/combat/kunai/kunai-combat.art.json','authored_duration_ms':duration,'frames':{di:[str(Path(p['body_frame'].removeprefix('res://')).relative_to(manifest_path.parent.relative_to(ROOT))).replace('\\','/') for p in dirs[di][action]] for di in directions}}
  manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
 out=ROOT/'assets/combat/kunai/kunai-combat.art.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(data,indent=2)+'\n')
 (HERE/'asset-qc.json').write_text(json.dumps(qc,indent=2)+'\n');print(json.dumps(qc))
if __name__=='__main__':export()
