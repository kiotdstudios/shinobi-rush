from pathlib import Path
from PIL import Image
import json,sys
R=Path(__file__).resolve().parent
for name in ['before','normal','half-speed']:
 folder=Path(sys.argv[1])/name;files=sorted(folder.glob('*.png'));times=json.loads((folder/'timings.json').read_text())
 frames=[Image.open(f).convert('RGB') for f in files]
 # Shared palette across the real screenshots, no interpolation or generated in-between frames.
 sample=Image.new('RGB',(1280,720*min(12,len(frames))))
 for i,im in enumerate(frames[::max(1,len(frames)//12)][:12]):sample.paste(im,(0,i*720))
 pal=sample.quantize(colors=256)
 indexed=[im.quantize(palette=pal,dither=Image.Dither.NONE) for im in frames]
 durations=[max(20,int(round((times[i+1]-times[i])/10))*10) for i in range(len(times)-1)]+[70]
 indexed[0].save(R/(name+'.gif'),save_all=True,append_images=indexed[1:],duration=durations,loop=0,optimize=False,disposal=2)
 print(name,len(frames),sum(durations),'ms')
