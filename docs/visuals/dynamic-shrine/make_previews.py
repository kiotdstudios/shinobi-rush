from pathlib import Path
from PIL import Image,ImageDraw
import json
ROOT=Path(__file__).resolve().parents[3]
DOC=Path(__file__).parent
paths=sorted((ROOT/'build/shrine-browser/frames').glob('*.png'))
assert len(paths)==288
samples=Image.new('RGB',(680*4,570))
for i in range(4):samples.paste(Image.open(paths[i*72]).convert('RGB').crop((300,100,980,670)),(i*680,0))
palette=samples.quantize(colors=256,dither=Image.Dither.NONE)
results={}
for name,rate in [('normal',1),('half-speed',.5)]:
    frames=[]
    for i,path in enumerate(paths):
        im=Image.new('RGB',(680,614),'#101c22')
        im.paste(Image.open(path).convert('RGB').crop((300,100,980,670)),(0,44))
        draw=ImageDraw.Draw(im)
        draw.text((12,8),f'BLIGHTWOOD SHRINE | {name} | {rate}x | {i/24:.2f}s',fill='#dce5ef')
        draw.text((12,25),'PixelLab shrine | 3 firefly groups | pulse / vines / god rays',fill='#99b6ce')
        frames.append(im.quantize(palette=palette,dither=Image.Dither.NONE))
    times=[round(i*1000/24/rate/10)*10 for i in range(289)]
    target=DOC/f'{name}.gif'
    frames[0].save(target,save_all=True,append_images=frames[1:],duration=[times[i+1]-times[i] for i in range(288)],loop=0,disposal=1,optimize=True)
    check=Image.open(target);total=0
    for i in range(check.n_frames):check.seek(i);total+=check.info['duration']
    assert total==int(12000/rate)
    results[name]={'frames':check.n_frames,'duration_ms':total,'bytes':target.stat().st_size,'source':'actual paused Godot Web frame captures; 24 source frames/sec'}
(DOC/'preview-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
