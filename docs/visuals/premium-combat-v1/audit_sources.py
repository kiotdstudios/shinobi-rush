"""Read-only integrity inventory of existing art; never creates or redraws sprites."""
from pathlib import Path
from PIL import Image
import argparse,json,hashlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--art-root',type=Path,required=True);p.add_argument('--legacy-root',type=Path,required=True);p.add_argument('--bandit-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
def load(path):return json.loads(path.read_text(encoding='utf-8'))
def check(path,size):
 im=Image.open(path);assert im.mode=='RGBA' and im.size==tuple(size),str(path)
 assert {v for _,v in im.getchannel('A').getcolors(256)}<={0,255},str(path)
 return hashlib.sha256(path.read_bytes()).hexdigest()
root=a.art_root;player=root/'assets/characters/player';m=load(player/'player_128.manifest.json');paths=set();states={}
for name,clip in m['animations'].items():
 states[name]={'directions':{d:len(ps) for d,ps in clip['frames'].items()},'fps':clip['fps']}
 paths.update(p for ps in clip['frames'].values() for p in ps)
for path in paths:check(player/path,[128,128])
mod=player/'modular_poc';m2=load(mod/'modular_poc.json');combos={}
for name,clip in m2['animations'].items():
 for f in clip['frames']:assert check(mod/f['body_frame'],[128,128])==f['body_sha256']
 combos[name]={'direction':clip['direction'],'frames':len(clip['frames']),'source_contact_frames':clip['contact_frames'],'timing_status':m2['timing_status']}
for w in m2['weapons'].values():assert check(mod/w['texture'],w['size'])==w['sha256']
fxroot=root/'assets/vfx/combat';fx=load(fxroot/'combat_vfx.json')
for effect in fx['effects'].values():
 for path,sha in zip(effect['frames'],effect['sha256']):assert check(fxroot/path,fx['frame_size'])==sha
legacy=a.legacy_root/'assets/characters/player/source/combat-review-v1';dash=load(legacy/'normalized/dash_attack/SE/clip.json')
for path in dash['frames']:check(legacy/path,[128,128])
bandit=load(a.bandit_root/'assets/characters/bandit/bandit_128.art.json')
out={'scope':'inventory checkpoint; not finished prototype or runtime integration','sources':{'modular_pr':33,'modular_commit':'2e5717d6e844de0a94c954a520aad131f3162873','bandit_pr':38,'bandit_sprint_art_revision':bandit['art_revision'],'legacy_dash':'workspace-only untracked candidate; not shipped/approved'},'player':{'frame_size':m['frame_size'],'foot_anchor':m['foot_anchor'],'body_height_px':m['body_height_px'],'unique_locomotion_files':len(paths),'states':states},'modular':{'body_frames':sum(x['frames'] for x in combos.values()),'weapons':list(m2['weapons']),'animations':combos},'vfx':{k:v['frame_count'] for k,v in fx['effects'].items()},'dash_candidate':{'frames':len(dash['frames']),'direction':dash['direction'],'status':dash['status'],'layering':'baked sword; separate weaponless dash/socket track not delivered'},'bandit':{k:len(v['frames']) for k,v in bandit['animations'].items()},'validation':'PASS: referenced audited PNG dimensions/RGBA/binary alpha; modular body/weapon/VFX file hashes match source metadata'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(json.dumps(out,indent=2))
