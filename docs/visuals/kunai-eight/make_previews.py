"""Assemble exact, paused Godot render captures; no art generation or interpolation."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
data=json.loads((ROOT/'assets/combat/kunai/kunai-combat.art.json').read_text())
shots=ROOT/'build/kunai-eight-browser'
directions=['S','SE','E','NE','N','NW','W','SW']
keys=[(a,i) for a in ['light1','light2','light3'] for i in range(6)]
durations=[data['characters']['player']['SE'][a][i]['duration_ms'] for a,i in keys]
for d in directions:
 frames=[Image.open(shots/f'{d}-{a}-{i}.png').convert('RGB') for a,i in keys]
 for speed,name in [(1,'normal'),(.5,'half-speed')]:
  # Cumulative rounding to GIF centiseconds avoids systematic frame-duration drift.
  elapsed=0;previous=0;holds=[]
  for ms in durations:
   elapsed+=ms/speed;now=round(elapsed/10)*10;holds.append(now-previous);previous=now
  frames[0].save(HERE/f'{d}-{name}.gif',save_all=True,append_images=frames[1:],duration=holds,loop=0,disposal=2,optimize=False)
sheet=Image.new('RGB',(1080*2,450*4),(25,28,34));draw=ImageDraw.Draw(sheet)
for n,d in enumerate(directions):
 x=(n%2)*1080;y=(n//2)*450
 sheet.paste(Image.open(shots/f'{d}-light1-2.png'),(x,y+30));draw.text((x+12,y+8),f'{d}: player / bandit - opening hit contact',fill='white')
sheet.save(HERE/'all-directions-contact.png')
print('8 normal + 8 half-speed Godot-rendered previews and all-direction contact sheet saved')
