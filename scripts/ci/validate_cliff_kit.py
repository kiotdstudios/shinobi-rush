"""Validate native cliff kit provenance, geometry and animation exports without Godot."""
from pathlib import Path
import json,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/'assets/environment/blightwood/cliff_kit'
def pixels(im):
 return im.get_flattened_data() if hasattr(im,"get_flattened_data") else im.getdata()
def main():
 m=json.loads((DIR/'cliffs.art.json').read_text(encoding='utf-8'));colors=set()
 for name,digest in m['source_sha256'].items():
  p=ROOT/name
  assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,('source changed',name)
  colors.update(c[:3] for c in pixels(Image.open(p).convert('RGBA')) if c[3])
 ids=set()
 for a in m['modules']:
  assert a['id'] not in ids;ids.add(a['id'])
  im=Image.open(DIR/(a['id']+'.png'))
  assert im.mode=='RGBA' and list(im.size)==a['size'] and im.getbbox(),a['id']
  assert a['rise']==66 and len(a['sockets'])>=4
  assert all(c[:3] in colors for c in pixels(im) if c[3]),('interpolated/source-mismatched color',a['id'])
 cap=Image.open(DIR/'cap.png')
 assert all(cap.getpixel((x,y))[3] for x in range(72) for y in range(36) if abs(x+.5-36)/36+abs(y+.5-18)/18<=1),'cap has pixel holes'
 atlas=Image.open(DIR/'cascade-atlas.png');assert atlas.size==(224,384) and atlas.mode=='RGBA'
 frames=[atlas.crop(((i%4)*56,(i//4)*96,(i%4+1)*56,(i//4+1)*96)) for i in range(16)]
 assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==16,'duplicate cascade frames'
 assert all(f.getbbox() and all(c[:3] in colors for c in pixels(f) if c[3]) for f in frames),'invalid cascade native colors'
 assert (ROOT/'world/demos/blightwood-cliff-kit.json').read_bytes()==(DIR/'demo-layout.json').read_bytes(),'source/runtime demo differs'
 print(f'PASS cliff kit: {len(ids)} native modules, 16 unique cascade frames, 7 unchanged source textures, exact palette/alpha/geometry/demo checks')
if __name__=='__main__':main()
