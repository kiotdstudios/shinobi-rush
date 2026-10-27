"""Deterministic review compositing of unmodified source sprites, not generated art."""
from pathlib import Path
from PIL import Image,ImageDraw
import json, math
R=Path(__file__).resolve().parents[2];D=R/'docs/visuals/movement-transitions'
actors={}
for who,filename in [('player','player_128.manifest.json'),('bandit','bandit_128.art.json')]:
 p=R/'assets/characters'/who/filename
 actors[who]=(p.parent,json.loads(p.read_text())['animations'])
frames=[]
segments=[(.35,'idle','SE'),(.10,'move_start','SE'),(.60,'run','SE'),(.12,'move_pivot','NE'),(.50,'run','NE'),(.13,'move_stop','NE'),(.30,'idle','NE'),(.10,'move_start_sprint','NE'),(.75,'sprint','NE'),(.13,'move_stop_sprint','NE'),(.92,'idle','NE')]
for tick in range(120):
 t=tick/30;local=t
 for duration,action,direction in segments:
  if local<duration:break
  local-=duration
 canvas=Image.new('RGB',(768,390),(26,45,47));draw=ImageDraw.Draw(canvas)
 draw.text((20,15),'PR 224 | APPROVED POSE REUSE | NORMAL / HALF SPEED',fill='white')
 draw.text((20,38),f'{t:04.2f}s    {action}    {direction}',fill=(160,206,219))
 for column,(who,(parent,animations)) in enumerate(actors.items()):
  definition=animations[action];face=direction
  if action=='move_pivot':face=['SE','E','NE'][min(2,int(local/duration*3))]
  files=definition['frames'][face]
  index=min(len(files)-1,int(local/duration*len(files))) if action.startswith('move_') else int(local*definition['fps'])%len(files)
  im=Image.open(parent/files[index]).convert('RGBA').resize((256,256),Image.Resampling.NEAREST)
  x=column*384+64;y=95
  draw.line((column*384+20,y+232,column*384+360,y+232),fill=(73,99,95))
  canvas.paste(im,(x,y),im)
  draw.text((column*384+90,355),f'{who.upper()} {face} frame {index+1}',fill='white')
 frames.append(canvas.quantize(colors=192,method=Image.Quantize.MEDIANCUT))
durations=[30 if i%3!=2 else 40 for i in range(120)]
for name,mult in [('normal',1),('half-speed',2)]:
 frames[0].save(D/(name+'.gif'),save_all=True,append_images=frames[1:],duration=[d*mult for d in durations],loop=0,disposal=2,optimize=False)
print('PASS: normal 4 seconds / half speed 8 seconds; native source pixels enlarged nearest-neighbor')
