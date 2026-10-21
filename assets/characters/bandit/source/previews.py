"""Nearest-only art-review exports from completed bandit PNGs."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[1];PRE=ROOT/'previews';PRE.mkdir(exist_ok=True)
m=json.loads((ROOT/'bandit_128.art.json').read_text());font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
def images(action,direction):return [Image.open(ROOT/p).convert('RGBA') for p in m['animations'][action]['frames'][direction]]
def mat(im,size=384):
 bg=Image.new('RGBA',(128,128),'#34494b');bg.alpha_composite(im);return bg.convert('RGB').resize((size,size),Image.Resampling.NEAREST)
for action in m['animations']:
 for direction in m['animations'][action]['frames']:
  ims=images(action,direction);out=[mat(im) for im in ims];fps=m['animations'][action]['authored_fps']
  for speed,label in [(1,'normal'),(.5,'half')]:
   times=[round(i*1000/fps/speed/10)*10 for i in range(len(out)+1)];dur=[times[i+1]-times[i] for i in range(len(out))]
   out[0].save(PRE/f'{action}-{direction}-{label}.gif',save_all=True,append_images=out[1:],duration=dur,loop=0,disposal=2,optimize=False)
  contact=Image.new('RGB',(len(ims)*256,290),'#18242b');draw=ImageDraw.Draw(contact)
  for i,im in enumerate(ims):
   contact.paste(mat(im,256),(i*256,34));draw.text((i*256+8,5),f'{action} {direction} / {i}',font=font,fill='white')
  contact.save(PRE/f'{action}-{direction}-frames.png')
actions=['idle','run','sprint'];directions=m['directions']
if all(len(m['animations'][a]['frames'])==8 for a in actions):
 out=[]
 for i in range(48):
  sheet=Image.new('RGB',(384,3*420),'#18242b');d=ImageDraw.Draw(sheet)
  for row,a in enumerate(actions):
   ims=images(a,'SE');rate=m['animations'][a]['authored_fps'];idx=int(i/24*rate)%len(ims)
   sheet.paste(mat(ims[idx]),(0,row*420+36));d.text((12,row*420+5),{'idle':'Idle','run':'Regular run — pumping arms','sprint':'Ninja sprint — arms back'}[a],font=font,fill='white')
  out.append(sheet)
 for speed,label in [(1,'normal'),(.5,'half')]:
  ts=[round(i*1000/24/speed/10)*10 for i in range(49)];out[0].save(PRE/f'bandit-SE-{label}.gif',save_all=True,append_images=out[1:],duration=[ts[i+1]-ts[i] for i in range(48)],loop=0,optimize=False,disposal=2)
 contact=Image.new('RGB',(8*256,3*300),'#18242b');d=ImageDraw.Draw(contact)
 for row,a in enumerate(actions):
  for col,direction in enumerate(directions):
   contact.paste(mat(images(a,direction)[0],256),(col*256,row*300+44));d.text((col*256+12,row*300+6),f'{a} / {direction}',font=font,fill='white')
 contact.save(PRE/'all-directions.png')
turn=Image.new('RGB',(4*256,2*290),'#18242b');d=ImageDraw.Draw(turn)
for i,direction in enumerate(directions):
 im=Image.open(ROOT/f'rotations/{direction}.png').convert('RGBA');turn.paste(mat(im,256),(i%4*256,i//4*290+34));d.text((i%4*256+10,i//4*290+5),direction,font=font,fill='white')
turn.save(PRE/'turnaround.png');print('Preview exports:',PRE)
player_root=ROOT.parent/'player';pm=json.loads((player_root/'player_128.manifest.json').read_text())
player=Image.open(player_root/pm['animations']['idle']['frames']['SE'][0]).convert('RGBA')
pair=Image.new('RGB',(780,340),'#18242b');draw=ImageDraw.Draw(pair)
for col,(name,im) in enumerate([('Approved player',player),('New bandit',Image.open(ROOT/'rotations/SE.png').convert('RGBA'))]):
 pair.paste(mat(im,256),(col*390+65,50));draw.text((col*390+65,12),name+' / native 128px, shown 2x',font=font,fill='white')
pair.save(PRE/'player-scale-comparison.png')
