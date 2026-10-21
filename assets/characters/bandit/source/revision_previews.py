"""Compare revised sprint to the rejected v1 poses; no art is redrawn here."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,io,subprocess
ROOT=Path(__file__).resolve().parents[1];PRE=ROOT/'previews'
m=json.loads((ROOT/'bandit_128.art.json').read_text());directions=m['directions'];font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
def sprite(direction,i,old=False):
 path=f'assets/characters/bandit/sprites/sprint/{direction}_{i:03}.png'
 im=Image.open(io.BytesIO(subprocess.run(['git','show',f'e211dae:{path}'],capture_output=True,check=True).stdout)) if old else Image.open(ROOT/f'sprites/sprint/{direction}_{i:03}.png')
 bg=Image.new('RGBA',(128,128),'#34494b');bg.alpha_composite(im.convert('RGBA'));return bg.convert('RGB').resize((256,256),Image.Resampling.NEAREST)
def save(frames,name):
 for speed,label in [(1,'normal'),(.5,'half')]:
  t=[round(i*1000/24/speed/10)*10 for i in range(len(frames)+1)]
  frames[0].save(PRE/f'{name}-{label}.gif',save_all=True,append_images=frames[1:],duration=[t[i+1]-t[i] for i in range(len(frames))],loop=0,optimize=False,disposal=2)
all_frames=[];comparison=[]
for i in range(8):
 sheet=Image.new('RGB',(1024,580),'#18242b');draw=ImageDraw.Draw(sheet)
 for j,direction in enumerate(directions):
  x=j%4*256;y=j//4*290;sheet.paste(sprite(direction,i),(x,y+34));draw.text((x+8,y+5),f'Revised sprint / {direction}',font=font,fill='white')
 all_frames.append(sheet)
 sheet=Image.new('RGB',(512,870),'#18242b');draw=ImageDraw.Draw(sheet)
 for row,direction in enumerate(['SE','N','NW']):
  for col,old in enumerate([True,False]):
   x=col*256;y=row*290;sheet.paste(sprite(direction,i,old),(x,y+34));draw.text((x+8,y+5),f'{direction} / '+('Rejected v1' if old else 'Revised arms'),font=font,fill='white')
 comparison.append(sheet)
save(all_frames,'sprint-v3-all-directions');save(comparison,'sprint-v3-before-after')
for direction in directions:
 save([sprite(direction,i) for i in range(8)],f'sprint-v3-{direction}')
print('Revised sprint: eight-direction normal/half GIFs and v1 comparisons exported')
