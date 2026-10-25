from pathlib import Path
from PIL import Image
import json
root=Path('build/tag-gif-frames');out=Path('docs/visuals/tag-bombs')
for mode in ['normal','half-speed']:
 paths=sorted((root/mode).glob('*.png'));times=json.loads((root/mode/'times.json').read_text());ims=[Image.open(p).convert('RGB') for p in paths]
 atlas=Image.new('RGB',(1280,720*len(ims[::10])))
 for i,im in enumerate(ims[::10]):atlas.paste(im,(0,720*i))
 palette=atlas.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
 frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in ims]
 durations=[max(20,round((times[i+1]-times[i])/10)*10) for i in range(len(times)-1)]+[100]
 frames[0].save(out/f'{mode}.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
 print(mode,len(frames),sum(durations), (out/f'{mode}.gif').stat().st_size)
