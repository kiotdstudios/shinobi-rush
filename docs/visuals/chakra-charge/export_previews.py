"""Assemble actual browser-rendered frames; no generated or interpolated in-between art."""
from pathlib import Path
from PIL import Image,ImageDraw
import shutil,sys
root=Path(__file__).resolve().parents[3]
source=root/(sys.argv[1] if len(sys.argv)>1 else 'build/chakra-browser')
dest=Path(__file__).parent
frames=[Image.open(source/'frames'/f'{i:03}.png').convert('RGB') for i in range(96)]
for name,fps in [('half-speed',12),('normal-speed',24)]:
 durations=[(int((i+1)*100/fps)-int(i*100/fps))*10 for i in range(96)]
 frames[0].save(dest/(name+'.gif'),save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
contact=Image.new('RGB',(6*220,4*275),'#111923');draw=ImageDraw.Draw(contact)
for j,i in enumerate(range(0,96,4)):
 x,y=(j%6)*220,(j//6)*275
 contact.paste(frames[i].resize((220,255),Image.Resampling.NEAREST),(x,y))
 draw.text((x+5,y+258),f'Phase {i:02}/96',fill='white')
contact.save(dest/'loop-contact.png')
for name in ['review.png','in-game.png']:
 shutil.copyfile(source/name,dest/name)
print('96 rendered frames assembled: half=8s; normal=4s; contact24 samples')
