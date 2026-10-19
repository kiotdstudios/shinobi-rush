from pathlib import Path
from PIL import Image
import json,hashlib,sys
p=Path(sys.argv[1]) if len(sys.argv)>1 else Path('assets/characters/player')
m=json.loads((p/'player_128.manifest.json').read_text());provenance=json.loads((p/'animations/production-provenance.json').read_text());count=0
for action,e in m['animations'].items():
 assert e['fps']==12
 for d,paths in e['frames'].items():
  unique=list(dict.fromkeys(paths));record=provenance[action]['directions'][d]
  assert len(unique)==record['count'];seen=set()
  for i,rel in enumerate(unique):
   f=p/rel;im=Image.open(f);assert im.mode=='RGBA' and im.size==(128,128)
   assert set(im.getchannel('A').get_flattened_data())<={0,255}
   assert hashlib.sha256(f.read_bytes()).hexdigest()==record['sha256'][i]
   seen.add(im.tobytes());count+=1
  assert len(seen)==len(unique)
assert m['animations']['idle']['frames']['SW'][0]==m['animations']['idle']['frames']['SW'][1]
assert len(m['animations']['idle']['frames']['SW'])==16
assert len(m['animations']['sprint']['frames']['NW'])==11
assert count==sum(q['count'] for entry in provenance.values() for q in entry['directions'].values())
print('PASS',count,'exact PNGs,RGBA128,binaryalpha,all direction counts,source hashes,idleSWholds,sprintNWloop')
