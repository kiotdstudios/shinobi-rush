"""Build phone-friendly GIFs from actual recorded Web frames (no interpolated poses)."""
from pathlib import Path
from PIL import Image
import json,sys
R=Path(__file__).resolve().parent
# Use lossless Web screenshots to prevent video compression noise bloating the palette.
sample=Image.new('RGB',(1280,720*3))
for i,name in enumerate(['travel','before','bandit']):sample.paste(Image.open(R/'local-proof'/(name+'.png')).convert('RGB'),(0,i*720))
pal=sample.quantize(colors=192)
for name in ['before','normal','half-speed']:
 folder=Path(sys.argv[1])/name;files=sorted(folder.glob('*.png'));times=json.loads((folder/'timings.json').read_text())
 indexed=[]
 for file in files:
  raw=Image.open(file).convert('RGB')
  # Both panels are unscaled crops of the real video, preserving native pixel density.
  canvas=Image.new('RGB',(500,524),'#111c22')
  canvas.paste(raw.crop((0,55,500,119)),(0,0))
  canvas.paste(raw.crop((400,130,900,590)),(0,64))
  indexed.append(canvas.quantize(palette=pal,dither=Image.Dither.NONE))
 boundaries=[int(round((t-times[0])/10))*10 for t in times]
 durations=[max(20,boundaries[i+1]-boundaries[i]) for i in range(len(times)-1)]+[40]
 indexed[0].save(R/(name+'.gif'),save_all=True,append_images=indexed[1:],duration=durations,loop=0,optimize=True,disposal=1)
 print(name,len(files),sum(durations),'ms',(R/(name+'.gif')).stat().st_size,'bytes')
