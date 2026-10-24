"""Package actual Godot Web captures, preserving their frame order and timing."""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
DOC = Path(__file__).parent
CAP = ROOT / 'build/ashen-trees-browser-final'
paths = sorted((CAP/'frames').glob('*.png'))
assert len(paths) == 192
# One global GIF palette for temporal color stability; never dither pixel art.
samples = Image.new('RGB',(320*8,180))
for i in range(8):
    samples.paste(Image.open(paths[i*24]).convert('RGB').resize((320,180),Image.Resampling.NEAREST),(i*320,0))
palette = samples.quantize(colors=256,dither=Image.Dither.NONE)
results = {}
for name,rate in [('normal',1),('half-speed',.5)]:
    frames=[]
    for i,path in enumerate(paths):
        image=Image.open(path).convert('RGB').resize((960,540),Image.Resampling.NEAREST)
        draw=ImageDraw.Draw(image)
        draw.rectangle((0,0,959,82),fill='#17212c')
        draw.text((16,16),f'ASHEN RUINS | VOLCANIC TREES | {name} | {rate:.1f}x',fill='#e0e5e9')
        draw.text((16,38),f'{i/24:.2f}s source clock | frame {i+1}/192 | sway + molten roots + falling ash',fill='#aab5c2')
        frames.append(image.quantize(palette=palette,dither=Image.Dither.NONE))
    times=[round(i*1000/24/rate/10)*10 for i in range(193)]
    durations=[times[i+1]-times[i] for i in range(192)]
    path=DOC/f'{name}.gif'
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=1,optimize=True)
    check=Image.open(path)
    total=0
    for i in range(check.n_frames):
        check.seek(i)
        total+=check.info['duration']
    assert total==int(8000/rate)
    results[name]={'frames':check.n_frames,'duration_ms':total,'bytes':path.stat().st_size}
for name in ['review.png','blightwood-comparison.png','gameplay-scale.png','browser-validation.json']:
    shutil.copy2(CAP/name,DOC/name)
(DOC/'preview-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
