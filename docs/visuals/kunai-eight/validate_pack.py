"""Check exported artwork and immutable approved SE references."""
from pathlib import Path
from PIL import Image
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
data=json.loads((ROOT/'assets/combat/kunai/kunai-combat.art.json').read_text())
old=json.loads((ROOT/'assets/characters/player/kunai_primary_se/kunai-primary.art.json').read_text())
assert data['frame_size']==[128,128] and data['foot_anchor']==[64,116]
count=0;new=set()
for character,dirs in data['characters'].items():
 assert set(dirs)==set(data['directions'])
 for direction,actions in dirs.items():
  assert set(actions)=={'light1','light2','light3','dash_attack','guard'}
  for action,frames in actions.items():
   assert len(frames)==(1 if action=='guard' else 5 if action=='dash_attack' else 6)
   hashes=[]
   for pose in frames:
    path=ROOT/pose['body_frame'].removeprefix('res://');im=Image.open(path)
    assert im.size==(128,128) and im.mode=='RGBA'
    assert set(im.getchannel('A').getdata()).issubset({0,255})
    x,y=pose['right_hand_px'];assert im.getpixel((x,y))[3]==255
    assert im.getbbox()[3] in (116,117)
    digest=hashlib.sha256(path.read_bytes()).hexdigest();hashes.append(digest)
    if character=='player' and direction=='SE':assert pose==old['animations'][action]['frames'][pose['frame_index']]
    else:
     assert pose['body_sha256']==digest;new.add(str(path))
    count+=1
   assert len(set(hashes))==len(frames),(character,direction,action,'duplicate body')
assert count==384 and len(new)==360
result={'result':'PASS','body_frame_references':count,'new_pngs':len(new),'approved_SE_preserved':True,'directions':data['directions'],'characters':list(data['characters']),'foot_anchor':[64,116],'legacy_SE_sole_convention':'exclusive bounds 116 or 117 preserved'}
(Path(__file__).parent/'pack-validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
