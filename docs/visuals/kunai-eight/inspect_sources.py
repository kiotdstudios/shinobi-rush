"""QC-only extraction and coordinate grids; does not paint sprite content."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
from process_common import ROOT,clean,extract,OFFSETS
OUT=ROOT/'build/kunai-tracks';OUT.mkdir(parents=True,exist_ok=True)
def main():
 qc={};errors=[]
 for character in ['player','bandit']:
  for path in sorted((ROOT/f'assets/characters/{character}/kunai_eight/source').glob('*.png')):
   if 'rejected' in path.stem:continue
   try:frames,cols,rows=extract(path)
   except AssertionError as e:errors.append(str(e));continue
   dest=OUT/path.stem;dest.mkdir(exist_ok=True)
   contact=Image.new('RGB',(cols*280,rows*282),'#26313e');d=ImageDraw.Draw(contact)
   for i,f in enumerate(frames):
    f.save(dest/f'{i:03}.png');x,y=i%cols*280,i//cols*282;big=f.resize((256,256),Image.Resampling.NEAREST);contact.paste(big,(x+24,y+8),big)
    for t in range(16,128,16):
     d.line((x+24+t*2,y+8,x+24+t*2,y+264),fill='#435365');d.line((x+24,y+8+t*2,x+280,y+8+t*2),fill='#435365');d.text((x+1,y+8+t*2),str(t),fill='#bbbbbb');d.text((x+24+t*2,y+268),str(t),fill='#bbbbbb')
    d.text((x+24,y+8),str(i),fill='white')
   contact.save(OUT/(path.stem+'.png'));qc[path.stem]={'frames':len(frames),'unclipped':True,'fixed_offset_x':OFFSETS.get(path.stem,0),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 (OUT/'source-qc.json').write_text(json.dumps(qc,indent=2)+'\n');print(json.dumps({'qc':qc,'errors':errors}));assert not errors
if __name__=='__main__':main()
