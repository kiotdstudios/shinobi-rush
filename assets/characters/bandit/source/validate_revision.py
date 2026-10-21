"""Keep the arm correction scoped to sprint and verify revision previews."""
from pathlib import Path
from PIL import Image
import subprocess,json
ROOT=Path(__file__).resolve().parents[1]
assert json.loads((ROOT/'bandit_128.art.json').read_text())['art_revision']=='sprint-arms-v3'
for action in ['idle','run']:
 for path in sorted((ROOT/'sprites'/action).glob('*.png')):
  git_path=f'assets/characters/bandit/sprites/{action}/{path.name}'
  before=subprocess.run(['git','show',f'e211dae:{git_path}'],capture_output=True,check=True).stdout
  assert path.read_bytes()==before,git_path+' unexpectedly changed'
for direction in ['S','SE','E','NE','N','NW','W','SW']:
 changed=0
 for i in range(8):
  path=f'assets/characters/bandit/sprites/sprint/{direction}_{i:03}.png'
  before=subprocess.run(['git','show',f'e211dae:{path}'],capture_output=True,check=True).stdout
  changed+=(ROOT/f'sprites/sprint/{direction}_{i:03}.png').read_bytes()!=before
 assert changed==8,(direction,changed,'expected every sprint pose replaced')
for name in ['sprint-v3-all-directions','sprint-v3-before-after']+[f'sprint-v3-{d}' for d in ['S','SE','E','NE','N','NW','W','SW']]:
 for label in ['normal','half']:
  gif=Image.open(ROOT/f'previews/{name}-{label}.gif');assert gif.n_frames==8
  duration=0
  for i in range(8):gif.seek(i);duration+=gif.info['duration']
  assert abs(duration-8/24*1000*(2 if label=='half' else 1))<10
print('PASS: all idle/run PNGs byte-identical to v1; revision GIF counts and timings correct')
