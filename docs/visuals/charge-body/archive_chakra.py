"""Create verified standalone giveaway exports and a private original-project archive."""
from pathlib import Path
from PIL import Image
import subprocess,json,hashlib,shutil,zipfile
ROOT=Path(__file__).resolve().parents[3]
DESKTOP=Path('C:/Users/dielp/Desktop').resolve()
DEST=DESKTOP/'Shinobi Rush - Chakra VFX Giveaway - 2026-10-23'
V2=ROOT.parent/'chakra-blue-v2'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(path,data):
 assert path.resolve().is_relative_to(DEST.resolve());path.parent.mkdir(parents=True,exist_ok=True);assert not path.exists();path.write_bytes(data)
def main():
 assert DEST.parent==DESKTOP and not DEST.exists(),'Do not overwrite an existing Desktop archive'
 DEST.mkdir();index={}
 ref='origin/codex/chakra-charge'
 paths=subprocess.check_output(['git','ls-tree','-r','--name-only',ref],cwd=ROOT,text=True).splitlines()
 prefixes=('assets/vfx/chakra_charge/','assets/characters/player/chakra_charge/','docs/visuals/chakra-charge/')
 for rel in paths:
  if not rel.startswith(prefixes):continue
  data=subprocess.check_output(['git','show',ref+':'+rel],cwd=ROOT);p=DEST/'Private Project Archive'/'V1'/rel;write(p,data);assert p.read_bytes()==data;index['V1/'+rel]=sha(p)
 art=json.loads(subprocess.check_output(['git','show',ref+':assets/characters/player/chakra_charge/chakra-charge.art.json'],cwd=ROOT))
 v1=DEST/'Giveaway VFX Only'/'V1';frames={};layers={}
 for name,spec in art['layers'].items():
  rel=spec['texture'].removeprefix('res://');src=DEST/'Private Project Archive'/'V1'/rel
  write(v1/(name+'.png'),src.read_bytes());sheet=Image.open(src).convert('RGBA');seq=[]
  for n in range(spec['frames']):
   x,y=n%spec['columns'],n//spec['columns'];im=sheet.crop((x*256,y*256,x*256+256,y*256+256));out=v1/'frames'/name/f'{n:03}.png';out.parent.mkdir(parents=True,exist_ok=True);im.save(out);seq.append(im)
  frames[name]=seq;layers[name]={k:spec[k] for k in ['frames','columns','frame_size','anchor']};layers[name]['texture']=name+'.png'
 (v1/'manifest.json').write_text(json.dumps({'fps':24,'layers':layers,'combined_loop_phases':96,'character_included':False},indent=2)+'\n')
 preview=[]
 for n in range(96):
  im=Image.new('RGBA',(384,384),'#162634')
  for name in ['ground','aura','wisps']:
   ax,ay=layers[name]['anchor'];im.alpha_composite(frames[name][n%len(frames[name])],(192-ax,320-ay))
  preview.append(im.convert('RGB'))
 for speed,label in [(1,'normal'),(.5,'half-speed')]:
  holds=[round((n+1)*100/24/speed)*10-round(n*100/24/speed)*10 for n in range(96)]
  preview[0].save(v1/(label+'.gif'),save_all=True,append_images=preview[1:],duration=holds,loop=0,disposal=2,optimize=False)
 v2=DEST/'Giveaway VFX Only'/'V2';asset=V2/'assets/vfx/chakra_charge_blue_v2';m=json.loads((asset/'manifest.json').read_text())
 for p in [asset/'sheet.png',*sorted((asset/'frames').glob('*.png'))]:
  out=v2/p.relative_to(asset);write(out,p.read_bytes());assert sha(out)==sha(p);index['V2/'+str(p.relative_to(asset))]=sha(p)
 clean={k:m[k] for k in ['schema','frame_size','ground_anchor','fps','half_speed_fps','frame_count','sequences']};clean['frames']=[{k:f[k] for k in ['index','phase','path','duration_ms','sha256']} for f in m['frames']];clean['character_included']=False
 (v2/'manifest.json').write_text(json.dumps(clean,indent=2)+'\n')
 for label in ['normal','half-speed','sustain-half-speed']:
  p=V2/'docs/visuals/chakra-blue-v2'/f'effect-preview-{label}.gif';write(v2/(label+'.gif'),p.read_bytes())
 for version in ['V1','V2']:
  base=DEST/'Giveaway VFX Only'/version
  (base/'README.txt').write_text('Standalone transparent charge VFX. Individual PNG frames, sprite sheets, timing metadata and effects-only GIFs included. No game character or third-party reference images included. V1 has96 drawings across3 independent layers; V2 has96 sequential drawings. Owner can choose distribution terms before publishing.\n')
  with zipfile.ZipFile(DEST/f'Chakra-VFX-{version}-Giveaway.zip','w',zipfile.ZIP_DEFLATED) as z:
   for p in sorted(base.rglob('*')):
    if p.is_file():z.write(p,p.relative_to(base))
 (DEST/'README.txt').write_text('Giveaway VFX Only and the two ZIPs contain standalone effects without Shinobi Rush characters or supplied reference images. Private Project Archive preserves original sources, old character previews and reference/provenance for your records; it is not the public giveaway folder. No publication or license choice has been made. Old Git snapshots remain recoverable.\n')
 (DEST/'verified-sha256.json').write_text(json.dumps(index,indent=2)+'\n')
 print(json.dumps({'desktop_folder':str(DEST),'verified_files':len(index),'v1_individual_vfx_frames':sum(len(v) for v in frames.values()),'v2_individual_vfx_frames':len(m['frames']),'public_zips':[p.name for p in DEST.glob('*.zip')]}))
if __name__=='__main__':main()
