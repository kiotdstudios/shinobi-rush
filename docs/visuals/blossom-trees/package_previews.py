"""Assemble previews from real rendered frames and delivered foliage tiles."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
out=ROOT/'docs/visuals/blossom-trees'
frames=[Image.open(ROOT/f'build/trees-loop/{i:03}.png').convert('RGB') for i in range(96)]
palette=frames[0].quantize(colors=256)
frames=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
frames[0].save(out/'weeping-sway-96.gif',save_all=True,append_images=frames[1:],duration=[50 if i%6==5 else 40 for i in range(96)],loop=0,optimize=False,disposal=2)
leaves=[]
sheets=[Image.open(ROOT/f'assets/vfx/falling_foliage/{kind}_tumble.png').convert('RGBA') for kind in ['petal','leaf']]
for i in range(16):
    panel=Image.new('RGB',(256,152),'#253743')
    ImageDraw.Draw(panel).text((8,4),'Separate petals / leaves',fill='white')
    for j,sheet in enumerate(sheets):
        frame=sheet.crop((i%4*32,i//4*32,(i%4+1)*32,(i//4+1)*32)).resize((128,128),Image.Resampling.NEAREST)
        panel.paste(frame,(j*128,24),frame)
    leaves.append(panel)
leaves[0].save(out/'foliage-tumble.gif',save_all=True,append_images=leaves[1:],duration=160,loop=0,optimize=False,disposal=2)
print('PASS packaged96 real shader frames /4seconds and16 independent foliage tumble preview frames')
