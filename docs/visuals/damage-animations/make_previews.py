"""Package real Godot Web screenshots. GIF loops are review replays; source clips are one-shot."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil
ROOT=Path(__file__).resolve().parents[3]
DOC=Path(__file__).parent
CAP=ROOT/'build/damage-browser'
counts={'hit_react':8,'knockback':12,'death':16}
results={}
for view in ['SE','all']:
    source=[(action,p) for action,n in counts.items() for p in sorted((CAP/view/action).glob('*.png'))]
    assert len(source)==72
    samples=Image.new('RGB',(1280*3,720))
    for i,action in enumerate(counts):
        paths=sorted((CAP/view/action).glob('*.png'))
        samples.paste(Image.open(paths[len(paths)//2]).convert('RGB'),(i*1280,0))
    palette=samples.quantize(colors=256,dither=Image.Dither.NONE)
    for name,rate in [('normal',1),('half-speed',.5)]:
        frames=[]
        for index,(action,path) in enumerate(source):
            im=Image.open(path).convert('RGB')
            draw=ImageDraw.Draw(im)
            draw.rectangle((0,0,1279,132),fill='#24323a')
            draw.text((20,20),f'PLAYER + BANDIT | {action.upper()} | {view} | {rate}x | frame{index+1}/72',fill='#edf0f5')
            draw.text((20,45),'128x128 native art / no resampling | GIF replays for review; each game clip is non-looping',fill='#c6d3de')
            draw.text((20,70),'Hit reaction -> heavy stagger -> death, with final-pose holds',fill='#a8bdca')
            frames.append(im.quantize(palette=palette,dither=Image.Dither.NONE))
        times=[round(i*1000/24/rate/10)*10 for i in range(73)]
        target=DOC/f'{"all-" if view=="all" else ""}{name}.gif'
        frames[0].save(target,save_all=True,append_images=frames[1:],duration=[times[i+1]-times[i] for i in range(72)],loop=0,disposal=1,optimize=True)
        check=Image.open(target);total=0
        for i in range(check.n_frames):check.seek(i);total+=check.info['duration']
        assert total==int(3000/rate)
        results[target.name]={'source_frames':72,'encoded_frames':check.n_frames,'duration_ms':total,'bytes':target.stat().st_size,'source':'actual Godot Web captures at24 source FPS; review replay only'}
for name in ['all-directions.png','hit_react-all.png','knockback-all.png','death-all.png','validation.json']:
    shutil.copy2(CAP/name,DOC/('browser-validation.json' if name=='validation.json' else name))
(DOC/'preview-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
