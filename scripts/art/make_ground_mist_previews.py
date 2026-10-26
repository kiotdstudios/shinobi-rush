from pathlib import Path
from PIL import Image
import json
out=Path('docs/visuals/ground-mist');result=[]
for name,folder,count in [('normal','mist-gif-normal',50),('half-speed','mist-gif-half',100)]:
 files=sorted((Path('build')/folder).glob('*.png'))[-count:]
 imgs=[Image.open(f).convert('RGB').crop((870,350,1270,550)) for f in files]
 palette=imgs[0].quantize(colors=256,method=Image.Quantize.MEDIANCUT)
 frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in imgs]
 frames[0].save(out/(name+'.gif'),save_all=True,append_images=frames[1:],duration=80,loop=0,disposal=1,optimize=False)
 gif=Image.open(out/(name+'.gif'))
 result.append({'name':name,'frames':gif.n_frames,'duration_s':sum(gif.seek(i) or gif.info.get('duration',0) for i in range(gif.n_frames))/1000,'size':[400,200],'crop':[870,350,1270,550],'source':'actual Chromium compositor video; 12.5 FPS sampled; shared palette; native pixel crop near the eastern tree; no interpolation','bytes':(out/(name+'.gif')).stat().st_size})
(out/'previews.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
